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
    func testWeekUsesMondayAndHandlesDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sofia")!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 14))!
        let week = Planning.week(containing: sunday, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: week.start), 2)
        XCTAssertEqual(calendar.component(.day, from: week.start), 23)
        XCTAssertEqual(week.duration, 7 * 86400 - 3600)
        XCTAssertFalse(Planning.contains(week.end, in: week))
    }
    func testWeeklyAssessmentExcludesFutureAndDeduplicates() {
        let week = Planning.week(containing: today)
        let log = TrainingLog(date: week.start, activity: "Running", minutes: 30, rpe: 5)
        let previous = TrainingLog(date: Calendar.current.date(byAdding: .day, value: -1, to: week.start)!, activity: "Running", minutes: 20, rpe: 5)
        let future = TrainingLog(date: today.addingTimeInterval(86400), activity: "Running", minutes: 500, rpe: 10)
        let plan = PlannedSession(date: week.start, activity: "Running", minutes: 40, targetRPE: 5, completedLogID: log.id)
        let result = Planning.assess(date: today, plans: [plan, plan], logs: [log, log, previous, future], now: today)
        XCTAssertEqual(result.days.count, 7)
        XCTAssertEqual(result.completedLoad, 150)
        XCTAssertEqual(result.plannedLoad, 200)
        XCTAssertEqual(result.loggedSessionCount, 1)
        XCTAssertEqual(result.completedPlanCount, 1)
        XCTAssertEqual(result.loadChangePercent, 50)
        XCTAssertEqual(result.planCompletionPercent, 100)
        XCTAssertNil(Planning.assess(date: today, plans: [], logs: []).planCompletionPercent)
    }
    func testEditingAndDeletingTrainingPreservesPlanIntegrity() {
        var state = LocalState()
        let plan = PlannedSession(date: today, activity: "Strength training")
        let other = PlannedSession(date: today, activity: "Running")
        state.plans = [plan, other]
        var log = TrainingLog(date: today, activity: "Strength training", minutes: 45, rpe: 6)
        state.upsert(log, completing: plan.id)
        log.minutes = 60
        state.upsert(log, completing: other.id)
        XCTAssertEqual(state.training.count, 1)
        XCTAssertEqual(state.training[0].load, 360)
        XCTAssertNil(state.plans[0].completedLogID)
        XCTAssertEqual(state.plans[1].completedLogID, log.id)
        state.removeTraining(id: log.id)
        XCTAssertEqual(state.training.count, 0)
        XCTAssertNil(state.plans[1].completedLogID)
    }
    func testLocalStateMigrationAndRoundTrip() {
        let oldJSON = Data("{\"training\":[],\"journal\":[],\"maximumHR\":182,\"baselineSleep\":8.5,\"healthConnected\":true}".utf8)
        let migrated = try? JSONDecoder().decode(LocalState.self, from: oldJSON)
        XCTAssertEqual(migrated?.schemaVersion, 2)
        XCTAssertEqual(migrated?.maximumHR, 182)
        XCTAssertEqual(migrated?.wakeHour, 7)
        XCTAssertEqual(migrated?.plans.count, 0)
        var state = migrated!
        let plan = PlannedSession(date: today, activity: "Cycling")
        state.plans = [plan]; state.wakeHour = 6; state.sleepTarget = .perform
        state.upsert(TrainingLog(date: today, activity: "Cycling", minutes: 60, rpe: 5), completing: plan.id)
        let encoded = try? JSONEncoder().encode(state)
        let decoded = encoded.flatMap { try? JSONDecoder().decode(LocalState.self, from: $0) }
        XCTAssertEqual(decoded?.plans.first?.completedLogID, state.training.first?.id)
        XCTAssertEqual(decoded?.wakeHour, 6)
        XCTAssertEqual(decoded?.sleepTarget, .perform)
        XCTAssertNil(try? JSONDecoder().decode(LocalState.self, from: Data("{\"schemaVersion\":999}".utf8)))
    }
    func testTrendsRequireCoverageAndWeightEachDayEqually() {
        let calendar = Calendar.current
        var points: [MetricPoint] = []
        for i in 0..<30 {
            let day = calendar.date(byAdding: .day, value: -i, to: today)!
            points.append(.init(date: day, value: i < 7 ? 80 : 60))
        }
        let summary = Trends.summarize(points, days: 30, ending: today)
        XCTAssertEqual(summary.absoluteChange, 20)
        XCTAssertEqual(summary.firstDays, 7)
        XCTAssertEqual(summary.recentDays, 7)
        XCTAssertNil(Trends.summarize(Array(points.prefix(2)), days: 30, ending: today).absoluteChange)
        points.append(.init(date: today.addingTimeInterval(86400), value: 999))
        XCTAssertEqual(Trends.summarize(points, days: 30, ending: today).absoluteChange, 20)
        let end = today.addingTimeInterval(3600)
        let extra = (1...100).map { MetricPoint(date: today.addingTimeInterval(Double($0)), value: 80) }
        XCTAssertEqual(Trends.summarize(points + extra, days: 30, ending: end).absoluteChange, 20)
    }
}
