import Foundation

public struct JournalEntry: Codable, Identifiable, Sendable {
    public var id: Date { day }
    public var day: Date
    public var answers: [String: Bool]
    public init(day: Date, answers: [String: Bool]) { self.day = day; self.answers = answers }
}
public struct HabitImpact: Sendable {
    public let difference: Double?
    public let exposed: Int
    public let unexposed: Int
    public var isReady: Bool { difference != nil }
}
public enum JournalAnalytics {
    /// Match a behavior day to NEXT morning recovery. Unanswered is not "no".
    public static func impact(habit: String, entries: [JournalEntry], recoveryByDay: [Date: Double], calendar: Calendar = .current) -> HabitImpact {
        var yes: [Double] = [], no: [Double] = []
        let unique = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.day) }).compactMapValues(\.last)
        for (day, entry) in unique {
            guard let answer = entry.answers[habit], let next = calendar.date(byAdding: .day, value: 1, to: day),
                  let score = recoveryByDay[next], score.isFinite, (0...100).contains(score) else { continue }
            if answer { yes.append(score) } else { no.append(score) }
        }
        let ready = yes.count >= 10 && no.count >= 10 && yes.count + no.count >= 30
        return .init(difference: ready ? Analytics.mean(yes)! - Analytics.mean(no)! : nil, exposed: yes.count, unexposed: no.count)
    }
}

public struct TrainingLog: Codable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var activity: String
    public var minutes: Double
    public var rpe: Double
    public var sets: [StrengthSet]
    public var load: Double { Analytics.workload(minutes: minutes, rpe: rpe) ?? 0 }
    public init(id: UUID = UUID(), date: Date = Date(), activity: String, minutes: Double, rpe: Double, sets: [StrengthSet] = []) {
        self.id = id; self.date = date; self.activity = activity; self.minutes = minutes; self.rpe = rpe; self.sets = sets
    }
}
public struct StrengthSet: Codable, Identifiable, Sendable {
    public var id: UUID
    public var exercise: String
    public var repetitions: Int
    public var kilograms: Double
    public var volume: Double { Double(max(0, repetitions)) * max(0, kilograms) }
    public init(exercise: String, repetitions: Int, kilograms: Double) {
        self.id = UUID(); self.exercise = exercise; self.repetitions = repetitions; self.kilograms = kilograms
    }
}

public enum Library {
    public static let activities = ["Strength training", "Running", "Walking", "Cycling", "Swimming", "Hiking", "Rowing", "Yoga", "Pilates", "HIIT", "Functional training", "Cross training", "Stair climbing", "Elliptical", "Mobility", "Stretching", "Boxing", "Kickboxing", "Martial arts", "Wrestling", "Dance", "Barre", "Climbing", "Bouldering", "Tennis", "Padel", "Squash", "Badminton", "Table tennis", "Basketball", "Football", "Volleyball", "Handball", "Rugby", "Baseball", "Softball", "Cricket", "Golf", "Hockey", "Ice hockey", "Skating", "Skateboarding", "Surfing", "Paddleboarding", "Kayaking", "Canoeing", "Sailing", "Water polo", "Skiing", "Snowboarding", "Cross-country skiing", "Snowshoeing", "Jump rope", "Gymnastics", "Fencing", "Archery", "Equestrian sports", "Disc sports", "Bowling", "Fishing", "Other"]
    public static let habitGroups: [String: [String]] = [
        "Nutrition": ["Alcohol", "Caffeine", "Late caffeine", "Late dinner", "Large dinner", "Breakfast", "Skipped breakfast", "Protein with breakfast", "Protein target met", "Carbohydrates before training", "Post-workout meal", "Fruits", "Vegetables", "High-fiber meals", "Fermented foods", "Fish", "Red meat", "Plant-based day", "Dairy", "Gluten", "Spicy food", "Sugary drinks", "Dessert", "Processed food", "Restaurant meal", "Home-cooked meals", "Calorie tracking", "Undereating", "Overeating", "Food cravings"],
        "Hydration": ["Hydration target met", "Morning water", "Electrolytes", "Water during workout", "Water before bed", "Dehydration symptoms", "Sparkling water", "Sports drink", "High sodium meal", "Sauna rehydration"],
        "Sleep": ["Consistent bedtime", "Consistent wake time", "Nap", "Late nap", "Screens before bed", "Reading before bed", "Dark bedroom", "Cool bedroom", "Earplugs", "Eye mask", "White noise", "Shared bed", "Pet in bedroom", "Nighttime interruption", "Nightmare", "Snoozed alarm", "Woke naturally", "Travel sleep", "New mattress", "Elevated pillow", "Open window", "Hot bedroom", "Late work", "Early wake-up", "Relaxation before bed"],
        "Training": ["Strength session", "Cardio session", "Zone 2 session", "Intervals", "Long workout", "Double session", "Morning workout", "Evening workout", "Training to failure", "Personal record", "Deload", "Rest day", "Active recovery", "Warm-up", "Cool-down", "Mobility work", "Stretching", "Foam rolling", "Massage", "Physiotherapy", "New exercise", "Outdoor workout", "Indoor workout", "Group workout", "Competition", "Heavy leg training", "Upper-body training", "Core training", "Balance work", "Breathing during recovery"],
        "Mind & lifestyle": ["Meditation", "Breathwork", "Gratitude practice", "Journaling", "Therapy session", "High work stress", "High personal stress", "Relaxed day", "Social time", "Time alone", "Time in nature", "Morning sunlight", "Evening sunlight", "Long commute", "Desk-bound day", "Standing desk", "Movement breaks", "High screen time", "Digital break", "Creative hobby", "Music", "Reading", "Learning", "Volunteering", "Conflict", "Positive mood", "Low mood", "Anxiety", "Mental fatigue", "Vacation"],
        "Environment": ["Flight", "Time-zone change", "Altitude", "Hot weather", "Cold weather", "High humidity", "Poor air quality", "Pollen exposure", "Crowded event", "Shift work", "Night shift", "Long drive", "Sauna", "Steam room", "Cold plunge", "Cold shower", "Hot bath", "Swimming outdoors", "New sleeping location", "Daylight saving change"],
        "Health & personal": ["Medication taken", "Medication timing changed", "Supplement taken", "Creatine taken", "Magnesium taken", "Melatonin taken", "Illness symptoms", "Allergy symptoms", "Headache", "Muscle soreness", "Joint discomfort", "Digestive discomfort", "Menstrual period", "Menstrual symptoms", "Vaccination", "Blood donation", "Injury recovery", "Nicotine", "Cannabis", "Intimacy", "Low energy", "High energy", "Appetite change", "Travel fatigue", "Routine checkup"]
    ]
    public static var habits: [String] { habitGroups.keys.sorted().flatMap { habitGroups[$0] ?? [] } }
}
