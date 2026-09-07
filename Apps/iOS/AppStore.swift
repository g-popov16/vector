import Foundation
import Observation
import VectorCore

struct LocalState: Codable {
    var journal: [JournalEntry] = []
    var training: [TrainingLog] = []
    var trackedHabits = ["Alcohol", "Late caffeine", "Meditation", "Protein target met", "Morning sunlight", "Late dinner"]
    var maximumHR: Double = 190
    var baselineSleep: Double = 8
    var healthConnected = false
}

@MainActor @Observable
final class AppStore {
    var local = LocalState()
    var snapshot = HealthSnapshot()
    var busy = false
    var message: String?
    var demo = false
    private let health = HealthService()
    private let file: URL
    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "Vector", directoryHint: .isDirectory)
        file = directory.appending(path: "local.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try (directory as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
            if FileManager.default.fileExists(atPath: file.path) { local = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: file)) }
        } catch { message = "Local data could not be loaded: \(error.localizedDescription)" }
    }
    func save() {
        do { try JSONEncoder().encode(local).write(to: file, options: [.atomic, .completeFileProtection]) }
        catch { message = "Changes could not be saved: \(error.localizedDescription)" }
    }
    var recovery: RecoveryResult { Analytics.recovery(today: snapshot.today, history: snapshot.history, sleepNeed: sleepNeed) }
    var sleepDebt: Double { SleepAnalytics.debt(recentHours: snapshot.history.sorted { $0.date < $1.date }.compactMap(\.sleepHours), baseline: local.baselineSleep) }
    var sleepNeed: Double { SleepAnalytics.need(baseline: local.baselineSleep, debt: sleepDebt, strain: snapshot.strain ?? 0) }
    var sleep: SleepSummary { SleepAnalytics.summarize(segments: snapshot.sleep, needHours: sleepNeed) }
    var recoveryHistory: [Date: Double] {
        var result: [Date: Double] = [:]
        for day in snapshot.history + [snapshot.today] {
            if let score = Analytics.recovery(today: day, history: snapshot.history, sleepNeed: local.baselineSleep).score {
                result[Calendar.current.startOfDay(for: day.date)] = Double(score)
            }
        }
        return result
    }
    func connect() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            try await health.authorize()
            local.healthConnected = true; save(); demo = false
            snapshot = try await health.read(maximumHR: local.maximumHR)
        } catch { message = "Apple Health: \(error.localizedDescription)" }
    }
    func refreshIfConnected() async {
        guard local.healthConnected && !demo && !busy else { return }
        busy = true; defer { busy = false }
        do { snapshot = try await health.read(maximumHR: local.maximumHR) }
        catch { message = "Refresh failed: \(error.localizedDescription)" }
    }
    func showDemo() { demo = true; snapshot = .example }
    func leaveDemo() async { demo = false; snapshot = HealthSnapshot(); await refreshIfConnected() }
    func answer(_ habit: String, value: Bool?, day: Date) {
        let date = Calendar.current.startOfDay(for: day)
        if let index = local.journal.firstIndex(where: { $0.day == date }) { local.journal[index].answers[habit] = value }
        else if let value { local.journal.append(.init(day: date, answers: [habit: value])) }
        save()
    }
    func deleteLocalData() {
        local = LocalState(); snapshot = HealthSnapshot(); demo = false; save()
    }
}
