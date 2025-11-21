import Foundation
import SwiftUI

// MARK: - Savings

struct LockerBudgetCategory: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var planned: Double
    var actual: Double

    var remaining: Double { planned - actual }
    var progress: Double {
        guard planned > 0 else { return 0 }
        return min(max(actual / planned, 0), 1)
    }
}

struct LockerSavingsGoal: Identifiable {
    let id = UUID()
    var title: String
    var targetAmount: Double
    var savedAmount: Double
    var targetDate: Date

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(savedAmount / targetAmount, 1)
    }

    static let sampleGoals: [LockerSavingsGoal] = [
        LockerSavingsGoal(
            title: "Family vacation",
            targetAmount: 3500,
            savedAmount: 2100,
            targetDate: Calendar.current.date(byAdding: .month, value: 6, to: .now)!
        ),
        LockerSavingsGoal(
            title: "Backup fund",
            targetAmount: 5000,
            savedAmount: 3800,
            targetDate: Calendar.current.date(byAdding: .month, value: 12, to: .now)!
        ),
    ]
}

// MARK: - Money Goals

enum MoneyGoalPlanningMode: String, CaseIterable, Identifiable {
    case targetDate
    case monthlyAmount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .targetDate: return "Target Date"
        case .monthlyAmount: return "Monthly Amount"
        }
    }
}

enum MoneyGoalPayFrequency: String, CaseIterable, Identifiable {
    case monthly
    case biweekly
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .biweekly: return "Bi-Weekly"
        case .weekly: return "Weekly"
        }
    }

    var periodsPerMonth: Double {
        switch self {
        case .monthly: return 1
        case .biweekly: return 2
        case .weekly: return 4
        }
    }
}

struct MoneyGoalContribution: Identifiable, Hashable {
    let id = UUID()
    let amount: Double
    let date: Date
}

struct MoneyGoal: Identifiable, Hashable {
    let id: UUID
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var createdAt: Date
    var mode: MoneyGoalPlanningMode
    var targetDate: Date?
    var monthlyContribution: Double?
    var payFrequency: MoneyGoalPayFrequency
    var contributions: [MoneyGoalContribution]

    init(
        id: UUID = UUID(),
        title: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        createdAt: Date = .now,
        mode: MoneyGoalPlanningMode,
        targetDate: Date? = nil,
        monthlyContribution: Double? = nil,
        payFrequency: MoneyGoalPayFrequency = .monthly,
        contributions: [MoneyGoalContribution] = []
    ) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.createdAt = createdAt
        self.mode = mode
        self.targetDate = targetDate
        self.monthlyContribution = monthlyContribution
        self.payFrequency = payFrequency
        self.contributions = contributions
    }

    var remainingAmount: Double {
        max(targetAmount - currentAmount, 0)
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    /// Mode A: required monthly savings to hit target date
    var requiredMonthlySavings: Double? {
        guard mode == .targetDate,
              let targetDate,
              targetDate > createdAt
        else { return nil }
        let months = max(createdAt.monthsUntil(targetDate), 1)
        guard months > 0 else { return nil }
        return ceilCurrency(remainingAmount / Double(months))
    }

    var requiredPerPaycheckSavings: Double? {
        guard let monthly = requiredMonthlySavings else { return nil }
        return ceilCurrency(monthly / payFrequency.periodsPerMonth)
    }

    /// Mode B: months needed at fixed monthly contribution
    var monthsNeeded: Int? {
        guard mode == .monthlyAmount,
              let monthly = monthlyContribution,
              monthly > 0
        else { return nil }
        let months = Int(ceil(remainingAmount / monthly))
        return max(months, 0)
    }

    var estimatedCompletionDate: Date? {
        guard mode == .monthlyAmount,
              let months = monthsNeeded
        else { return nil }
        return Calendar.current.date(byAdding: .month, value: months, to: createdAt)
    }

    func addingContribution(_ amount: Double, on date: Date = .now) -> MoneyGoal {
        var copy = self
        copy.currentAmount += amount
        copy.contributions.append(MoneyGoalContribution(amount: amount, date: date))
        return copy
    }

    static let sampleGoals: [MoneyGoal] = [
        MoneyGoal(
            title: "Family Vacation",
            targetAmount: 3500,
            currentAmount: 900,
            mode: .targetDate,
            targetDate: Calendar.current.date(byAdding: .month, value: 8, to: .now),
            payFrequency: .biweekly
        ),
        MoneyGoal(
            title: "Pay Off Card",
            targetAmount: 1800,
            currentAmount: 300,
            mode: .monthlyAmount,
            monthlyContribution: 250,
            payFrequency: .monthly
        )
    ]
}

struct MoneyGoalEditorSuggestion {
    let planningMode: MoneyGoalPlanningMode
    let monthlyContribution: Double?
    let payFrequency: MoneyGoalPayFrequency
}

final class BudgetingCalculatorStore: ObservableObject {
    @Published var baseMonthlyIncome: Double {
        didSet { persist(baseMonthlyIncome, key: Keys.baseMonthlyIncome) }
    }
    @Published var essentialExpenses: Double {
        didSet { persist(essentialExpenses, key: Keys.essentialExpenses) }
    }
    @Published var lifestyleExpenses: Double {
        didSet { persist(lifestyleExpenses, key: Keys.lifestyleExpenses) }
    }
    @Published var offDutyHours: Double {
        didSet { persist(offDutyHours, key: Keys.offDutyHours) }
    }
    @Published var offDutyRate: Double {
        didSet { persist(offDutyRate, key: Keys.offDutyRate) }
    }
    @Published var overtimeHours: Double {
        didSet { persist(overtimeHours, key: Keys.overtimeHours) }
    }
    @Published var overtimeRate: Double {
        didSet { persist(overtimeRate, key: Keys.overtimeRate) }
    }
    @Published var payFrequency: MoneyGoalPayFrequency {
        didSet { defaults.set(payFrequency.rawValue, forKey: Keys.payFrequency) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        baseMonthlyIncome = defaults.loadDouble(forKey: Keys.baseMonthlyIncome, defaultValue: 5200)
        essentialExpenses = defaults.loadDouble(forKey: Keys.essentialExpenses, defaultValue: 3200)
        lifestyleExpenses = defaults.loadDouble(forKey: Keys.lifestyleExpenses, defaultValue: 800)
        offDutyHours = defaults.loadDouble(forKey: Keys.offDutyHours, defaultValue: 10)
        offDutyRate = defaults.loadDouble(forKey: Keys.offDutyRate, defaultValue: 55)
        overtimeHours = defaults.loadDouble(forKey: Keys.overtimeHours, defaultValue: 8)
        overtimeRate = defaults.loadDouble(forKey: Keys.overtimeRate, defaultValue: 75)
        if let storedFrequency = defaults.string(forKey: Keys.payFrequency),
           let frequency = MoneyGoalPayFrequency(rawValue: storedFrequency) {
            payFrequency = frequency
        } else {
            payFrequency = .biweekly
        }
    }

    var offDutyIncome: Double { offDutyHours * offDutyRate }
    var overtimeIncome: Double { overtimeHours * overtimeRate }
    var totalMonthlyIncome: Double { baseMonthlyIncome + offDutyIncome + overtimeIncome }
    var totalMonthlyExpenses: Double { essentialExpenses + lifestyleExpenses }
    var availableForGoals: Double { max(totalMonthlyIncome - totalMonthlyExpenses, 0) }
    var perPaycheckAvailable: Double {
        availableForGoals / max(payFrequency.periodsPerMonth, 1)
    }
    var surplusPercentage: Double {
        guard totalMonthlyIncome > 0 else { return 0 }
        return min(max(availableForGoals / totalMonthlyIncome, 0), 1)
    }

    var goalSuggestion: MoneyGoalEditorSuggestion? {
        guard availableForGoals > 0 else { return nil }
        return MoneyGoalEditorSuggestion(
            planningMode: .monthlyAmount,
            monthlyContribution: ceilCurrency(availableForGoals),
            payFrequency: payFrequency
        )
    }

    private func persist(_ value: Double, key: String) {
        defaults.set(value, forKey: key)
    }

    private enum Keys {
        static let baseMonthlyIncome = "moneyGoals.baseMonthlyIncome"
        static let essentialExpenses = "moneyGoals.essentialExpenses"
        static let lifestyleExpenses = "moneyGoals.lifestyleExpenses"
        static let offDutyHours = "moneyGoals.offDutyHours"
        static let offDutyRate = "moneyGoals.offDutyRate"
        static let overtimeHours = "moneyGoals.overtimeHours"
        static let overtimeRate = "moneyGoals.overtimeRate"
        static let payFrequency = "moneyGoals.payFrequency"
    }
}

private func ceilCurrency(_ value: Double) -> Double {
    (value * 100).rounded(.up) / 100
}

private extension Date {
    func monthsUntil(_ other: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: self)
        let end = calendar.startOfDay(for: other)
        let components = calendar.dateComponents([.month], from: start, to: end)
        return components.month ?? 0
    }
}

private extension UserDefaults {
    func loadDouble(forKey key: String, defaultValue: Double) -> Double {
        if object(forKey: key) != nil {
            return double(forKey: key)
        }
        return defaultValue
    }
}

// MARK: - Locker Notes Models

enum LockerNoteType: String, CaseIterable, Identifiable {
    case quick
    case casework
    case training
    case wellness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .casework: return "Casework"
        case .training: return "Training"
        case .wellness: return "Wellness"
        }
    }

    var suggestedTags: [LockerNoteTag] {
        switch self {
        case .quick:
            return [.action, .followUp]
        case .casework:
            return [.casework, .followUp]
        case .training:
            return [.training]
        case .wellness:
            return [.wellness]
        }
    }
}

enum LockerNoteTag: String, CaseIterable, Identifiable {
    case casework
    case followUp
    case training
    case wellness
    case reminder
    case personal
    case action

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casework: return "Casework"
        case .followUp: return "Follow Up"
        case .training: return "Training"
        case .wellness: return "Wellness"
        case .reminder: return "Reminder"
        case .personal: return "Personal"
        case .action: return "Action Items"
        }
    }

    var tint: Color {
        switch self {
        case .casework: return .blue
        case .followUp: return .orange
        case .training: return .purple
        case .wellness: return .green
        case .reminder: return .pink
        case .personal: return .teal
        case .action: return .red
        }
    }

    static let selectableCases: [LockerNoteTag] = [.casework, .followUp, .training, .wellness, .reminder, .personal, .action]
}

struct LockerNote: Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var tags: [LockerNoteTag]
    var noteType: LockerNoteType
    var caseReference: String?
    var reminderDate: Date?
    var isPinned: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var trimmedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Note" : trimmed
    }

    var previewText: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "No details added yet."
        }
        return trimmed
    }
}

enum LockerNotesFilter: String, CaseIterable, Identifiable {
    case all
    case pinned
    case reminders
    case casework
    case wellness
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .pinned: return "Pinned"
        case .reminders: return "Reminders"
        case .casework: return "Casework"
        case .wellness: return "Wellness"
        case .archived: return "Archived"
        }
    }

    func matches(_ note: LockerNote) -> Bool {
        switch self {
        case .all:
            return !note.isArchived
        case .pinned:
            return note.isPinned && !note.isArchived
        case .reminders:
            return note.reminderDate != nil && !note.isArchived
        case .casework:
            return note.noteType == .casework && !note.isArchived
        case .wellness:
            return note.noteType == .wellness && !note.isArchived
        case .archived:
            return note.isArchived
        }
    }
}

@MainActor
final class LockerNotesViewModel: ObservableObject {
    @Published private(set) var notes: [LockerNote]

    init() {
        self.notes = LockerNotesViewModel.makeSamples()
    }

    func note(with id: LockerNote.ID) -> LockerNote? {
        notes.first { $0.id == id }
    }

    func create(note: LockerNote) {
        notes.insert(note, at: 0)
    }

    func update(_ note: LockerNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
    }

    func delete(ids: Set<LockerNote.ID>) {
        notes.removeAll { ids.contains($0.id) }
    }

    func archive(ids: Set<LockerNote.ID>) {
        archive(ids: ids, archived: true)
    }

    func archive(ids: Set<LockerNote.ID>, archived: Bool) {
        mutate(ids: ids) { note in
            note.isArchived = archived
            if archived {
                note.isPinned = false
            }
        }
    }

    func togglePin(ids: Set<LockerNote.ID>) {
        mutate(ids: ids) { note in
            note.isPinned.toggle()
            if note.isPinned {
                note.isArchived = false
            }
        }
    }

    func add(tags: [LockerNoteTag], to ids: Set<LockerNote.ID>) {
        mutate(ids: ids) { note in
            var set = Set(note.tags)
            tags.forEach { set.insert($0) }
            note.tags = Array(set)
        }
    }

    func duplicate(note: LockerNote) {
        let duplicate = LockerNote(
            id: UUID(),
            title: note.title + " Copy",
            body: note.body,
            tags: note.tags,
            noteType: note.noteType,
            caseReference: note.caseReference,
            reminderDate: note.reminderDate,
            isPinned: false,
            isArchived: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        notes.insert(duplicate, at: 0)
    }

    private func mutate(ids: Set<LockerNote.ID>, transform: (inout LockerNote) -> Void) {
        notes = notes.map { note in
            guard ids.contains(note.id) else { return note }
            var updated = note
            transform(&updated)
            updated.updatedAt = Date()
            return updated
        }
    }

    private static func makeSamples() -> [LockerNote] {
        [
            LockerNote(
                id: UUID(),
                title: "Overtime case follow-up",
                body: "Remember to call Sgt. Miller about the supplemental report and include CAD notes.",
                tags: [.casework, .followUp],
                noteType: .casework,
                caseReference: "23-10498",
                reminderDate: Calendar.current.date(byAdding: .day, value: 2, to: .now),
                isPinned: true,
                isArchived: false,
                createdAt: Date().addingTimeInterval(-86400 * 2),
                updatedAt: Date().addingTimeInterval(-3600 * 6)
            ),
            LockerNote(
                id: UUID(),
                title: "Wellness ideas",
                body: "Schedule a massage after this rotation. Look into the peer support workshop on Thursday.",
                tags: [.wellness, .personal],
                noteType: .wellness,
                caseReference: nil,
                reminderDate: nil,
                isPinned: false,
                isArchived: false,
                createdAt: Date().addingTimeInterval(-86400 * 5),
                updatedAt: Date().addingTimeInterval(-86400)
            ),
            LockerNote(
                id: UUID(),
                title: "Training takeaways",
                body: "Vehicle interdiction refresher: emphasize passenger-side approaches, keep the flashlight low.",
                tags: [.training],
                noteType: .training,
                caseReference: nil,
                reminderDate: nil,
                isPinned: false,
                isArchived: false,
                createdAt: Date().addingTimeInterval(-86400 * 10),
                updatedAt: Date().addingTimeInterval(-86400 * 3)
            )
        ]
    }
}

// MARK: - Locker Certifications

struct LockerCertificationAttachment: Identifiable, Hashable {
    let id: UUID
    var fileName: String
    var fileURL: URL?
    var addedAt: Date
}

struct LockerCertificationReminder: Hashable {
    var leadTime: LockerCertificationReminderLeadTime
    var customDate: Date?

    var displayText: String {
        switch leadTime {
        case .custom:
            if let date = customDate {
                return "Custom – \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Custom"
        default:
            return leadTime.description
        }
    }
}

enum LockerCertificationReminderLeadTime: String, CaseIterable, Identifiable {
    case days30
    case days60
    case days90
    case custom

    var id: String { rawValue }

    var description: String {
        switch self {
        case .days30: return "30 days before"
        case .days60: return "60 days before"
        case .days90: return "90 days before"
        case .custom: return "Custom"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .days30: return 86400 * 30
        case .days60: return 86400 * 60
        case .days90: return 86400 * 90
        case .custom: return 0
        }
    }
}

struct LockerCertification: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String?
    var issuer: String?
    var licenseNumber: String?
    var issueDate: Date
    var expirationDate: Date?
    var attachments: [LockerCertificationAttachment]
    var reminder: LockerCertificationReminder?
    var notes: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String?,
        issuer: String?,
        licenseNumber: String?,
        issueDate: Date,
        expirationDate: Date?,
        attachments: [LockerCertificationAttachment],
        reminder: LockerCertificationReminder?,
        notes: String,
        isArchived: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.issuer = issuer
        self.licenseNumber = licenseNumber
        self.issueDate = issueDate
        self.expirationDate = expirationDate
        self.attachments = attachments
        self.reminder = reminder
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var hasAttachments: Bool { !attachments.isEmpty }

    var hasReminder: Bool { reminder != nil }

    var statusDescription: String {
        switch statusCategory {
        case .archived: return "Archived"
        case .expired: return "Expired"
        case .expiringSoon: return "Expiring Soon"
        case .active: return "Active"
        }
    }

    var statusColor: Color {
        switch statusCategory {
        case .archived: return .gray
        case .expired: return .red
        case .expiringSoon: return .orange
        case .active: return .green
        }
    }

    var exportSummary: String {
        var lines: [String] = [
            "Certification: \(name)",
            "Issued: \(issueDate.formatted(date: .abbreviated, time: .omitted))"
        ]
        if let issuer {
            lines.append("Issuer: \(issuer)")
        }
        if let licenseNumber {
            lines.append("License #: \(licenseNumber)")
        }
        if let expirationDate {
            lines.append("Expires: \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
        }
        if !notes.isEmpty {
            lines.append("")
            lines.append(notes)
        }
        return lines.joined(separator: "\n")
    }

    fileprivate var statusCategory: CertificationStatusCategory {
        if isArchived { return .archived }
        guard let expirationDate else { return .active }
        if expirationDate < Date() {
            return .expired
        }
        if expirationDate < Date().addingTimeInterval(86400 * 60) {
            return .expiringSoon
        }
        return .active
    }

    fileprivate enum CertificationStatusCategory {
        case archived
        case expired
        case expiringSoon
        case active
    }
}

enum LockerCertificationStatusFilter: CaseIterable, Identifiable {
    case all
    case active
    case expiringSoon
    case expired
    case archived

    var id: String {
        switch self {
        case .all: return "all"
        case .active: return "active"
        case .expiringSoon: return "soon"
        case .expired: return "expired"
        case .archived: return "archived"
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .expiringSoon: return "Expiring Soon"
        case .expired: return "Expired"
        case .archived: return "Archived"
        }
    }

    func matches(_ certification: LockerCertification) -> Bool {
        switch self {
        case .all:
            return true
        case .active:
            return certification.statusCategory == .active
        case .expiringSoon:
            return certification.statusCategory == .expiringSoon
        case .expired:
            return certification.statusCategory == .expired
        case .archived:
            return certification.statusCategory == .archived
        }
    }
}

enum LockerCertificationSort: CaseIterable, Identifiable {
    case expiration
    case name
    case issuer

    var id: String {
        switch self {
        case .expiration: return "expiration"
        case .name: return "name"
        case .issuer: return "issuer"
        }
    }

    var title: String {
        switch self {
        case .expiration: return "Expiration"
        case .name: return "Name"
        case .issuer: return "Issuer"
        }
    }
}

@MainActor
final class LockerCertificationsViewModel: ObservableObject {
    @Published private(set) var certifications: [LockerCertification]

    init() {
        self.certifications = LockerCertificationsViewModel.makeSamples()
    }

    func certification(id: LockerCertification.ID) -> LockerCertification? {
        certifications.first { $0.id == id }
    }

    func create(_ certification: LockerCertification) {
        certifications.insert(certification, at: 0)
    }

    func update(_ certification: LockerCertification) {
        guard let index = certifications.firstIndex(where: { $0.id == certification.id }) else { return }
        certifications[index] = certification
    }

    func delete(id: LockerCertification.ID) {
        certifications.removeAll { $0.id == id }
    }

    func toggleArchive(id: LockerCertification.ID) {
        guard let index = certifications.firstIndex(where: { $0.id == id }) else { return }
        certifications[index].isArchived.toggle()
        certifications[index].updatedAt = Date()
    }

    private static func makeSamples() -> [LockerCertification] {
        [
            LockerCertification(
                name: "First Aid / CPR",
                category: "Medical",
                issuer: "DutyWire Academy",
                licenseNumber: "FA-2025-17",
                issueDate: Date().addingTimeInterval(-86400 * 150),
                expirationDate: Date().addingTimeInterval(86400 * 200),
                attachments: [],
                reminder: LockerCertificationReminder(leadTime: .days60, customDate: nil),
                notes: "Renew every 2 years. Evidence of training stored in Locker.",
                isArchived: false,
                createdAt: Date().addingTimeInterval(-86400 * 150),
                updatedAt: Date().addingTimeInterval(-86400 * 4)
            ),
            LockerCertification(
                name: "Crisis Intervention",
                category: "Training",
                issuer: "County Training Unit",
                licenseNumber: "CIT-8832",
                issueDate: Date().addingTimeInterval(-86400 * 400),
                expirationDate: Date().addingTimeInterval(-86400 * 20),
                attachments: [
                    LockerCertificationAttachment(id: UUID(), fileName: "CIT-Certificate.pdf", fileURL: nil, addedAt: Date().addingTimeInterval(-86400 * 30))
                ],
                reminder: LockerCertificationReminder(leadTime: .days30, customDate: nil),
                notes: "Schedule refresher next quarter.",
                isArchived: false,
                createdAt: Date().addingTimeInterval(-86400 * 400),
                updatedAt: Date().addingTimeInterval(-86400 * 2)
            ),
            LockerCertification(
                name: "Advanced Driving Instructor",
                category: "Instruction",
                issuer: "State Academy",
                licenseNumber: "ADI-2041",
                issueDate: Date().addingTimeInterval(-86400 * 800),
                expirationDate: nil,
                attachments: [],
                reminder: nil,
                notes: "Grandfathered credential, no expiration.",
                isArchived: false,
                createdAt: Date().addingTimeInterval(-86400 * 800),
                updatedAt: Date().addingTimeInterval(-86400 * 100)
            )
        ]
    }
}

// MARK: - Locker Career Records

struct LockerCareerAttachment: Identifiable, Hashable {
    let id: UUID
    var fileName: String
    var fileURL: URL?
    var addedAt: Date
}

enum LockerCareerRecordType: String, CaseIterable, Identifiable {
    case evaluation
    case commendation
    case counseling
    case goal
    case promotion
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .evaluation: return "Evaluation"
        case .commendation: return "Commendation"
        case .counseling: return "Counseling"
        case .goal: return "Goal"
        case .promotion: return "Promotion"
        case .other: return "Other"
        }
    }

    var tint: Color {
        switch self {
        case .evaluation: return .blue
        case .commendation: return .green
        case .counseling: return .orange
        case .goal: return .purple
        case .promotion: return .pink
        case .other: return .gray
        }
    }

    var primaryDateLabel: String {
        switch self {
        case .evaluation: return "Evaluation Date"
        case .commendation: return "Event Date"
        case .counseling: return "Session Date"
        case .goal: return "Recorded Date"
        case .promotion: return "Effective Date"
        case .other: return "Date"
        }
    }
}

enum LockerCareerRecordFilter: CaseIterable, Identifiable {
    case all
    case highlights
    case archived
    case evaluations
    case commendations

    var id: String {
        switch self {
        case .all: return "all"
        case .highlights: return "highlights"
        case .archived: return "archived"
        case .evaluations: return "evaluations"
        case .commendations: return "commendations"
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .highlights: return "Highlights"
        case .archived: return "Archived"
        case .evaluations: return "Evaluations"
        case .commendations: return "Commendations"
        }
    }

    func matches(_ record: LockerCareerRecord) -> Bool {
        switch self {
        case .all:
            return !record.isArchived
        case .highlights:
            return record.highlight && !record.isArchived
        case .archived:
            return record.isArchived
        case .evaluations:
            return record.type == .evaluation && !record.isArchived
        case .commendations:
            return record.type == .commendation && !record.isArchived
        }
    }
}

enum LockerCareerSortOption: CaseIterable, Identifiable {
    case newest
    case oldest
    case title
    case type

    var id: String {
        switch self {
        case .newest: return "newest"
        case .oldest: return "oldest"
        case .title: return "title"
        case .type: return "type"
        }
    }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .title: return "Title"
        case .type: return "Type"
        }
    }
}

struct LockerCareerRecord: Identifiable, Hashable {
    let id: UUID
    var title: String
    var type: LockerCareerRecordType
    var primaryDate: Date
    var highlight: Bool
    var attachments: [LockerCareerAttachment]
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var performancePeriod: String?
    var rater: String?
    var rating: String?
    var assignmentAtTime: String?
    var issuingAuthority: String?
    var awardType: String?
    var counselingType: String?
    var followUpDate: Date?
    var goalTargetDate: Date?
    var goalCategory: String?
    var goalStatus: String?
    var newAssignment: String?
    var previousAssignment: String?

    var exportSummary: String {
        var components: [String] = [
            "Record: \(title)",
            "Type: \(type.title)",
            "Primary Date: \(primaryDate.formatted(date: .abbreviated, time: .omitted))"
        ]
        if let rater {
            components.append("Rater: \(rater)")
        }
        if let issuingAuthority {
            components.append("Issuer: \(issuingAuthority)")
        }
        if !notes.isEmpty {
            components.append("")
            components.append(notes)
        }
        return components.joined(separator: "\n")
    }
}

@MainActor
final class LockerCareerRecordsViewModel: ObservableObject {
    @Published private(set) var records: [LockerCareerRecord]

    init() {
        self.records = LockerCareerRecordsViewModel.makeSamples()
    }

    func record(id: LockerCareerRecord.ID) -> LockerCareerRecord? {
        records.first { $0.id == id }
    }

    func create(_ record: LockerCareerRecord) {
        records.insert(record, at: 0)
    }

    func update(_ record: LockerCareerRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
    }

    func delete(id: LockerCareerRecord.ID) {
        records.removeAll { $0.id == id }
    }

    func toggleArchive(id: LockerCareerRecord.ID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].isArchived.toggle()
        records[index].updatedAt = Date()
    }

    func toggleHighlight(id: LockerCareerRecord.ID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].highlight.toggle()
        records[index].updatedAt = Date()
    }

    func duplicate(record: LockerCareerRecord) {
        var clone = record
        clone.updatedAt = Date()
        let newRecord = LockerCareerRecord(
            id: UUID(),
            title: "\(record.title) Copy",
            type: record.type,
            primaryDate: record.primaryDate,
            highlight: clone.highlight,
            attachments: record.attachments,
            notes: record.notes,
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false,
            performancePeriod: record.performancePeriod,
            rater: record.rater,
            rating: record.rating,
            assignmentAtTime: record.assignmentAtTime,
            issuingAuthority: record.issuingAuthority,
            awardType: record.awardType,
            counselingType: record.counselingType,
            followUpDate: record.followUpDate,
            goalTargetDate: record.goalTargetDate,
            goalCategory: record.goalCategory,
            goalStatus: record.goalStatus,
            newAssignment: record.newAssignment,
            previousAssignment: record.previousAssignment
        )
        records.insert(newRecord, at: 0)
    }

    private static func makeSamples() -> [LockerCareerRecord] {
        [
            LockerCareerRecord(
                id: UUID(),
                title: "Annual Evaluation – 2024",
                type: .evaluation,
                primaryDate: Date().addingTimeInterval(-86400 * 30),
                highlight: true,
                attachments: [],
                notes: "Exceeded expectations for leadership and mentoring.",
                createdAt: Date().addingTimeInterval(-86400 * 40),
                updatedAt: Date().addingTimeInterval(-86400 * 20),
                isArchived: false,
                performancePeriod: "Jan – Dec 2024",
                rater: "Lt. Alvarez",
                rating: "Exceeds",
                assignmentAtTime: "Metro Patrol",
                issuingAuthority: nil,
                awardType: nil,
                counselingType: nil,
                followUpDate: nil,
                goalTargetDate: nil,
                goalCategory: nil,
                goalStatus: nil,
                newAssignment: nil,
                previousAssignment: nil
            ),
            LockerCareerRecord(
                id: UUID(),
                title: "Letter of Commendation – Downtown Parade",
                type: .commendation,
                primaryDate: Date().addingTimeInterval(-86400 * 120),
                highlight: false,
                attachments: [
                    LockerCareerAttachment(id: UUID(), fileName: "Commendation.pdf", fileURL: nil, addedAt: Date().addingTimeInterval(-86400 * 90))
                ],
                notes: "Coordinated with Transit Division for joint response.",
                createdAt: Date().addingTimeInterval(-86400 * 130),
                updatedAt: Date().addingTimeInterval(-86400 * 100),
                isArchived: false,
                performancePeriod: nil,
                rater: nil,
                rating: nil,
                assignmentAtTime: "Special Events",
                issuingAuthority: "Chief Daniels",
                awardType: "Unit Citation",
                counselingType: nil,
                followUpDate: nil,
                goalTargetDate: nil,
                goalCategory: nil,
                goalStatus: nil,
                newAssignment: nil,
                previousAssignment: nil
            ),
            LockerCareerRecord(
                id: UUID(),
                title: "Career Goal – Sergeants Process",
                type: .goal,
                primaryDate: Date().addingTimeInterval(-86400 * 200),
                highlight: false,
                attachments: [],
                notes: "Prep timeline for supervisor promotional exam.",
                createdAt: Date().addingTimeInterval(-86400 * 200),
                updatedAt: Date().addingTimeInterval(-86400 * 60),
                isArchived: false,
                performancePeriod: nil,
                rater: nil,
                rating: nil,
                assignmentAtTime: nil,
                issuingAuthority: nil,
                awardType: nil,
                counselingType: nil,
                followUpDate: nil,
                goalTargetDate: Date().addingTimeInterval(86400 * 120),
                goalCategory: "Promotion",
                goalStatus: "In Progress",
                newAssignment: nil,
                previousAssignment: nil
            )
        ]
    }
}
