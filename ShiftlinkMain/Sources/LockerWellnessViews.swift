import SwiftUI

struct LockerWellnessHomeView: View {
    @State private var workouts = LockerWorkoutPlan.samples
    @State private var routines = WorkoutRoutine.sampleRoutines
    @State private var selectedWorkout: LockerWorkoutPlan?
    @State private var showingDailyCheckIn = false
    @State private var showingVitals = false
    @State private var checkIns: [DailyCheckInEntry] = DailyCheckInEntry.samples
    @State private var vitals: [VitalEntry] = VitalEntry.samples

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                lockerHeader
                workoutLibrary
                dailyCheckInSection
                metricsVitalsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(LockerGradientBackground().ignoresSafeArea())
        .navigationTitle("Wellness HQ")
        .sheet(item: $selectedWorkout) { workout in
            LockerWorkoutDetailView(workout: workout)
        }
        .sheet(isPresented: $showingDailyCheckIn) {
            DailyCheckInView { entry in
                checkIns.append(entry)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingVitals) {
            MetricsVitalsView { entry in
                vitals.append(entry)
            }
            .presentationDetents([.medium])
        }
    }

    private var lockerHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Balance the grind")
                .font(.title2.weight(.semibold))
            Text("Create workouts, track your sleep and moods, stay on top of your vitals.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("🔒 Stored in My Locker. Not shared with your agency.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var workoutLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workout library")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    WorkoutLibraryView(routines: $routines)
                } label: {
                    Text("Manage My Workouts")
                        .font(.footnote.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            todaysPlannedWorkoutCard
        }
    }

    private var dailyCheckInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Check-in")
                .font(.headline)
            dailyCheckInCard
        }
    }

    private var metricsVitalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metrics & Vitals")
                .font(.headline)
            metricsVitalsCard
        }
    }

    private var todaysPlannedWorkoutCard: some View {
        let workoutsToday = routines.flatMap { routine -> [(WorkoutRoutine, RoutineDay)] in
            let matches = routine.workouts(on: Date())
            return matches.map { (routine, $0) }
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Today's Planned Workout")
                .font(.headline)
            if let first = workoutsToday.first {
                Text("Today: \(first.0.name) – \(first.1.title)")
                    .font(.title3.weight(.semibold))
                Text("\(first.0.estimatedDurationMinutes) min · Goal: \(first.0.goal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No workout scheduled for today.")
                    .font(.subheadline.weight(.semibold))
                Text("Tap a date or manage routines to add one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 8)
    }

    private var dailyCheckInCard: some View {
        let lastDate = checkIns.last?.date
        let dayText = lastDate?.formatted(.dateTime.weekday(.abbreviated)) ?? "—"
        let avgSleep = averageSleep
        let avgStress = averageStress
        let avgMood = averageMood
        return Button {
            showingDailyCheckIn = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                Text("Log sleep, stress, and mood in under a minute.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Last check-in: \(dayText) • \(checkInStreak(for: checkIns))-day streak")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.blue)
                if let avgSleep, let avgStress, let avgMood {
                    Text("Avg \(avgSleep, specifier: "%.1f")h sleep • Stress \(avgStress, specifier: "%.1f") • Mood \(avgMood, specifier: "%.1f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var metricsVitalsCard: some View {
        let latest = vitals.last
        return Button {
            showingVitals = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(.blue)
                }
                Text("Track weight, BP, or other vitals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Last update: \(latest?.date.formatted(date: .abbreviated, time: .omitted) ?? "—")")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.blue)
                if let latest {
                    Text("Weight \(latest.weight) lbs • BP \(latest.systolic)/\(latest.diastolic) • \(latest.pulse) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var averageSleep: Double? {
        guard !checkIns.isEmpty else { return nil }
        return checkIns.map(\.sleepHours).reduce(0, +) / Double(checkIns.count)
    }

    private var averageStress: Double? {
        guard !checkIns.isEmpty else { return nil }
        return Double(checkIns.map(\.stressLevel).reduce(0, +)) / Double(checkIns.count)
    }

    private var averageMood: Double? {
        guard !checkIns.isEmpty else { return nil }
        return Double(checkIns.map(\.moodLevel).reduce(0, +)) / Double(checkIns.count)
    }

    private func checkInStreak(for entries: [DailyCheckInEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        let sorted = entries.sorted { $0.date > $1.date }
        var streak = 0
        var currentDate = sorted.first!.date.startOfDay
        let calendar = Calendar.current

        for entry in sorted {
            let day = entry.date.startOfDay
            if calendar.isDate(day, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if day < currentDate {
                break
            }
        }

        return streak
    }
}

private struct LockerWorkoutDetailView: View {
    var workout: LockerWorkoutPlan

    var body: some View {
        Form {
            Section("Focus") {
                Text(workout.focus)
            }

            Section("Duration") {
                Text("\(workout.duration) minutes")
            }

            Section("Guidance") {
                Text("Warm-up, circuit work, and mobility drills tailored for shift work. Track completion inside My Locker.")
            }
        }
        .navigationTitle(workout.title)
    }
}
struct WorkoutLibraryView: View {
    @Binding var routines: [WorkoutRoutine]
    @State private var selectedDate: Date = Date().startOfDay
    @State private var displayedMonth: Date = Date().startOfMonth

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                todaysPlannedCard
                calendarCard
                workoutsForSelectedDate
                routinesStrip
                manageButton
            }
            .padding(20)
        }
        .background(LockerGradientBackground().ignoresSafeArea())
        .navigationTitle("Workout Library")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Workout Library")
                .font(.largeTitle.weight(.semibold))
            Text("Plan weekly workouts, build routines, and keep your training honest.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todaysPlannedCard: some View {
        let workoutsToday = workouts(for: Date())
        return VStack(alignment: .leading, spacing: 8) {
            Text("Today's Planned Workout")
                .font(.headline)
            if let first = workoutsToday.first {
                Text("Today: \(first.0.name) – \(first.1.title)")
                    .font(.title3.weight(.semibold))
                Text("\(first.0.estimatedDurationMinutes) min · Goal: \(first.0.goal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No workout scheduled for today.")
                    .font(.subheadline.weight(.semibold))
                Text("Tap a date or manage routines to add one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 8)
    }


    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedule")
                    .font(.headline)
                Spacer()
                Button(action: { displayedMonth = displayedMonth.addingMonths(-1); selectedDate = displayedMonth }) {
                    Image(systemName: "chevron.left")
                }
                Button(action: { displayedMonth = displayedMonth.addingMonths(1); selectedDate = displayedMonth }) {
                    Image(systemName: "chevron.right")
                }
            }
            Text(displayedMonth.formatted(.dateTime.month().year()))
                .font(.callout.weight(.semibold))

            VStack(spacing: 8) {
                HStack {
                    ForEach(weekdaySymbols(), id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(monthGridDates().enumerated()), id: \.offset) { _, date in
                        if let date {
                            Button {
                                selectedDate = date
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .foregroundStyle(isSameDay(date, selectedDate) ? Color.white : Color.primary)
                                    Circle()
                                        .fill(hasWorkouts(on: date) ? Color.blue : Color.clear)
                                        .frame(width: 6, height: 6)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSameDay(date, selectedDate) ? Color.blue : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 32)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
            )
        }
    }

    private var workoutsForSelectedDate: some View {
        let workouts = workouts(for: selectedDate)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Workouts for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.headline)
            if workouts.isEmpty {
                Text("No workouts scheduled for this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workouts, id: \.1.id) { routine, day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(routine.name) – \(day.title)")
                            .font(.subheadline.weight(.semibold))
                        Text("Goal: \(routine.goal) • \(routine.estimatedDurationMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
                }
            }
        }
    }

    private var routinesStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Routines")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ManageRoutinesView(routines: $routines)
                } label: {
                    Text("Manage Routines")
                        .font(.footnote.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(routines) { routine in
                        NavigationLink {
                            RoutineDetailView(mode: .edit(routine)) { updated in
                                updateRoutine(updated)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(routine.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(routine.goal)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(routine.estimatedDurationMinutes) min")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                            .padding()
                            .frame(width: 180, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.systemBackground))
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var manageButton: some View {
        NavigationLink {
            ManageRoutinesView(routines: $routines)
        } label: {
            Text("+ Manage Workout Routines")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Helpers
    private func workouts(for date: Date) -> [(WorkoutRoutine, RoutineDay)] {
        routines.flatMap { routine -> [(WorkoutRoutine, RoutineDay)] in
            let matches = routine.workouts(on: date)
            return matches.map { (routine, $0) }
        }
    }

    private func hasWorkouts(on date: Date) -> Bool {
        !workouts(for: date).isEmpty
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func monthGridDates() -> [Date?] {
        let start = displayedMonth.startOfMonth
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: start)
        let adjustment = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dates: [Date?] = Array(repeating: nil, count: adjustment)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                dates.append(date)
            }
        }
        return dates
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        let prefix = symbols[startIndex...]
        let suffix = symbols[..<startIndex]
        return Array(prefix + suffix)
    }

    private func updateRoutine(_ routine: WorkoutRoutine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        }
    }

}

struct ManageRoutinesView: View {
    @Binding var routines: [WorkoutRoutine]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    RoutineDetailView(mode: .create) { newRoutine in
                        routines.append(newRoutine)
                    }
                } label: {
                    Label("+ New Routine", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }

            Section("Your routines") {
                if routines.isEmpty {
                    Text("No routines yet. Tap “+ New Routine” to build a weekly plan.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routines) { routine in
                        NavigationLink {
                            RoutineDetailView(mode: .edit(routine)) { updated in
                                if let index = routines.firstIndex(where: { $0.id == updated.id }) {
                                    routines[index] = updated
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.name)
                                    .font(.headline)
                                Text("Goal: \(routine.goal)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Estimated: \(routine.estimatedDurationMinutes) min · \(routine.activeDaysPerWeek) day(s)/week")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .onDelete { offsets in
                        routines.remove(atOffsets: offsets)
                    }
                }
            }
        }
        .navigationTitle("Manage Routines")
        .listStyle(.insetGrouped)
    }
}

struct RoutineDetailView: View {
    enum Mode {
        case create
        case edit(WorkoutRoutine)
    }

    struct RoutineDayFields {
        var id: UUID = UUID()
        var title: String = ""
        var description: String = ""
    }

    let mode: Mode
    let onSave: (WorkoutRoutine) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var goal: String = "Strength"
    @State private var estimatedDuration: Int = 30
    @State private var notes: String = ""
    @State private var selectedDays: Set<Int> = []
    @State private var dayFields: [Int: RoutineDayFields] = [:]

    private let goalOptions = ["Strength", "Cardio", "Mobility", "Mixed"]

    init(mode: Mode, onSave: @escaping (WorkoutRoutine) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            break
        case .edit(let routine):
            _name = State(initialValue: routine.name)
            _goal = State(initialValue: routine.goal)
            _estimatedDuration = State(initialValue: routine.estimatedDurationMinutes)
            _notes = State(initialValue: routine.notes)
            let days = routine.scheduleDays
            _selectedDays = State(initialValue: Set(days.map(\.dayOfWeek)))
            var initialFields: [Int: RoutineDayFields] = [:]
            for day in days {
                initialFields[day.dayOfWeek] = RoutineDayFields(id: day.id, title: day.title, description: day.description)
            }
            _dayFields = State(initialValue: initialFields)
        }
    }

    var body: some View {
        Form {
            Section("Routine Basics") {
                TextField("Routine name", text: $name)
                Picker("Goal", selection: $goal) {
                    ForEach(goalOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                Stepper(value: $estimatedDuration, in: 10...120, step: 5) {
                    Text("Estimated duration: \(estimatedDuration) min")
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    .padding(.vertical, 4)
            }

            Section("Weekly Schedule") {
                Text("Which days is this routine for?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(LockerWeekday.allCases) { weekday in
                        let isSelected = selectedDays.contains(weekday.rawValue)
                        Button {
                            toggleDay(weekday.rawValue)
                        } label: {
                            Text(weekday.shortLabel)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.blue : Color(.systemGray6))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)

                ForEach(selectedDays.sorted(), id: \.self) { dayValue in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LockerWeekday(rawValue: dayValue)?.longLabel ?? "Day")
                            .font(.subheadline.weight(.semibold))
                        TextField("Day title / focus", text: bindingForDay(dayValue).title)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: bindingForDay(dayValue).description)
                            .frame(minHeight: 70)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                Button(action: saveRoutine) {
                    Text("Save Routine")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle(modeTitle)
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "New Routine"
        case .edit: return "Edit Routine"
        }
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
            dayFields.removeValue(forKey: day)
        } else {
            selectedDays.insert(day)
            if dayFields[day] == nil {
                let defaultTitle = LockerWeekday(rawValue: day)?.longLabel ?? "Workout"
                dayFields[day] = RoutineDayFields(title: defaultTitle, description: "")
            }
        }
    }

    private func bindingForDay(_ day: Int) -> (title: Binding<String>, description: Binding<String>) {
        let titleBinding = Binding<String>(
            get: { dayFields[day]?.title ?? "" },
            set: { dayFields[day, default: RoutineDayFields()].title = $0 }
        )
        let descriptionBinding = Binding<String>(
            get: { dayFields[day]?.description ?? "" },
            set: { dayFields[day, default: RoutineDayFields()].description = $0 }
        )
        return (titleBinding, descriptionBinding)
    }

    private func saveRoutine() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let sortedDays = selectedDays.sorted()
        let schedule = sortedDays.compactMap { dayValue -> RoutineDay? in
            guard var fields = dayFields[dayValue] else {
                let defaultTitle = LockerWeekday(rawValue: dayValue)?.longLabel ?? "Workout"
                return RoutineDay(dayOfWeek: dayValue, title: defaultTitle, description: "")
            }
            fields.title = fields.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if fields.title.isEmpty {
                fields.title = LockerWeekday(rawValue: dayValue)?.longLabel ?? "Workout"
            }
            fields.description = fields.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return RoutineDay(id: fields.id, dayOfWeek: dayValue, title: fields.title, description: fields.description)
        }

        var routine = WorkoutRoutine(
            name: trimmedName,
            goal: goal,
            estimatedDurationMinutes: estimatedDuration,
            notes: notes,
            scheduleDays: schedule
        )

        if case .edit(let existing) = mode {
            routine = WorkoutRoutine(
                id: existing.id,
                name: trimmedName,
                goal: goal,
                estimatedDurationMinutes: estimatedDuration,
                notes: notes,
                scheduleDays: schedule
            )
        }

        onSave(routine)
        dismiss()
    }
}

private struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sleepHours: Double = 6.5
    @State private var stressLevel: Int = 3
    @State private var moodLevel: Int = 4
    @State private var notes: String = ""
    let onSave: (DailyCheckInEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Sleep") {
                    Slider(value: $sleepHours, in: 0...12, step: 0.5)
                    Text("\(sleepHours, specifier: "%.1f") hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Stress") {
                    Picker("Stress level", selection: $stressLevel) {
                        ForEach(1..<6) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Mood") {
                    Picker("Mood", selection: $moodLevel) {
                        ForEach(1..<6) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Daily Check-in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            DailyCheckInEntry(
                                date: Date(),
                                sleepHours: sleepHours,
                                stressLevel: stressLevel,
                                moodLevel: moodLevel,
                                notes: notes
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }

}

private struct MetricsVitalsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weight: String = ""
    @State private var systolic: String = ""
    @State private var diastolic: String = ""
    @State private var pulse: String = ""
    let onSave: (VitalEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    TextField("Weight (lbs)", text: $weight)
                        .keyboardType(.decimalPad)
                }
                Section("Blood Pressure") {
                    TextField("Systolic", text: $systolic)
                        .keyboardType(.numberPad)
                    TextField("Diastolic", text: $diastolic)
                        .keyboardType(.numberPad)
                    TextField("Pulse", text: $pulse)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Metrics & Vitals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            VitalEntry(
                                date: Date(),
                                weight: Double(weight) ?? 0,
                                systolic: Int(systolic) ?? 0,
                                diastolic: Int(diastolic) ?? 0,
                                pulse: Int(pulse) ?? 0
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LockerGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemGray6),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct DailyCheckInEntry: Identifiable {
    let id = UUID()
    let date: Date
    let sleepHours: Double
    let stressLevel: Int
    let moodLevel: Int
    let notes: String

    static let samples: [DailyCheckInEntry] = [
        DailyCheckInEntry(date: .now.addingTimeInterval(-86400), sleepHours: 6.5, stressLevel: 3, moodLevel: 4, notes: ""),
        DailyCheckInEntry(date: .now.addingTimeInterval(-172800), sleepHours: 7.0, stressLevel: 2, moodLevel: 4, notes: "")
    ]
}

struct VitalEntry: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let systolic: Int
    let diastolic: Int
    let pulse: Int

    static let samples: [VitalEntry] = [
        VitalEntry(date: .now.addingTimeInterval(-259200), weight: 185, systolic: 120, diastolic: 78, pulse: 70)
    ]
}
