import Foundation

struct LockerWorkoutPlan: Identifiable {
    let id = UUID()
    var title: String
    var focus: String
    var duration: Int
    var isFavorite: Bool

    static let samples: [LockerWorkoutPlan] = [
        LockerWorkoutPlan(title: "Shift-ready mobility", focus: "Mobility & core", duration: 20, isFavorite: true),
        LockerWorkoutPlan(title: "Cardio reset", focus: "Cardio", duration: 35, isFavorite: false),
        LockerWorkoutPlan(title: "Strength circuit", focus: "Full body", duration: 30, isFavorite: false),
    ]
}

struct LockerWellnessMetric: Identifiable {
    let id = UUID()
    var title: String
    var valueDescription: String
    var trendDescription: String
    var symbolName: String

    static let weeklySnapshot: [LockerWellnessMetric] = [
        LockerWellnessMetric(title: "Sleep", valueDescription: "6h 50m avg", trendDescription: "+20m vs. last week", symbolName: "bed.double.fill"),
        LockerWellnessMetric(title: "Mindful minutes", valueDescription: "35 min", trendDescription: "Consistent streak • 8 days", symbolName: "brain.head.profile"),
        LockerWellnessMetric(title: "Hydration", valueDescription: "82 oz/day", trendDescription: "Goal met 5 times", symbolName: "drop.fill"),
    ]
}

struct LockerHabitLog: Identifiable {
    let id = UUID()
    var title: String
    var streak: Int
    var goalFrequency: String

    static let sampleHabits: [LockerHabitLog] = [
        LockerHabitLog(title: "Journal entry", streak: 6, goalFrequency: "5x / week"),
        LockerHabitLog(title: "10k Steps", streak: 3, goalFrequency: "4x / week"),
        LockerHabitLog(title: "Water reminder", streak: 11, goalFrequency: "Daily"),
    ]
}

struct WorkoutRoutine: Identifiable, Hashable {
    let id: UUID
    var name: String
    var goal: String
    var estimatedDurationMinutes: Int
    var notes: String
    var scheduleDays: [RoutineDay]

    init(
        id: UUID = UUID(),
        name: String,
        goal: String,
        estimatedDurationMinutes: Int,
        notes: String = "",
        scheduleDays: [RoutineDay]
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.notes = notes
        self.scheduleDays = scheduleDays
    }

    var activeDaysPerWeek: Int {
        scheduleDays.count
    }

    func workouts(on date: Date, calendar: Calendar = .current) -> [RoutineDay] {
        let weekday = calendar.component(.weekday, from: date)
        return scheduleDays.filter { $0.dayOfWeek == weekday }
    }

    static let sampleRoutines: [WorkoutRoutine] = [
        WorkoutRoutine(
            name: "Bulk Plan",
            goal: "Strength",
            estimatedDurationMinutes: 45,
            scheduleDays: [
                RoutineDay(dayOfWeek: 2, title: "Legs & Core", description: "Squats, lunges, deadlifts, planks."),
                RoutineDay(dayOfWeek: 4, title: "Upper Body", description: "Bench press, pull-ups, rows, pushups."),
                RoutineDay(dayOfWeek: 6, title: "Mobility Reset", description: "Mobility drills and stretching.")
            ]
        ),
        WorkoutRoutine(
            name: "Shift Cardio",
            goal: "Cardio",
            estimatedDurationMinutes: 30,
            scheduleDays: [
                RoutineDay(dayOfWeek: 3, title: "Intervals", description: "20 min HIIT ride + cooldown."),
                RoutineDay(dayOfWeek: 5, title: "Steady Run", description: "3 mile conversational pace.")
            ]
        ),
        WorkoutRoutine(
            name: "Recovery Flow",
            goal: "Mobility",
            estimatedDurationMinutes: 25,
            scheduleDays: [
                RoutineDay(dayOfWeek: 1, title: "Yoga Flow", description: "Slow flow and breathwork."),
                RoutineDay(dayOfWeek: 7, title: "Stretch & Reset", description: "Foam roll, hips, shoulders.")
            ]
        )
    ]
}

struct RoutineDay: Identifiable, Hashable {
    let id: UUID
    var dayOfWeek: Int
    var title: String
    var description: String

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        title: String,
        description: String
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.title = title
        self.description = description
    }

    var weekdayName: String {
        LockerWeekday(rawValue: dayOfWeek)?.shortLabel ?? "Day"
    }
}

enum LockerWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var longLabel: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    func addingMonths(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func weekday(using calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: self)
    }
}
