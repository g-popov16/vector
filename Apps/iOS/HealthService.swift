import Foundation
import HealthKit
import VectorCore

struct HealthReading: Identifiable {
    let id: String
    let value: Double
    let unit: String
    let date: Date
    let source: String
}
struct ImportedWorkout: Identifiable {
    let id: UUID
    let name: String
    let start: Date
    let minutes: Double
    let zones: ZoneSummary
}
struct HealthSnapshot {
    var today = VitalDay(date: Date())
    var history: [VitalDay] = []
    var sleep: [SleepSegment] = []
    var readings: [HealthReading] = []
    var metricHistory: [String: [MetricPoint]] = [:]
    var workouts: [ImportedWorkout] = []
    var steps: Double?
    var calories: Double?
    var strain: Double?
    var heartCoverage: Double = 0
    var updated: Date?
    static var example: HealthSnapshot {
        let now = Date(), calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        var result = HealthSnapshot()
        result.history = (1...42).map { i in
            VitalDay(date: calendar.date(byAdding: .day, value: -i, to: day)!, hrv: 62 + sin(Double(i)) * 8, restingHR: 51 + cos(Double(i)) * 3, respiratoryRate: 14.2, sleepHours: 7.8 + sin(Double(i)) * 0.5)
        }
        result.today = .init(date: day, hrv: 71, restingHR: 49, respiratoryRate: 14, sleepHours: 8.1)
        result.metricHistory["HRV"] = result.history.compactMap { vital in vital.hrv.map { MetricPoint(date: vital.date, value: $0) } }
        result.metricHistory["Resting HR"] = result.history.compactMap { vital in vital.restingHR.map { MetricPoint(date: vital.date, value: $0) } }
        result.metricHistory["Respiration"] = result.history.compactMap { vital in vital.respiratoryRate.map { MetricPoint(date: vital.date, value: $0) } }
        let wake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
        var cursor = wake.addingTimeInterval(-8.4 * 3600)
        let blocks: [(SleepStage, Double)] = [(.core, 1.2), (.deep, 1.3), (.core, 1.1), (.rem, 0.8), (.awake, 0.3), (.core, 1.2), (.rem, 1.1), (.core, 1.4)]
        result.sleep = blocks.map { stage, hours in
            let end = cursor.addingTimeInterval(hours * 3600)
            defer { cursor = end }
            return .init(start: cursor, end: end, stage: stage)
        }
        result.readings = [HealthReading(id: "HRV", value: 71, unit: "ms", date: wake, source: "Demo Watch"), HealthReading(id: "Resting HR", value: 49, unit: "bpm", date: wake, source: "Demo Watch"), HealthReading(id: "Respiration", value: 14, unit: "/min", date: wake, source: "Demo Watch"), HealthReading(id: "VO₂ max", value: 48.2, unit: "mL/kg/min", date: day, source: "Demo Watch"), HealthReading(id: "Blood oxygen", value: 98, unit: "%", date: wake, source: "Demo Watch")]
        result.steps = 8240; result.calories = 618; result.strain = 11.4; result.heartCoverage = 0.52; result.updated = now
        return result
    }
}

@MainActor
final class HealthService {
    private let store = HKHealthStore()
    private let types: [(HKQuantityTypeIdentifier, String, HKUnit)] = [
        (.heartRateVariabilitySDNN, "HRV", .secondUnit(with: .milli)),
        (.restingHeartRate, "Resting HR", .count().unitDivided(by: .minute())),
        (.respiratoryRate, "Respiration", .count().unitDivided(by: .minute())),
        (.appleSleepingWristTemperature, "Wrist temperature", .degreeCelsius()),
        (.oxygenSaturation, "Blood oxygen", .percent()),
        (.vo2Max, "VO₂ max", HKUnit(from: "ml/kg*min"))
    ]
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        var read = Set<HKObjectType>(types.map { HKQuantityType($0.0) })
        read.formUnion([HKQuantityType(.heartRate), HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()])
        try await store.requestAuthorization(toShare: [], read: read)
    }
    func samples(_ type: HKSampleType, start: Date, end: Date) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end), limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
    }
    private func total(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: HKQuantityType(identifier), quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate), options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit)) }
            }
            store.execute(query)
        }
    }
    func read(maximumHR: Double) async throws -> HealthSnapshot {
        let now = Date(), calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let beginning = calendar.date(byAdding: .day, value: -180, to: day)!
        var days: [Date: VitalDay] = [:]
        var result = HealthSnapshot()
        for (identifier, label, unit) in types {
            let quantities = try await samples(HKQuantityType(identifier), start: beginning, end: now).compactMap { $0 as? HKQuantitySample }
            result.metricHistory[label] = quantities.map { .init(date: $0.startDate, value: $0.quantity.doubleValue(for: unit) * (identifier == .oxygenSaturation ? 100 : 1)) }
            if let latest = quantities.last {
                result.readings.append(.init(id: label, value: latest.quantity.doubleValue(for: unit) * (identifier == .oxygenSaturation ? 100 : 1), unit: identifier == .oxygenSaturation ? "%" : unit.unitString, date: latest.endDate, source: latest.sourceRevision.source.name))
            }
            for (date, values) in Dictionary(grouping: quantities, by: { calendar.startOfDay(for: $0.startDate) }) {
                var vital = days[date] ?? VitalDay(date: date)
                let average = Analytics.mean(values.map { $0.quantity.doubleValue(for: unit) })
                if identifier == .heartRateVariabilitySDNN { vital.hrv = average }
                if identifier == .restingHeartRate { vital.restingHR = average }
                if identifier == .respiratoryRate { vital.respiratoryRate = average }
                days[date] = vital
            }
        }
        let sleepSamples = try await samples(HKCategoryType(.sleepAnalysis), start: beginning, end: now).compactMap { $0 as? HKCategorySample }
        // Noon-to-noon windows keep one overnight sleep together, including stage boundaries across midnight.
        var nights: [Date: [SleepSegment]] = [:]
        for sample in sleepSamples {
            let stage: SleepStage
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepUnspecified: stage = .unspecified
            case .awake: stage = .awake
            default: continue
            }
            let shifted = calendar.date(byAdding: .hour, value: 12, to: sample.startDate)!
            let date = calendar.startOfDay(for: shifted)
            nights[date, default: []].append(.init(start: sample.startDate, end: min(sample.endDate, now), stage: stage))
        }
        for (date, segments) in nights {
            var vital = days[date] ?? VitalDay(date: date)
            vital.sleepHours = SleepAnalytics.summarize(segments: segments, needHours: 8).asleepHours
            days[date] = vital
        }
        result.sleep = nights[day] ?? []
        result.today = days[day] ?? VitalDay(date: day)
        result.history = days.values.filter { $0.date < day }.sorted { $0.date < $1.date }
        result.steps = try await total(.stepCount, unit: .count(), start: day, end: now)
        result.calories = try await total(.activeEnergyBurned, unit: .kilocalorie(), start: day, end: now)
        let heartStart = calendar.date(byAdding: .day, value: -7, to: day)!
        let heart = try await samples(HKQuantityType(.heartRate), start: heartStart, end: now).compactMap { $0 as? HKQuantitySample }.map { HeartSample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: .count().unitDivided(by: .minute()))) }
        let daily = ZoneSummary.calculate(samples: heart, start: day, end: now, maximumHR: maximumHR)
        result.strain = daily.observedSeconds > 0 ? daily.strain : nil
        result.heartCoverage = daily.coverage
        let workouts = try await samples(HKObjectType.workoutType(), start: heartStart, end: now).compactMap { $0 as? HKWorkout }
        result.workouts = workouts.reversed().map { workout in
            .init(id: workout.uuid, name: Self.name(workout.workoutActivityType), start: workout.startDate, minutes: workout.duration / 60,
                  zones: ZoneSummary.calculate(samples: heart, start: workout.startDate, end: workout.endDate, maximumHR: maximumHR))
        }
        result.updated = now
        return result
    }
    static func name(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Run"
        case .walking: "Walk"
        case .cycling: "Ride"
        case .swimming: "Swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength"
        case .hiking: "Hike"
        case .yoga: "Yoga"
        default: "Workout · \(type.rawValue)"
        }
    }
    enum HealthError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Health data is unavailable on this device." }
    }
}
