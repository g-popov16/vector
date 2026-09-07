import SwiftUI
import Charts
import VectorCore

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    var body: some View {
        @Bindable var store = store
        TabView {
            Tab("Today", systemImage: "scope") { NavigationStack { TodayView() } }
            Tab("Train", systemImage: "figure.strengthtraining.traditional") { NavigationStack { TrainingView() } }
            Tab("Sleep", systemImage: "moon") { NavigationStack { SleepView() } }
            Tab("Journal", systemImage: "square.and.pencil") { NavigationStack { JournalView() } }
            Tab("Coach", systemImage: "waveform") { NavigationStack { CoachView() } }
        }.tint(V.signal)
            .safeAreaInset(edge: .top, spacing: 0) {
                if store.demo {
                    HStack { Text("DEMO DATA · NOT YOUR BIOMETRICS").font(.system(.caption2, design: .monospaced)); Spacer(); Button("Exit") { Task { await store.leaveDemo() } } }.padding(12).background(V.signal).foregroundStyle(.black)
                }
            }
            .alert("VECTOR", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
            .onChange(of: phase) { _, value in if value == .active { Task { await store.refreshIfConnected() } } }
    }
}

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var settings = false
    var body: some View {
        Page(title: "Your daily signal.", subtitle: Date().formatted(.dateTime.weekday(.wide).month().day())) {
            if !store.local.healthConnected && !store.demo {
                Panel {
                    Image(systemName: "applewatch").font(.largeTitle).foregroundStyle(V.signal)
                    Text("Meet your baseline.").font(.title2.bold())
                    Text("Connect Apple Health to bring your Ultra’s training, sleep, and vitals into one view. Your data stays on your iPhone.").foregroundStyle(V.muted)
                    Button(store.busy ? "Connecting…" : "Connect Apple Health") { Task { await store.connect() } }.buttonStyle(.borderedProminent).disabled(store.busy)
                    Button("Explore with demo data") { store.showDemo() }
                }
            }
            Panel {
                HStack { Eyebrow(text: "01 / Recovery"); Spacer(); Image(systemName: "scope").foregroundStyle(V.signal) }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.recovery.score.map(String.init) ?? "—").font(.system(size: 100, weight: .medium, design: .rounded)).tracking(-6).monospacedDigit().foregroundStyle(V.signal)
                    Text("/ 100").foregroundStyle(V.muted)
                }.accessibilityElement(children: .combine)
                SignalBar(value: Double(store.recovery.score ?? 0) / 100)
                Text(store.recovery.explanation).font(.footnote).foregroundStyle(V.muted)
                NavigationLink { RecoveryDetail() } label: { Label("Read your signals", systemImage: "arrow.up.right") }.font(.subheadline.weight(.medium))
            }
            HStack(alignment: .top, spacing: 12) {
                Panel { Metric(label: "Strain", value: store.snapshot.strain?.oneDecimal ?? "—", unit: "/21", color: V.orange); Text("Observed load").font(.caption).foregroundStyle(V.muted) }
                Panel { Metric(label: "Sleep", value: store.snapshot.today.sleepHours?.oneDecimal ?? "—", unit: "hrs", color: V.blue); Text("Last night").font(.caption).foregroundStyle(V.muted) }
            }
            Panel {
                Eyebrow(text: "The essentials")
                HStack { Metric(label: "Steps", value: store.snapshot.steps.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—", unit: ""); Metric(label: "Active energy", value: store.snapshot.calories.map { String(Int($0)) } ?? "—", unit: "kcal") }
            }
            NavigationLink { HealthMonitorView() } label: {
                Panel { HStack { VStack(alignment: .leading, spacing: 8) { Eyebrow(text: "Health monitor"); Text("Know your normal.").font(.title3.bold()).foregroundStyle(.white) }; Spacer(); Image(systemName: "arrow.up.right") } }
            }
            if let updated = store.snapshot.updated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened)) · \(Int(store.snapshot.heartCoverage * 100))% of today has observed HR coverage. Strain may undercount activity.").font(.caption).foregroundStyle(V.muted)
            }
        }.toolbar { ToolbarItem(placement: .topBarLeading) { Text("V E C T O R").font(.system(.caption, design: .monospaced, weight: .bold)) }; ToolbarItem(placement: .topBarTrailing) { Button("Settings", systemImage: "slider.horizontal.3") { settings = true } } }
            .sheet(isPresented: $settings) { SettingsView() }
            .refreshable { await store.refreshIfConnected() }
    }
}

struct RecoveryDetail: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page(title: "Readiness, explained.", subtitle: "Personal baseline / v0.1") {
            Panel {
                Text(store.recovery.explanation).font(.title3)
                Text("HRV and resting heart rate are compared with up to 28 prior days. Sleep shortfall and elevated respiration can lower the estimate. Fourteen baseline days are required.").foregroundStyle(V.muted)
                Text("This experimental score is a training reflection tool. It does not diagnose illness or certify readiness.").font(.footnote).foregroundStyle(V.muted)
            }
            Panel {
                Eyebrow(text: "HRV / last 30 days")
                Chart(store.snapshot.history.suffix(30)) { day in
                    if let hrv = day.hrv { LineMark(x: .value("Day", day.date), y: .value("HRV · ms", hrv)).foregroundStyle(V.signal) }
                }.frame(height: 180).chartYAxis { AxisMarks(position: .leading) }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Personal calibration") {
                    Stepper("Maximum HR: \(Int(store.local.maximumHR)) bpm", value: $store.local.maximumHR, in: 100...230).onChange(of: store.local.maximumHR) { _, _ in store.save() }
                    Text("190 bpm is an editable starting value, not a measured maximum. Set your known maximum before interpreting zones.").font(.caption)
                    Stepper("Baseline sleep: \(store.local.baselineSleep.oneDecimal) h", value: $store.local.baselineSleep, in: 6...10, step: 0.25).onChange(of: store.local.baselineSleep) { _, _ in store.save() }
                }
                Section("Apple Health") {
                    Button("Review health permissions") { Task { await store.connect() } }
                    Button("Recalculate from Apple Health") { Task { await store.refreshIfConnected() } }
                    Text("Missing data can mean there are no samples or read access was not granted. VECTOR cannot distinguish these cases.").font(.caption)
                }
                Section("Privacy") {
                    Text("Core analytics and Apple Intelligence coaching run on device. No accounts, cloud AI, advertising, or tracking SDKs.")
                    Button("Delete local journal and training data", role: .destructive) { deleting = true }
                }
                Section { Button("Explore demo") { store.showDemo(); dismiss() } }
            }.navigationTitle("Calibration").toolbar { Button("Done") { dismiss() } }
                .confirmationDialog("Delete local data? Apple Health records remain available in Health.", isPresented: $deleting) { Button("Delete local data", role: .destructive) { store.deleteLocalData() } }
        }
    }
}
