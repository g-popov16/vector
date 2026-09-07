import Foundation

public struct VitalDay: Codable, Sendable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var hrv: Double?
    public var restingHR: Double?
    public var respiratoryRate: Double?
    public var sleepHours: Double?
    public init(date: Date, hrv: Double? = nil, restingHR: Double? = nil, respiratoryRate: Double? = nil, sleepHours: Double? = nil) {
        self.date = date; self.hrv = hrv; self.restingHR = restingHR
        self.respiratoryRate = respiratoryRate; self.sleepHours = sleepHours
    }
}

public struct RecoveryResult: Sendable {
    public let score: Int?
    public let baselineDays: Int
    public let explanation: String
}

public enum Analytics {
    public static func mean(_ values: [Double]) -> Double? {
        let valid = values.filter(\.isFinite)
        return valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count)
    }

    /// Experimental VECTOR v0.1 model, not a WHOOP/Bevel or clinical score.
    /// Missing signals never become zero. Baseline excludes the current/future day.
    public static func recovery(today: VitalDay, history: [VitalDay], sleepNeed: Double = 8) -> RecoveryResult {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today.date)
        let cutoff = calendar.date(byAdding: .day, value: -28, to: start)!
        let days = Dictionary(grouping: history.filter { $0.date >= cutoff && $0.date < start }, by: { calendar.startOfDay(for: $0.date) })
            .values.compactMap(\.first)
            .filter { ($0.hrv ?? 0) > 0 && ($0.restingHR ?? 0) > 0 && $0.hrv?.isFinite == true && $0.restingHR?.isFinite == true }
        guard days.count >= 14 else {
            return .init(score: nil, baselineDays: days.count, explanation: "Building your baseline · \(days.count)/14 nights")
        }
        guard let hrv = today.hrv, hrv.isFinite, hrv > 0,
              let rhr = today.restingHR, rhr.isFinite, rhr > 0,
              let sleep = today.sleepHours, sleep.isFinite, sleep > 0,
              sleepNeed.isFinite, sleepNeed > 0 else {
            return .init(score: nil, baselineDays: days.count, explanation: "Waiting for HRV, resting heart rate, and sleep")
        }
        func z(_ current: Double, _ values: [Double], floor: Double) -> Double {
            let m = mean(values) ?? current
            let sd = sqrt(mean(values.map { pow($0 - m, 2) }) ?? 0)
            return max(-2, min(2, (current - m) / max(sd, floor)))
        }
        let hrvZ = z(log(hrv), days.compactMap(\.hrv).filter { $0 > 0 }.map(log), floor: 0.12)
        let hrZ = z(rhr, days.compactMap(\.restingHR), floor: 3)
        var score = 70 + 12 * hrvZ - 8 * hrZ + 25 * (min(sleep / sleepNeed, 1) - 1)
        let rates = days.compactMap(\.respiratoryRate).filter { $0.isFinite && $0 > 0 }
        let hasRespiration = today.respiratoryRate.map { $0.isFinite && $0 > 0 } == true && rates.count >= 14
        if hasRespiration, let rate = today.respiratoryRate {
            score -= 5 * max(0, z(rate, rates, floor: 0.5))
        }
        return .init(score: Int(max(0, min(100, score)).rounded()), baselineDays: days.count,
                     explanation: hasRespiration ? "Experimental estimate · compared with your own baseline" : "Experimental estimate · respiratory data insufficient")
    }

    /// Add load first, then transform. Scores themselves must never be added.
    public static func strain(weightedMinutes: Double) -> Double {
        guard weightedMinutes.isFinite else { return 0 }
        return min(21, max(0, 21 * (1 - exp(-max(0, weightedMinutes) / 100))))
    }

    public static func zone(bpm: Double, maximumHR: Double) -> Int? {
        guard bpm.isFinite, maximumHR.isFinite, bpm > 0, maximumHR > 0 else { return nil }
        switch bpm / maximumHR {
        case ..<0.5: return 0
        case ..<0.6: return 1
        case ..<0.7: return 2
        case ..<0.8: return 3
        case ..<0.9: return 4
        default: return 5
        }
    }

    public static func load(zoneSeconds: [Double]) -> Double {
        let weights: [Double] = [0, 0.5, 1, 2, 3, 5]
        return zip(zoneSeconds, weights).reduce(0) { $0 + max(0, $1.0) / 60 * $1.1 }
    }

    /// Workload is session RPE × minutes; never mixes arbitrary strain scores with RPE load.
    public static func workload(minutes: Double, rpe: Double) -> Double? {
        guard minutes.isFinite, minutes > 0, rpe.isFinite, (1...10).contains(rpe) else { return nil }
        return minutes * rpe
    }
}

public struct HeartSample: Sendable {
    public let date: Date
    public let bpm: Double
    public init(date: Date, bpm: Double) { self.date = date; self.bpm = bpm }
}

public struct ZoneSummary: Sendable {
    public let seconds: [Double]
    public let unknownSeconds: Double
    public var strain: Double { Analytics.strain(weightedMinutes: Analytics.load(zoneSeconds: seconds)) }
    public var observedSeconds: Double { seconds.reduce(0, +) }
    public var coverage: Double { observedSeconds / max(1, observedSeconds + unknownSeconds) }
    public var percentages: [Double] { seconds.map { 100 * $0 / max(1, observedSeconds) } }

    /// Carry a reading for at most 15 s; gaps remain explicitly unobserved.
    public static func calculate(samples: [HeartSample], start: Date, end: Date, maximumHR: Double) -> ZoneSummary {
        var result = Array(repeating: 0.0, count: 6)
        guard end > start else { return .init(seconds: result, unknownSeconds: 0) }
        let sorted = samples.filter { $0.date >= start && $0.date < end && $0.bpm.isFinite && $0.bpm > 0 }.sorted { $0.date < $1.date }
        for (index, sample) in sorted.enumerated() {
            let next = index + 1 < sorted.count ? sorted[index + 1].date : end
            let duration = max(0, min(15, min(next, end).timeIntervalSince(sample.date)))
            if let zone = Analytics.zone(bpm: sample.bpm, maximumHR: maximumHR) { result[zone] += duration }
        }
        return .init(seconds: result, unknownSeconds: max(0, end.timeIntervalSince(start) - result.reduce(0, +)))
    }
}

public enum SleepStage: String, Codable, Sendable, CaseIterable { case awake, core, deep, rem, unspecified }
public struct SleepSegment: Codable, Sendable {
    public let start: Date
    public let end: Date
    public let stage: SleepStage
    public init(start: Date, end: Date, stage: SleepStage) { self.start = start; self.end = end; self.stage = stage }
}
public enum SleepTarget: String, CaseIterable, Codable, Sendable { case peak, perform, getBy = "get by" }

public struct SleepSummary: Sendable {
    public let asleepHours: Double
    public let efficiency: Double?
    public let stageHours: [SleepStage: Double]
    public let needHours: Double
    public var performance: Double { min(100, 100 * asleepHours / max(1, needHours)) }
}

public enum SleepAnalytics {
    /// Interval union avoids double counting overlapping sources/stages.
    public static func summarize(segments: [SleepSegment], needHours: Double) -> SleepSummary {
        let valid = segments.filter { $0.end > $0.start }
        let points = Array(Set(valid.flatMap { [$0.start, $0.end] })).sorted()
        var stages: [SleepStage: Double] = [:]
        let priority: [SleepStage] = [.awake, .deep, .rem, .core, .unspecified]
        for (a, b) in zip(points, points.dropFirst()) {
            let active = valid.filter { $0.start < b && $0.end > a }.map(\.stage)
            if let stage = priority.first(where: { active.contains($0) }) { stages[stage, default: 0] += b.timeIntervalSince(a) / 3600 }
        }
        let asleep = stages.filter { $0.key != .awake }.values.reduce(0, +)
        let span = points.last.flatMap { last in points.first.map { last.timeIntervalSince($0) / 3600 } } ?? 0
        return .init(asleepHours: asleep, efficiency: span > 0 ? min(100, asleep / span * 100) : nil, stageHours: stages, needHours: needHours)
    }

    /// Seven-night heuristic. Missing nights are excluded, not assumed sleepless.
    public static func debt(recentHours: [Double], baseline: Double = 8) -> Double {
        guard baseline.isFinite, baseline > 0 else { return 0 }
        return max(0, recentHours.suffix(7).filter { $0.isFinite && $0 >= 0 }.reduce(0) { $0 + baseline - $1 })
    }
    public static func need(baseline: Double, debt: Double, strain: Double) -> Double {
        min(10, max(6, baseline + min(1, max(0, debt) / 4) + min(0.75, max(0, strain) / 28)))
    }
    public static func bedtime(wake: Date, need: Double, target: SleepTarget, latencyMinutes: Double = 20) -> Date {
        let fraction: Double = target == .peak ? 1 : target == .perform ? 0.9 : 0.8
        return wake.addingTimeInterval(-(max(0, need) * fraction * 3600 + max(0, latencyMinutes) * 60))
    }
}
