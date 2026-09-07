import XCTest
@testable import VectorCore

final class AnalyticsTests: XCTestCase {
    let today = Calendar.current.startOfDay(for: Date())
    func history(_ count: Int) -> [VitalDay] {
        (1...count).map { VitalDay(date: Calendar.current.date(byAdding: .day, value: -$0, to: today)!, hrv: 60, restingHR: 50, respiratoryRate: 14, sleepHours: 8) }
    }
    func testRecoveryBaselineAndMissingSignals() {
        let current = VitalDay(date: today, hrv: 60, restingHR: 50, respiratoryRate: 14, sleepHours: 8)
        XCTAssertNil(Analytics.recovery(today: current, history: history(13)).score)
        XCTAssertEqual(Analytics.recovery(today: current, history: history(14)).score, 70)
        XCTAssertNil(Analytics.recovery(today: VitalDay(date: today), history: history(20)).score)
        XCTAssertNil(Analytics.recovery(today: current, history: Array(repeating: history(1)[0], count: 20)).score)
    }
    func testRecoveryRespondsToFatigueAndExcludesFuture() {
        let fatigued = VitalDay(date: today, hrv: 30, restingHR: 65, respiratoryRate: 17, sleepHours: 5)
        XCTAssertLessThan(Analytics.recovery(today: fatigued, history: history(20)).score!, 40)
        XCTAssertNil(Analytics.recovery(today: fatigued, history: [fatigued]).score)
    }
    func testStrainIsBoundedMonotonicNonAdditive() {
        XCTAssertEqual(Analytics.strain(weightedMinutes: -1), 0)
        XCTAssertLessThan(Analytics.strain(weightedMinutes: 50), Analytics.strain(weightedMinutes: 100))
        XCTAssertLessThanOrEqual(Analytics.strain(weightedMinutes: 100000), 21)
        XCTAssertNotEqual(Analytics.strain(weightedMinutes: 50) * 2, Analytics.strain(weightedMinutes: 100))
    }
    func testHeartRateGapsNeverBecomeFullCoverage() {
        let summary = ZoneSummary.calculate(samples: [.init(date: today, bpm: 130)], start: today, end: today.addingTimeInterval(600), maximumHR: 200)
        XCTAssertEqual(summary.seconds[2], 15)
        XCTAssertEqual(summary.unknownSeconds, 585)
        XCTAssertEqual(summary.coverage, 0.025, accuracy: 0.0001)
        XCTAssertEqual(Analytics.zone(bpm: 180, maximumHR: 200), 5)
        XCTAssertNil(Analytics.zone(bpm: .nan, maximumHR: 200))
    }
    func testSleepDeduplicatesAndPreservesWake() {
        let end = today.addingTimeInterval(8 * 3600)
        let segments: [SleepSegment] = [
            .init(start: today, end: end, stage: .unspecified),
            .init(start: today, end: end, stage: .core),
            .init(start: today, end: today.addingTimeInterval(3600), stage: .awake)
        ]
        let result = SleepAnalytics.summarize(segments: segments, needHours: 8)
        XCTAssertEqual(result.asleepHours, 7)
        XCTAssertEqual(result.efficiency, 87.5)
        XCTAssertEqual(result.performance, 87.5)
    }
    func testSleepDebtAndPlanner() {
        XCTAssertEqual(SleepAnalytics.debt(recentHours: [7, 7, 9]), 1)
        XCTAssertEqual(SleepAnalytics.debt(recentHours: []), 0)
        XCTAssertEqual(SleepAnalytics.bedtime(wake: today, need: 8, target: .peak).timeIntervalSince(today), -30000)
    }
    func testJournalUsesNextDayAndRequiresEnoughBothGroups() {
        var entries: [JournalEntry] = []; var scores: [Date: Double] = [:]
        for i in 0..<30 {
            let day = Calendar.current.date(byAdding: .day, value: i, to: today)!
            let next = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            entries.append(.init(day: day, answers: ["Caffeine": i % 2 == 0]))
            scores[next] = i % 2 == 0 ? 60 : 80
        }
        let impact = JournalAnalytics.impact(habit: "Caffeine", entries: entries, recoveryByDay: scores)
        XCTAssertEqual(impact.difference, -20)
        XCTAssertFalse(JournalAnalytics.impact(habit: "Unknown", entries: entries, recoveryByDay: scores).isReady)
        XCTAssertFalse(JournalAnalytics.impact(habit: "Caffeine", entries: Array(entries.prefix(20)), recoveryByDay: scores).isReady)
    }
    func testCatalogAndTrainingValidation() {
        XCTAssertGreaterThanOrEqual(Library.habits.count, 160)
        XCTAssertEqual(Set(Library.habits).count, Library.habits.count)
        XCTAssertNil(Analytics.workload(minutes: 30, rpe: 11))
        XCTAssertEqual(Analytics.workload(minutes: 45, rpe: 7), 315)
    }
}
