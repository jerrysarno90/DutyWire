import SwiftUI

struct LockerSavingsDashboardView: View {
    @State private var categories: [LockerBudgetCategory] = [
        LockerBudgetCategory(name: "Housing", planned: 1400, actual: 1350),
        LockerBudgetCategory(name: "Food", planned: 600, actual: 520),
        LockerBudgetCategory(name: "Fuel", planned: 300, actual: 210),
        LockerBudgetCategory(name: "Childcare", planned: 450, actual: 470),
    ]
    @State private var goals = LockerSavingsGoal.sampleGoals
    @State private var showingAddGoal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                budgetSummary
                goalSection
                recentActivity
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(LockerSavingsBackground().ignoresSafeArea())
        .navigationTitle("Savings & Budget")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddGoal = true
                } label: {
                    Label("Add goal", systemImage: "target")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            LockerGoalEditor { goal in
                goals.append(goal)
            }
            .presentationDetents([.medium])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Money made visual")
                .font(.title2.weight(.semibold))
            Text("Private workbook for budgets, goals, and off-duty jobs.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("🔒 Stored in My Locker. Not shared with your agency.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly budget")
                .font(.headline)
            ForEach(categories) { category in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(currency(category.actual))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("/ \(currency(category.planned))")
                            .font(.subheadline.weight(.semibold))
                    }
                    ProgressView(value: category.progress)
                        .tint(category.remaining >= 0 ? Color.blue : Color.red)
                }
            }
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Savings goals")
                .font(.headline)
            ForEach(goals) { goal in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(goal.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(goal.targetDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: goal.progress) {
                        Text("\(currency(goal.savedAmount)) / \(currency(goal.targetAmount))")
                            .font(.caption.weight(.semibold))
                    }
                    .tint(.green)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent activity")
                .font(.headline)
            ForEach(sampleTransactions) { transaction in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.title)
                            .font(.subheadline.weight(.semibold))
                        Text(transaction.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(transaction.isCredit ? "+" : "-")\(currency(transaction.amount))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(transaction.isCredit ? .green : .primary)
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private var sampleTransactions: [LockerTransaction] {
        [
            LockerTransaction(title: "Neighborhood overtime", category: "Extra income", amount: 220, isCredit: true),
            LockerTransaction(title: "Meal prep kit", category: "Food", amount: 72, isCredit: false),
            LockerTransaction(title: "BJJ gym", category: "Training", amount: 95, isCredit: false),
        ]
    }
}

private struct LockerTransaction: Identifiable {
    let id = UUID()
    var title: String
    var category: String
    var amount: Double
    var isCredit: Bool
}

private struct LockerGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var targetAmount: Double = 1000
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: .now)!
    let onSave: (LockerSavingsGoal) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal title", text: $title)
                Stepper(value: $targetAmount, step: 100, format: .currency(code: "USD")) {
                    Text("Target amount \(targetAmount, format: .currency(code: "USD"))")
                }
                DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
            }
            .navigationTitle("Add savings goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let goal = LockerSavingsGoal(
                            title: title.isEmpty ? "New goal" : title,
                            targetAmount: targetAmount,
                            savedAmount: 0,
                            targetDate: targetDate
                        )
                        onSave(goal)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LockerSavingsBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct MoneyGoalsDashboardView: View {
    @StateObject private var calculatorStore = BudgetingCalculatorStore()
    @State private var goals: [MoneyGoal] = MoneyGoal.sampleGoals
    @State private var selectedGoal: MoneyGoal?
    @State private var pendingActionGoal: MoneyGoal?
    @State private var showingGoalActions = false
    @State private var contributionTarget: MoneyGoal?
    @State private var editorMode: MoneyGoalEditorMode?
    @State private var editorSuggestion: MoneyGoalEditorSuggestion?

    enum MoneyGoalEditorMode: Identifiable {
        case add
        case edit(MoneyGoal)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let goal): return goal.id.uuidString
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                summaryCard
                BudgetingCalculatorView(store: calculatorStore)
                ForEach(goals) { goal in
                    Button {
                        pendingActionGoal = goal
                        showingGoalActions = true
                    } label: {
                        MoneyGoalRow(goal: goal)
                    }
                    .buttonStyle(.plain)
                }
                if goals.isEmpty {
                    EmptyGoalState(addAction: presentAdd)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Money Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: presentAdd) {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .accessibilityLabel("Add goal")
            }
        }
        .sheet(item: $selectedGoal) { goal in
            MoneyGoalDetailView(goal: goal) { updated in
                updateGoal(updated)
                selectedGoal = updated
            } onDelete: {
                goals.removeAll { $0.id == goal.id }
            } onContribution: { amount in
                applyContribution(amount, to: goal)
            }
        }
        .sheet(item: $contributionTarget) { goal in
            ContributionEntryView { amount in
                applyContribution(amount, to: goal)
                contributionTarget = nil
            } onCancel: {
                contributionTarget = nil
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                MoneyGoalEditorView(mode: mode, suggestion: editorSuggestion) { result in
                    switch result {
                    case .created(let goal): goals.append(goal)
                    case .updated(let goal): updateGoal(goal)
                    }
                    editorMode = nil
                    editorSuggestion = nil
                } onCancel: {
                    editorMode = nil
                    editorSuggestion = nil
                }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Choose action", isPresented: $showingGoalActions, presenting: pendingActionGoal) { goal in
            Button("Add Contribution") {
                contributionTarget = goal
                showingGoalActions = false
            }
            Button("Manage Goal") {
                selectedGoal = goal
                showingGoalActions = false
            }
            Button("Cancel", role: .cancel) {}
        } message: { goal in
            Text("What would you like to do with \(goal.title)?")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Savings Planner")
                .font(.title2.weight(.semibold))
            Text("Plan private financial goals. Not shared with your agency.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("🔒 Private to you")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Goals")
                .font(.headline)
            Text("You have \(goals.count) goal\(goals.count == 1 ? "" : "s").")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let avg = averageProgress {
                ProgressView(value: avg)
                    .tint(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var averageProgress: Double? {
        guard !goals.isEmpty else { return nil }
        return goals.map(\.progress).reduce(0, +) / Double(goals.count)
    }

    private func presentAdd() {
        editorSuggestion = calculatorStore.goalSuggestion
        editorMode = .add
    }

    private func updateGoal(_ goal: MoneyGoal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        }
    }

    private func applyContribution(_ amount: Double, to goal: MoneyGoal) {
        guard amount > 0 else { return }
        let updated = goal.addingContribution(amount)
        updateGoal(updated)
        selectedGoal = updated
    }
}

private struct MoneyGoalRow: View {
    let goal: MoneyGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Text(goal.targetAmount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: goal.progress) {
                Text(String(format: "%.0f%%", goal.progress * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let line = summaryLine {
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private var summaryLine: String? {
        switch goal.mode {
        case .targetDate:
            guard let monthly = goal.requiredMonthlySavings,
                  let perCheck = goal.requiredPerPaycheckSavings,
                  let date = goal.targetDate else { return nil }
            let monthlyText = monthly.formatted(.currency(code: "USD"))
            let perCheckText = perCheck.formatted(.currency(code: "USD"))
            return "Save \(monthlyText)/mo (≈ \(perCheckText) per \(goal.payFrequency.displayName.lowercased())) to finish by \(date.formatted(date: .abbreviated, time: .omitted))."
        case .monthlyAmount:
            guard let monthly = goal.monthlyContribution,
                  let months = goal.monthsNeeded,
                  let date = goal.estimatedCompletionDate else { return nil }
            let monthlyText = monthly.formatted(.currency(code: "USD"))
            return "\(monthlyText)/mo • \(months) mo • ~\(date.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

private struct BudgetingCalculatorView: View {
    @ObservedObject var store: BudgetingCalculatorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Budgeting calculator")
                    .font(.headline)
                Text("Estimate leftover cash after expenses and include off-duty + overtime earnings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Base income")
                currencyStepperRow(
                    title: "Monthly take-home",
                    value: binding(\.baseMonthlyIncome),
                    range: 0...20_000,
                    step: 100
                )
                Divider()
                sectionLabel("Off-duty work")
                hoursStepperRow(
                    title: "Hours per month",
                    value: binding(\.offDutyHours),
                    range: 0...80,
                    step: 1
                )
                currencyStepperRow(
                    title: "Rate per hour",
                    value: binding(\.offDutyRate),
                    range: 0...150,
                    step: 5
                )
                Text("Adds \(store.offDutyIncome.formatted(.currency(code: "USD")))/mo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                sectionLabel("Overtime")
                hoursStepperRow(
                    title: "Hours per month",
                    value: binding(\.overtimeHours),
                    range: 0...80,
                    step: 1
                )
                currencyStepperRow(
                    title: "Rate per hour",
                    value: binding(\.overtimeRate),
                    range: 0...200,
                    step: 5
                )
                Text("Adds \(store.overtimeIncome.formatted(.currency(code: "USD")))/mo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                sectionLabel("Expenses")
                currencyStepperRow(
                    title: "Essential costs",
                    value: binding(\.essentialExpenses),
                    range: 0...15_000,
                    step: 100
                )
                currencyStepperRow(
                    title: "Lifestyle & extras",
                    value: binding(\.lifestyleExpenses),
                    range: 0...10_000,
                    step: 100
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Pay frequency")
                Picker("Pay frequency", selection: binding(\.payFrequency)) {
                    ForEach(MoneyGoalPayFrequency.allCases) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Summary")
                ProgressView(value: store.surplusPercentage) {
                    Text("Available for goals")
                        .font(.subheadline.weight(.semibold))
                } currentValueLabel: {
                    Text(store.availableForGoals.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.semibold))
                }
                .tint(.green)
                Text("That's about \(store.perPaycheckAvailable.formatted(.currency(code: "USD")))/paycheck.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                KeyValueRow(title: "Monthly income", value: store.totalMonthlyIncome.formatted(.currency(code: "USD")))
                KeyValueRow(title: "Off-duty + OT boost", value: (store.offDutyIncome + store.overtimeIncome).formatted(.currency(code: "USD")))
                KeyValueRow(title: "Monthly expenses", value: store.totalMonthlyExpenses.formatted(.currency(code: "USD")))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func currencyStepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                CurrencyEditableField(value: value, range: range)
            }
        }
    }

    @ViewBuilder
    private func hoursStepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                HoursEditableField(value: value, range: range)
            }
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<BudgetingCalculatorStore, Value>) -> Binding<Value> {
        Binding(
            get: { store[keyPath: keyPath] },
            set: { store[keyPath: keyPath] = $0 }
        )
    }
}

private struct CurrencyEditableField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        TextField("", value: $value, format: .currency(code: "USD"))
            .multilineTextAlignment(.trailing)
            .font(.subheadline.weight(.semibold))
            .keyboardType(.decimalPad)
            .submitLabel(.done)
            .onChange(of: value) { _, newValue in
                clamp(to: newValue)
            }
    }

    private func clamp(to newValue: Double) {
        if newValue < range.lowerBound {
            value = range.lowerBound
        } else if newValue > range.upperBound {
            value = range.upperBound
        }
    }
}

private struct HoursEditableField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .frame(minWidth: 60)
                .onChange(of: value) { _, newValue in
                    clamp(to: newValue)
                }
            Text("hrs")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func clamp(to newValue: Double) {
        if newValue < range.lowerBound {
            value = range.lowerBound
        } else if newValue > range.upperBound {
            value = range.upperBound
        }
    }
}

private struct EmptyGoalState: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Plan your first goal")
                .font(.headline)
            Text("Track vacations, debt payoff, or new gear with simple math.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Add Goal", action: addAction)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Detail

private struct MoneyGoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goal: MoneyGoal
    let onUpdate: (MoneyGoal) -> Void
    let onDelete: () -> Void
    let onContribution: (Double) -> Void
    @State private var showingContribution = false
    @State private var showingEditor = false

    init(goal: MoneyGoal,
         onUpdate: @escaping (MoneyGoal) -> Void,
         onDelete: @escaping () -> Void,
         onContribution: @escaping (Double) -> Void) {
        _goal = State(initialValue: goal)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onContribution = onContribution
    }

    var body: some View {
        List {
            VStack(spacing: 6) {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Swipe down to close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.title)
                        .font(.title3.weight(.semibold))
                    ProgressView(value: goal.progress)
                    Text("\(goal.currentAmount, format: .currency(code: "USD")) of \(goal.targetAmount, format: .currency(code: "USD"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Plan") {
                if let rowData = planRows {
                    ForEach(Array(rowData.enumerated()), id: \.offset) { _, row in
                        KeyValueRow(title: row.title, value: row.value)
                    }
                }
            }

            if !goal.contributions.isEmpty {
                Section("Contributions") {
                    ForEach(goal.contributions) { contribution in
                        HStack {
                            Text(contribution.date, style: .date)
                            Spacer()
                            Text(contribution.amount, format: .currency(code: "USD"))
                        }
                    }
                }
            }
        }
        .navigationTitle("Goal Details")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit") { showingEditor = true }
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Add contribution") {
                    showingContribution = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingContribution) {
            ContributionEntryView { amount in
                onContribution(amount)
                goal = goal.addingContribution(amount)
                showingContribution = false
            } onCancel: {
                showingContribution = false
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                MoneyGoalEditorView(mode: .edit(goal)) { result in
                    if case .updated(let updated) = result {
                        goal = updated
                        onUpdate(updated)
                    }
                    showingEditor = false
                } onCancel: {
                    showingEditor = false
                }
            }
        }
    }

    private var planRows: [(title: String, value: String)]? {
        switch goal.mode {
        case .targetDate:
            guard let target = goal.targetDate,
                  let monthly = goal.requiredMonthlySavings,
                  let perCheck = goal.requiredPerPaycheckSavings else { return nil }
            return [
                ("Target date", target.formatted(date: .abbreviated, time: .omitted)),
                ("Save per month", monthly.formatted(.currency(code: "USD"))),
                ("Per \(goal.payFrequency.displayName)", perCheck.formatted(.currency(code: "USD")))
            ]
        case .monthlyAmount:
            guard let monthly = goal.monthlyContribution,
                  let months = goal.monthsNeeded,
                  let completion = goal.estimatedCompletionDate else { return nil }
            return [
                ("Monthly amount", monthly.formatted(.currency(code: "USD"))),
                ("Months needed", "\(months)"),
                ("Est. completion", completion.formatted(date: .abbreviated, time: .omitted))
            ]
        }
    }
}

private struct KeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ContributionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 100
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Stepper(value: $amount, in: 10...10000, step: 25) {
                    Text("Amount: \(amount, format: .currency(code: "USD"))")
                }
            }
            .navigationTitle("Contribution")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(amount)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Editor

enum MoneyGoalEditorResult {
    case created(MoneyGoal)
    case updated(MoneyGoal)
}

struct MoneyGoalEditorView: View {
    let mode: MoneyGoalsDashboardView.MoneyGoalEditorMode
    let suggestion: MoneyGoalEditorSuggestion?
    let onSave: (MoneyGoalEditorResult) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var targetAmount: Double = 1000
    @State private var startDate: Date = .now
    @State private var planningMode: MoneyGoalPlanningMode = .targetDate
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var monthlyContribution: Double = 250
    @State private var payFrequency: MoneyGoalPayFrequency = .monthly
    @State private var seedAmount: Double = 0

    init(mode: MoneyGoalsDashboardView.MoneyGoalEditorMode,
         suggestion: MoneyGoalEditorSuggestion? = nil,
         onSave: @escaping (MoneyGoalEditorResult) -> Void,
         onCancel: @escaping () -> Void) {
        self.mode = mode
        self.suggestion = suggestion
        self.onSave = onSave
        self.onCancel = onCancel
        switch mode {
        case .add:
            if let suggestion {
                _planningMode = State(initialValue: suggestion.planningMode)
                if let monthly = suggestion.monthlyContribution {
                    let clamped = min(max(monthly, 50), 5_000)
                    _monthlyContribution = State(initialValue: clamped)
                }
                _payFrequency = State(initialValue: suggestion.payFrequency)
            }
        case .edit(let goal):
            _title = State(initialValue: goal.title)
            _targetAmount = State(initialValue: goal.targetAmount)
            _startDate = State(initialValue: goal.createdAt)
            _planningMode = State(initialValue: goal.mode)
            _targetDate = State(initialValue: goal.targetDate ?? Date())
            _monthlyContribution = State(initialValue: goal.monthlyContribution ?? 250)
            _payFrequency = State(initialValue: goal.payFrequency)
            _seedAmount = State(initialValue: goal.currentAmount)
        }
    }

    var body: some View {
        Form {
            Section("Goal Info") {
                TextField("Goal name", text: $title)
                Stepper(value: $targetAmount, in: 100...100_000, step: 100, format: .currency(code: "USD")) {
                    Text("Target amount: \(targetAmount, format: .currency(code: "USD"))")
                }
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                Stepper(value: $seedAmount, in: 0...targetAmount, step: 50, format: .currency(code: "USD")) {
                    Text("Already saved: \(seedAmount, format: .currency(code: "USD"))")
                }
            }

            Section("Planning Mode") {
                Picker("Mode", selection: $planningMode) {
                    ForEach(MoneyGoalPlanningMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch planningMode {
                case .targetDate:
                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                    Picker("Pay frequency", selection: $payFrequency) {
                        ForEach(MoneyGoalPayFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                case .monthlyAmount:
                    Stepper(value: $monthlyContribution, in: 50...5000, step: 50, format: .currency(code: "USD")) {
                        Text("Monthly contribution: \(monthlyContribution, format: .currency(code: "USD"))")
                    }
                }
            }
        }
        .navigationTitle(modeTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Add Money Goal"
        case .edit: return "Edit Goal"
        }
    }

    private func save() {
        var goal = MoneyGoal(
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Money Goal" : title,
            targetAmount: targetAmount,
            currentAmount: seedAmount,
            createdAt: startDate,
            mode: planningMode,
            targetDate: planningMode == .targetDate ? targetDate : nil,
            monthlyContribution: planningMode == .monthlyAmount ? monthlyContribution : nil,
            payFrequency: payFrequency
        )
        switch mode {
        case .add:
            onSave(.created(goal))
        case .edit(let existing):
            goal = MoneyGoal(
                id: existing.id,
                title: goal.title,
                targetAmount: goal.targetAmount,
                currentAmount: goal.currentAmount,
                createdAt: goal.createdAt,
                mode: goal.mode,
                targetDate: goal.targetDate,
                monthlyContribution: goal.monthlyContribution,
                payFrequency: goal.payFrequency,
                contributions: existing.contributions
            )
            onSave(.updated(goal))
        }
        dismiss()
    }
}
