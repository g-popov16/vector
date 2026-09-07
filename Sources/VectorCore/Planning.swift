import Foundation

public struct PlannedSession: Codable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var activity: String
    public var minutes: Double
    public var targetRPE: Double
    public var notes: String
    public var completedLogID: UUID?
    public var plannedLoad: Double { Analytics.workload(minutes: minutes, rpe: targetRPE) ?? 0 }
    public init(id: UUID = UUID(), date: Date, activity: String, minutes: Double = 45, targetRPE: Double = 6, notes: String = "", completedLogID: UUID? = nil) {
        self.id = id; self.date = date; self.activity = activity; self.minutes = minutes
        self.targetRPE = targetRPE; self.notes = notes; self.completedLogID = completedLogID
    }
}

public struct DailyWorkload: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let planned: Double
    public let completed: Double
}

public struct WeeklyAssessment: Sendable {
    public let interval: DateInterval
    public let days: [DailyWorkload]
    public let plannedCount: Int
    public let completedPlanCount: Int
    public let loggedSessionCount: Int
    public let loggedMinutes: Double
    public let previousLoad: Double
    public var plannedLoad: Double { days.reduce(0) { $0 + $1.planned } }
    public var completedLoad: Double { days.reduce(0) { $0 + $1.completed } }
    public var loadChangePercent: Double? { previousLoad > 0 ? (completedLoad - previousLoad) / previousLoad * 100 : nil }
    public var planCompletionPercent: Double? { plannedCount > 0 ? Double(completedPlanCount) / Double(plannedCount) * 100 : nil }
}

public enum Planning {
    /// Monday-based local week, including DST transitions. All comparisons use [start, end).
    public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: startOfDay) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: startOfDay)!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }
    public static func contains(_ date: Date, in interval: DateInterval) -> Bool { date >= interval.start && date < interval.end }
    public static func assess(date: Date, plans: [PlannedSession], logs: [TrainingLog], now: Date = Date(), calendar: Calendar = .current) -> WeeklyAssessment {
        let interval = week(containing: date, calendar: calendar)
        let previous = week(containing: calendar.date(byAdding: .day, value: -7, to: interval.start)!, calendar: calendar)
        // Ignore duplicate IDs, invalid sessions and future-dated completed logs.
        let validLogs = Dictionary(grouping: logs, by: \.id).compactMapValues(\.last).values.filter {
            $0.date <= now && Analytics.workload(minutes: $0.minutes, rpe: $0.rpe) != nil
        }
        let selectedLogs = validLogs.filter { contains($0.date, in: interval) }
        let selectedPlans = Dictionary(grouping: plans, by: \.id).compactMapValues(\.last).values.filter { contains($0.date, in: interval) }
        let validLogIDs = Set(validLogs.map(\.id))
        let completedIDs = Set(selectedPlans.compactMap(\.completedLogID)).intersection(validLogIDs)
        let days = (0..<7).map { offset -> DailyWorkload in
            let day = calendar.date(byAdding: .day, value: offset, to: interval.start)!
            return DailyWorkload(date: day,
                                 planned: selectedPlans.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.plannedLoad },
                                 completed: selectedLogs.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.load })
        }
        return .init(interval: interval, days: days, plannedCount: selectedPlans.count, completedPlanCount: completedIDs.count,
                     loggedSessionCount: selectedLogs.count, loggedMinutes: selectedLogs.reduce(0) { $0 + $1.minutes },
                     previousLoad: validLogs.filter { contains($0.date, in: previous) }.reduce(0) { $0 + $1.load })
    }
}

/// Versioned on-device state. Optional new fields preserve installations created before planning.
public struct LocalState: Codable, Sendable {
    public var schemaVersion = 2
    public var journal: [JournalEntry] = []
    public var training: [TrainingLog] = []
    public var plans: [PlannedSession] = []
    public var trackedHabits = ["Alcohol", "Late caffeine", "Meditation", "Protein target met", "Morning sunlight", "Late dinner"]
    public var maximumHR: Double = 190
    public var baselineSleep: Double = 8
    public var healthConnected = false
    public var wakeHour = 7
    public var wakeMinute = 0
    public var sleepTarget: SleepTarget = .peak
    public init() {}
    enum CodingKeys: String, CodingKey { case schemaVersion, journal, training, plans, trackedHabits, maximumHR, baselineSleep, healthConnected, wakeHour, wakeMinute, sleepTarget }
    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version <= schemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "This data requires a newer version of VECTOR.")
        }
        journal = try container.decodeIfPresent([JournalEntry].self, forKey: .journal) ?? journal
        training = try container.decodeIfPresent([TrainingLog].self, forKey: .training) ?? training
        plans = try container.decodeIfPresent([PlannedSession].self, forKey: .plans) ?? plans
        trackedHabits = try container.decodeIfPresent([String].self, forKey: .trackedHabits) ?? trackedHabits
        maximumHR = try container.decodeIfPresent(Double.self, forKey: .maximumHR) ?? maximumHR
        baselineSleep = try container.decodeIfPresent(Double.self, forKey: .baselineSleep) ?? baselineSleep
        healthConnected = try container.decodeIfPresent(Bool.self, forKey: .healthConnected) ?? healthConnected
        wakeHour = try container.decodeIfPresent(Int.self, forKey: .wakeHour) ?? wakeHour
        wakeMinute = try container.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? wakeMinute
        sleepTarget = try container.decodeIfPresent(SleepTarget.self, forKey: .sleepTarget) ?? sleepTarget
        maximumHR = min(230, max(100, maximumHR)); baselineSleep = min(10, max(6, baselineSleep))
        wakeHour = min(23, max(0, wakeHour)); wakeMinute = min(59, max(0, wakeMinute))
    }
    public mutating func upsert(_ log: TrainingLog, completing planID: UUID? = nil) {
        if let index = training.firstIndex(where: { $0.id == log.id }) { training[index] = log }
        else { training.append(log) }
        if let planID, let index = plans.firstIndex(where: { $0.id == planID }) {
            // One actual session completes at most one planned session.
            for other in plans.indices where plans[other].completedLogID == log.id { plans[other].completedLogID = nil }
            plans[index].completedLogID = log.id
        }
    }
    public mutating func removeTraining(id: UUID) {
        training.removeAll { $0.id == id }
        for index in plans.indices where plans[index].completedLogID == id { plans[index].completedLogID = nil }
    }
}
