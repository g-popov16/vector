import SwiftUI
import Charts
import VectorCore

struct TrainingView: View {
    @Environment(AppStore.self) private var store
    @State private var logging = false
    @State private var editing: TrainingLog?
    var body: some View {
        Page(title: "Built, not guessed.", subtitle: "02 / Training") {
            NavigationLink { WeeklyPlanView() } label: {
                Panel { HStack { VStack(alignment: .leading, spacing: 8) { Eyebrow(text: "Weekly plan"); Text("Give the week direction.").font(.title3.bold()).foregroundStyle(.white) }; Spacer(); Image(systemName: "calendar") } }
            }
            Panel {
                Eyebrow(text: "Seven-day workload")
                Metric(label: "Session RPE × minutes", value: Int(weeklyLoad).formatted(), unit: "AU", color: V.orange)
                Chart(visibleLogs.filter { $0.date > Date().addingTimeInterval(-7 * 86400) }) { log in
                    BarMark(x: .value("Day", log.date, unit: .day), y: .value("Load", log.load)).foregroundStyle(V.orange)
                }.frame(height: 130)
                Text("Perceived effort captures strength and cardio in a common workload unit. It remains separate from cardiovascular strain.").font(.caption).foregroundStyle(V.muted)
                Button("Log a session", systemImage: "plus") { logging = true }.buttonStyle(.borderedProminent).disabled(store.demo)
            }
            Eyebrow(text: "From your Watch / last 7 days")
            if store.snapshot.workouts.isEmpty { Text("Recorded Apple Health workouts will appear after sync.").foregroundStyle(V.muted) }
            ForEach(store.snapshot.workouts) { workout in
                NavigationLink { WorkoutDetail(workout: workout) } label: {
                    Panel { HStack { VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()).foregroundStyle(.white); Text(workout.start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(V.muted) }; Spacer(); Text("\(Int(workout.minutes)) min").foregroundStyle(V.orange) } }
                }
            }
            Eyebrow(text: "Your training log")
            ForEach(visibleLogs.sorted { $0.date > $1.date }) { log in
                Panel {
                    HStack { Text(log.activity).font(.headline); Spacer(); Text("\(Int(log.minutes)) min").foregroundStyle(V.muted) }
                    Text("\(log.date.formatted(date: .abbreviated, time: .shortened)) · RPE \(Int(log.rpe)) · \(Int(log.load)) AU").font(.caption).foregroundStyle(V.muted)
                    ForEach(log.sets) { set in Text("\(set.exercise) · \(set.repetitions) × \(set.kilograms.oneDecimal) kg").font(.subheadline) }
                    HStack {
                        Button("Edit session") { editing = log }
                        Spacer()
                        Button("Delete session", role: .destructive) { store.updateLocal { $0.removeTraining(id: log.id) } }
                    }
                }
            }
        }.sheet(isPresented: $logging) { TrainingEditor() }
            .sheet(item: $editing) { TrainingEditor(existing: $0) }
    }
    private var visibleLogs: [TrainingLog] { store.demo ? [] : store.local.training }
    private var weeklyLoad: Double { visibleLogs.filter { $0.date > Date().addingTimeInterval(-7 * 86400) }.reduce(0) { $0 + $1.load } }
}

struct WorkoutDetail: View {
    let workout: ImportedWorkout
    var body: some View {
        Page(title: workout.name, subtitle: "Heart-rate zone analysis") {
            Panel {
                Metric(label: "Observed strain", value: workout.zones.strain.oneDecimal, unit: "/21", color: V.orange)
                Text("\(Int(workout.zones.coverage * 100))% recording coverage · \(Int(workout.zones.unknownSeconds / 60)) min unobserved").font(.caption).foregroundStyle(V.muted)
                ForEach(0..<6) { index in
                    HStack { Text(index == 0 ? "Below Z1" : "Zone \(index)").frame(width: 75, alignment: .leading); SignalBar(value: workout.zones.percentages[index] / 100, color: index > 3 ? V.orange : V.signal); Text("\(Int(workout.zones.seconds[index] / 60))m · \(Int(workout.zones.percentages[index]))%").font(.caption.monospacedDigit()).frame(width: 85, alignment: .trailing) }
                }
                Text("Percentages use observed time. Zones use your maximum-HR setting.").font(.caption).foregroundStyle(V.muted)
            }
        }
    }
}

struct TrainingEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var activity = "Strength training"
    @State private var date = Date()
    @State private var minutes = 45.0
    @State private var rpe = 6.0
    @State private var sets: [StrengthSet] = []
    @State private var exercise = "Squat"
    @State private var reps = 8
    @State private var weight = 40.0
    private let logID: UUID
    private let isEditing: Bool
    private let initialPlanID: UUID?
    @State private var selectedPlanID: UUID?
    @State private var initializedPlanSelection = false
    init(existing: TrainingLog? = nil, plan: PlannedSession? = nil) {
        logID = existing?.id ?? UUID(); isEditing = existing != nil; initialPlanID = plan?.id
        _selectedPlanID = State(initialValue: plan?.id)
        _activity = State(initialValue: existing?.activity ?? plan?.activity ?? "Strength training")
        _date = State(initialValue: existing?.date ?? min(plan?.date ?? Date(), Date()))
        _minutes = State(initialValue: existing?.minutes ?? plan?.minutes ?? 45)
        _rpe = State(initialValue: existing?.rpe ?? plan?.targetRPE ?? 6)
        _sets = State(initialValue: existing?.sets ?? [])
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Picker("Activity", selection: $activity) { ForEach(Library.activities, id: \.self) { Text($0).tag($0) } }
                    DatePicker("When", selection: $date, in: ...Date())
                    Stepper("\(Int(minutes)) minutes", value: $minutes, in: 5...600, step: 5)
                    Stepper("Effort: \(Int(rpe))/10", value: $rpe, in: 1...10)
                    Picker("Completes planned session", selection: $selectedPlanID) {
                        Text("Unplanned session").tag(nil as UUID?)
                        ForEach(store.local.plans.filter { $0.completedLogID == nil || $0.completedLogID == logID }.sorted { $0.date < $1.date }) { plan in
                            Text("\(plan.activity) · \(plan.date.formatted(date: .abbreviated, time: .shortened))").tag(Optional(plan.id))
                        }
                    }
                }
                Section("Strength sets · optional") {
                    TextField("Exercise", text: $exercise)
                    Stepper("\(reps) reps", value: $reps, in: 1...100)
                    Stepper("\(weight.oneDecimal) kg", value: $weight, in: 0...500, step: 2.5)
                    Button("Add set") { sets.append(.init(exercise: exercise.trimmingCharacters(in: .whitespaces), repetitions: reps, kilograms: weight)) }.disabled(exercise.trimmingCharacters(in: .whitespaces).isEmpty)
                    ForEach(sets) { set in Text("\(set.exercise) · \(set.repetitions) × \(set.kilograms.oneDecimal) kg") }.onDelete { sets.remove(atOffsets: $0) }
                }
            }.navigationTitle(isEditing ? "Edit session" : "Log session").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    let log = TrainingLog(id: logID, date: date, activity: activity, minutes: minutes, rpe: rpe, sets: sets)
                    if store.updateLocal({ state in
                        for index in state.plans.indices where state.plans[index].completedLogID == logID { state.plans[index].completedLogID = nil }
                        state.upsert(log, completing: selectedPlanID)
                    }) { dismiss() }
                }.disabled(store.demo) }
            }
            .onAppear {
                guard !initializedPlanSelection else { return }
                initializedPlanSelection = true
                if initialPlanID == nil { selectedPlanID = store.local.plans.first { $0.completedLogID == logID }?.id }
            }
        }
    }
}
