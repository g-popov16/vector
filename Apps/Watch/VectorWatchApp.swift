import SwiftUI
import HealthKit
import WatchKit
import VectorCore

@main struct VectorWatchApp: App {
    @StateObject private var workout = WorkoutManager()
    var body: some Scene { WindowGroup { WatchDashboard().environmentObject(workout).tint(.green) } }
}
struct WatchDashboard: View {
    @EnvironmentObject private var workout: WorkoutManager
    @State private var activity: HKWorkoutActivityType = .running
    @AppStorage("maximumHR") private var maximumHR = 190.0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("V E C T O R").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                if workout.active {
                    Text(workout.bpm.map { "\(Int($0))" } ?? "—").font(.system(size: 56, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("BPM · \(workout.bpm.flatMap { Analytics.zone(bpm: $0, maximumHR: maximumHR) }.map { "ZONE \($0)" } ?? "WAITING FOR HR")").font(.caption2).foregroundStyle(.green)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(workout.start.map { "\(Int(timeline.date.timeIntervalSince($0) / 60)) min elapsed" } ?? "Starting…").font(.caption)
                    }
                    Text("Strain \(workout.strain.formatted(.number.precision(.fractionLength(1)))) / 21").font(.headline)
                    HStack {
                        Button(workout.paused ? "Resume" : "Pause") { workout.togglePause() }
                        Button("Finish", role: .destructive) { workout.finish() }
                    }.disabled(workout.busy)
                } else {
                    Text("Make it count.").font(.title2.bold())
                    Picker("Session", selection: $activity) {
                        Text("Run").tag(HKWorkoutActivityType.running)
                        Text("Ride").tag(HKWorkoutActivityType.cycling)
                        Text("Strength").tag(HKWorkoutActivityType.traditionalStrengthTraining)
                        Text("Walk").tag(HKWorkoutActivityType.walking)
                        Text("Row").tag(HKWorkoutActivityType.rowing)
                        Text("HIIT").tag(HKWorkoutActivityType.highIntensityIntervalTraining)
                    }
                    Stepper("Max HR \(Int(maximumHR))", value: $maximumHR, in: 100...230, step: 1).font(.caption2)
                    Text("Set the same known maximum as on iPhone.").font(.caption2).foregroundStyle(.secondary)
                    Button("Start workout") { Task { await workout.begin(activity: activity, maximumHR: maximumHR) } }.buttonStyle(.borderedProminent).disabled(workout.busy)
                }
                if workout.busy { ProgressView() }
                if let message = workout.message { Text(message).font(.caption2) }
            }
        }
    }
}

@MainActor final class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published var active = false
    @Published var paused = false
    @Published var busy = false
    @Published var bpm: Double?
    @Published var strain = 0.0
    @Published var start: Date?
    @Published var message: String?
    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var maximumHR = 190.0
    private var lastSample: Date?
    private var previousBPM: Double?
    private var zoneSeconds = Array(repeating: 0.0, count: 6)
    func begin(activity: HKWorkoutActivityType, maximumHR: Double) async {
        guard !active && !busy else { return }
        busy = true; message = nil; defer { busy = false }
        do {
            try await health.requestAuthorization(toShare: [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)], read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
            let config = HKWorkoutConfiguration(); config.activityType = activity; config.locationType = .unknown
            let session = try HKWorkoutSession(healthStore: health, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: config)
            session.delegate = self; builder.delegate = self
            self.session = session; self.builder = builder; self.maximumHR = maximumHR
            let now = Date(); start = now; strain = 0; zoneSeconds = Array(repeating: 0, count: 6)
            bpm = nil; lastSample = nil; previousBPM = nil; paused = false
            session.startActivity(with: now)
            try await builder.beginCollection(at: now)
            active = true
        } catch { session?.end(); active = false; message = error.localizedDescription }
    }
    func togglePause() {
        if paused { session?.resume() } else { session?.pause() }
        // Do not integrate heart-rate duration across the pause.
        lastSample = nil; previousBPM = nil
    }
    func finish() { busy = true; session?.end() }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.paused = toState == .paused
            if toState == .ended {
                guard let builder = self.builder else { self.busy = false; self.active = false; return }
                do {
                    try await builder.endCollection(at: date)
                    let saved = try await builder.finishWorkout()
                    self.message = saved == nil ? "Workout could not be saved." : "Saved to Apple Health. Refresh VECTOR on iPhone after sync."
                } catch { self.message = "Save failed: \(error.localizedDescription)" }
                self.active = false; self.busy = false; self.session = nil; self.builder = nil
            }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.message = error.localizedDescription; self.active = false; self.busy = false }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)),
              let statistics = workoutBuilder.statistics(for: HKQuantityType(.heartRate)),
              let quantity = statistics.mostRecentQuantity() else { return }
        let value = quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        let measured = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
        Task { @MainActor in
            guard !self.paused, value.isFinite, value > 0 else { return }
            if let last = self.lastSample, measured <= last { return }
            if let last = self.lastSample, let previous = self.previousBPM,
               let zone = Analytics.zone(bpm: previous, maximumHR: self.maximumHR) {
                self.zoneSeconds[zone] += max(0, min(15, measured.timeIntervalSince(last)))
            }
            self.lastSample = measured; self.previousBPM = value; self.bpm = value
            self.strain = Analytics.strain(weightedMinutes: Analytics.load(zoneSeconds: self.zoneSeconds))
        }
    }
}
