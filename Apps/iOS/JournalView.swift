import SwiftUI
import VectorCore

struct JournalView: View {
    @Environment(AppStore.self) private var store
    @State private var day = Date()
    @State private var library = false
    var body: some View {
        Page(title: "Small inputs. Patterns.", subtitle: "04 / Journal") {
            DatePicker("Behavior date", selection: $day, in: ...Date(), displayedComponents: .date)
            Text("Log the day the behavior happened. Its association is measured against the following morning’s recovery.").font(.footnote).foregroundStyle(V.muted)
            ForEach(store.local.trackedHabits, id: \.self) { habit in
                Panel {
                    Text(habit).font(.headline)
                    HStack {
                        choice("Yes", value: true, habit: habit)
                        choice("No", value: false, habit: habit)
                        choice("Skip", value: nil, habit: habit)
                    }
                    let impact = JournalAnalytics.impact(habit: habit, entries: store.local.journal, recoveryByDay: store.demo ? [:] : store.recoveryHistory)
                    if let delta = impact.difference {
                        Text("\(delta > 0 ? "+" : "")\(delta.oneDecimal) recovery points associated · \(impact.exposed) yes / \(impact.unexposed) no days").font(.caption).foregroundStyle(V.signal)
                    } else {
                        Text("Building evidence · \(impact.exposed) yes / \(impact.unexposed) no matched days").font(.caption).foregroundStyle(V.muted)
                    }
                }
            }
            Button("Customize behaviors", systemImage: "plus") { library = true }.buttonStyle(.bordered)
            Text("Associations require 30 matched days, including at least 10 yes and 10 no. They are observational and may reflect other habits; they do not establish cause.").font(.caption).foregroundStyle(V.muted)
        }.sheet(isPresented: $library) { HabitLibraryView() }
    }
    private func choice(_ label: String, value: Bool?, habit: String) -> some View {
        let selected = (store.demo ? nil : store.local.journal.first { Calendar.current.isDate($0.day, inSameDayAs: day) }?.answers[habit]) == value
        return Button(label) { store.answer(habit, value: value, day: day) }
            .buttonStyle(.bordered).tint(selected ? V.signal : V.muted).disabled(store.demo)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct HabitLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List {
                ForEach(Library.habitGroups.keys.sorted(), id: \.self) { category in
                    Section(category) {
                        ForEach((Library.habitGroups[category] ?? []).filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { habit in
                            Button {
                                if store.local.trackedHabits.contains(habit) { store.local.trackedHabits.removeAll { $0 == habit } }
                                else { store.local.trackedHabits.append(habit) }
                                store.save()
                            } label: { HStack { Text(habit).foregroundStyle(.primary); Spacer(); if store.local.trackedHabits.contains(habit) { Image(systemName: "checkmark").foregroundStyle(V.signal) } } }.disabled(store.demo)
                        }
                    }
                }
            }.searchable(text: $search).navigationTitle("\(Library.habits.count) behaviors").toolbar { Button("Done") { dismiss() } }
        }
    }
}
