import SwiftUI
import Charts
import VectorCore

struct SleepView: View {
    @Environment(AppStore.self) private var store
    @State private var wake = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 7), matchingPolicy: .nextTime) ?? Date()
    @State private var target: SleepTarget = .peak
    var body: some View {
        Page(title: "Recharge with intent.", subtitle: "03 / Sleep") {
            Panel {
                Metric(label: "Sleep performance", value: store.snapshot.today.sleepHours == nil ? "—" : Int(store.sleep.performance).formatted(), unit: "%", color: V.blue)
                SignalBar(value: store.sleep.performance / 100, color: V.blue)
                HStack { Metric(label: "Asleep", value: store.snapshot.today.sleepHours?.oneDecimal ?? "—", unit: "h"); Metric(label: "Efficiency", value: store.sleep.efficiency.map { Int($0).formatted() } ?? "—", unit: "%") }
                if !store.snapshot.sleep.isEmpty {
                    Chart(Array(store.snapshot.sleep.enumerated()), id: \.offset) { item in
                        RectangleMark(xStart: .value("Start", item.element.start), xEnd: .value("End", item.element.end), y: .value("Stage", item.element.stage.rawValue.capitalized))
                            .foregroundStyle(stageColor(item.element.stage))
                    }.frame(height: 140)
                    ForEach(SleepStage.allCases, id: \.self) { stage in
                        if let hours = store.sleep.stageHours[stage] {
                            HStack { Circle().fill(stageColor(stage)).frame(width: 6, height: 6); Text(stage.rawValue.capitalized); Spacer(); Text("\(Int(hours * 60)) min").monospacedDigit() }.font(.caption)
                        }
                    }
                }
            }
            Panel {
                Eyebrow(text: "Tonight / Sleep planner")
                Picker("Target", selection: $target) { ForEach(SleepTarget.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
                DatePicker("Wake time", selection: $wake, displayedComponents: .hourAndMinute).tint(V.blue)
                Metric(label: "Start winding down before", value: SleepAnalytics.bedtime(wake: wake, need: store.sleepNeed, target: target).formatted(date: .omitted, time: .shortened), unit: "", color: V.blue)
                Text("\(store.sleepNeed.oneDecimal) h estimated need · \(store.sleepDebt.oneDecimal) h recent debt · includes 20 min to fall asleep.").font(.footnote).foregroundStyle(V.muted)
                Text("Planning estimate, not a scheduled alarm. Peak budgets 100% of estimated need, Perform 90%, and Get by 80%.").font(.caption).foregroundStyle(V.muted)
            }
            Panel {
                Eyebrow(text: "Consistency / last 14 nights")
                Chart(store.snapshot.history.suffix(14)) { day in
                    if let hours = day.sleepHours { BarMark(x: .value("Night", day.date, unit: .day), y: .value("Hours", hours)).foregroundStyle(V.blue) }
                }.frame(height: 160)
                Text("Sleep efficiency uses the observed sleep window. Missing nights are excluded from debt estimates.").font(.caption).foregroundStyle(V.muted)
            }
        }
    }
    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage { case .awake: V.orange; case .core: V.blue; case .deep: Color(red: 0.32, green: 0.42, blue: 0.69); case .rem: V.signal; case .unspecified: V.muted }
    }
}
