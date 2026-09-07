import SwiftUI
import Charts
import VectorCore

struct WeeklyPlanView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedDate = Date()
    @State private var editing: PlannedSession?
    @State private var completing: PlannedSession?
    @State private var adding = false
    private var plans: [PlannedSession] { store.demo ? [] : store.local.plans }
    private var logs: [TrainingLog] { store.demo ? [] : store.local.training }
    private var assessment: WeeklyAssessment { Planning.assess(date: selectedDate, plans: plans, logs: logs) }
    var body: some View {
        Page(title: "Give the week direction.", subtitle: "Training / Weekly plan") {
            HStack {
                Button("Previous week", systemImage: "chevron.left") { moveWeek(-1) }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                Spacer()
                VStack {
                    Text(assessment.interval.start.formatted(.dateTime.month(.abbreviated).day())).font(.headline)
                    Text("Week of Monday").font(.caption).foregroundStyle(V.muted)
                }
                Spacer()
                Button("Next week", systemImage: "chevron.right") { moveWeek(1) }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            }
            Panel {
                Eyebrow(text: "Plan / performance")
                HStack {
                    Metric(label: "Planned load", value: Int(assessment.plannedLoad).formatted(), unit: "AU")
                    Metric(label: "Logged load", value: Int(assessment.completedLoad).formatted(), unit: "AU", color: V.orange)
                }
                Chart(assessment.days) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Workload", day.planned)).foregroundStyle(by: .value("Type", "Planned")).position(by: .value("Type", "Planned"))
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Workload", day.completed)).foregroundStyle(by: .value("Type", "Logged")).position(by: .value("Type", "Logged"))
                }.chartForegroundStyleScale(["Planned": V.muted, "Logged": V.orange]).frame(height: 170)
                Text("\(assessment.completedPlanCount) / \(assessment.plannedCount) planned sessions completed · \(Int(assessment.loggedMinutes)) logged minutes").font(.subheadline)
                if let change = assessment.loadChangePercent {
                    Text("\(change >= 0 ? "+" : "")\(change.oneDecimal)% load versus the previous full week").font(.footnote).foregroundStyle(V.muted)
                } else { Text("No logged load in the previous week to compare.").font(.footnote).foregroundStyle(V.muted) }
                Text("Current weeks are partial. Workload includes dated RPE logs only; add an effort log for imported Watch workouts. Missing logs are not proof of rest.").font(.caption).foregroundStyle(V.muted)
            }
            Button("Schedule a session", systemImage: "plus") { adding = true }.buttonStyle(.borderedProminent).disabled(store.demo)
            ForEach(assessment.days) { day in
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    let dailyPlans = plans.filter { Calendar.current.isDate($0.date, inSameDayAs: day.date) }.sorted { $0.date < $1.date }
                    if dailyPlans.isEmpty { Text("Open day").font(.subheadline).foregroundStyle(V.muted) }
                    ForEach(dailyPlans) { plan in
                        Panel {
                            HStack {
                                Text(plan.activity).font(.headline)
                                Spacer()
                                if let id = plan.completedLogID, logs.contains(where: { $0.id == id }) {
                                    Label("Completed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(V.signal)
                                }
                            }
                            Text("\(plan.date.formatted(date: .omitted, time: .shortened)) · \(Int(plan.minutes)) min · target RPE \(Int(plan.targetRPE))").font(.caption).foregroundStyle(V.muted)
                            if !plan.notes.isEmpty { Text(plan.notes).font(.subheadline) }
                            HStack {
                                Button("Edit") { editing = plan }
                                if plan.completedLogID == nil && plan.date <= Date() { Button("Log completion") { completing = plan } }
                                Spacer()
                                Button("Remove", role: .destructive) { store.updateLocal { $0.plans.removeAll { $0.id == plan.id } } }
                            }.font(.subheadline).disabled(store.demo)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $adding) { PlanEditor(date: max(Date(), assessment.interval.start)) }
        .sheet(item: $editing) { PlanEditor(existing: $0) }
        .sheet(item: $completing) { TrainingEditor(plan: $0) }
    }
    private func moveWeek(_ direction: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: direction * 7, to: selectedDate)!
    }
}

struct PlanEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan: PlannedSession
    init(existing: PlannedSession? = nil, date: Date = Date()) {
        _plan = State(initialValue: existing ?? .init(date: date, activity: "Strength training"))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Picker("Activity", selection: $plan.activity) { ForEach(Library.activities, id: \.self) { Text($0).tag($0) } }
                    DatePicker("Scheduled for", selection: $plan.date)
                    Stepper("\(Int(plan.minutes)) minutes", value: $plan.minutes, in: 5...600, step: 5)
                    Stepper("Target effort: \(Int(plan.targetRPE))/10", value: $plan.targetRPE, in: 1...10)
                    TextField("Focus or notes", text: $plan.notes, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Text("Target effort is a plan. Log how the session actually felt when you finish.").font(.caption)
                }
            }.navigationTitle("Schedule session").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    if store.updateLocal({ state in
                        if let index = state.plans.firstIndex(where: { $0.id == plan.id }) { state.plans[index] = plan }
                        else { state.plans.append(plan) }
                    }) { dismiss() }
                }.disabled(store.demo) }
            }
        }
    }
}
