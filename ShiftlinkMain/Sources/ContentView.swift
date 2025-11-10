//
//  ContentView.swift
//  ShiftlinkMain
//
//  Created by Jerry Sarno on 11/2/25.
//

import SwiftUI
import Foundation
import UIKit
import UserNotifications
import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore

private struct AppTintKey: EnvironmentKey {
    static let defaultValue: Color = Color(.systemBlue)
}

extension EnvironmentValues {
    var appTint: Color {
        get { self[AppTintKey.self] }
        set { self[AppTintKey.self] = newValue }
    }
}

private extension View {
    @ViewBuilder
    func actionButtonStyle(for role: ButtonRole?) -> some View {
        if role == .destructive {
            self.buttonStyle(.bordered)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Root Shell

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel
    private let appTint = Color(.systemBlue)

    var body: some View {
        Group {
            if auth.isLoading {
                OrgLoadingView(message: auth.statusMessage)
            } else if let flow = auth.authFlow {
                switch flow {
                case .signedIn:
                    RootTabsView()
                case .needsConfirmation(let username):
                    ConfirmationView(username: username)
                case .signedOut:
                    LoginView()
                }
            } else {
                LoginView()
            }; footer: do {
                Text("Stay on top of your tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(appTint)
        .environment(\.appTint, appTint)
        .task {
            await auth.refreshAuthState()
        }
        .alert(isPresented: Binding<Bool>(
            get: { auth.alertMessage != nil },
            set: { if !$0 { auth.alertMessage = nil } }
        ), content: {
            Alert(
                title: Text("Authentication"),
                message: Text(auth.alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        })
    }
}

private struct OrgLoadingView: View {
    var message: String?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(message ?? "Loading your ShiftLink workspace…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Tabs

enum AppTab: Hashable { case dashboard, supervisor, admin, inbox, profile }
enum QuickActionDestination: Hashable {
    case myLog
    case squad
    case overtime
    case patrols
    case vehicles
    case calendar
}

enum DepartmentAlertPriority: String, CaseIterable, Identifiable {
    case info
    case warning
    case critical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .info: return "Information"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    var systemImage: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "bolt.trianglebadge.exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

private enum RoleLabels {
    static let defaultRole = "Non-Supervisor"

    static func displayName(for rawRole: String) -> String {
        let normalized = rawRole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return defaultRole }

        switch normalized.lowercased() {
        case "admin", "administrator":
            return "Administrator"
        case "supervisor":
            return "Supervisor"
        case "officer", "non-supervisor", "nonsupervisor":
            return defaultRole
        default:
            return normalized.capitalized
        }
    }
}

private enum AdminPortalDestination: Hashable {
    case sendAlert
    case managePatrols
    case vehicleRoster
    case shiftTemplates
    case overtimeAudit
    case departmentRoster
}

struct RootTabsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selection: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { tabItemLabel(title: "Dashboard", systemImage: "house.fill") }
                .tag(AppTab.dashboard)

            if auth.isAdmin {
                AdministratorPortalView()
                    .tabItem { tabItemLabel(title: "Admin", systemImage: "gearshape.2.fill") }
                    .tag(AppTab.admin)
            } else if auth.isSupervisor {
                SupervisorPortalView()
                    .tabItem { tabItemLabel(title: "Supervisor", systemImage: "person.2.fill") }
                    .tag(AppTab.supervisor)
            }

            InboxView()
                .tabItem { tabItemLabel(title: "Inbox", systemImage: "tray.full.fill") }
                .badge(auth.notifications.filter { !$0.isRead }.count)
                .tag(AppTab.inbox)

            ProfileView()
                .tabItem { tabItemLabel(title: "Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: auth.isAdmin) { _, _ in
            ensureValidSelection()
        }
        .onChange(of: auth.isSupervisor) { _, _ in
            ensureValidSelection()
        }
    }

    private func ensureValidSelection() {
        let allowedTabs: Set<AppTab> = {
            var tabs: [AppTab] = [.dashboard]
            if auth.isAdmin {
                tabs.append(.admin)
            } else if auth.isSupervisor {
                tabs.append(.supervisor)
            }
            tabs.append(contentsOf: [.inbox, .profile])
            return Set(tabs)
        }()

        if !allowedTabs.contains(selection) {
            selection = .dashboard
        }
    }

    @ViewBuilder
    private func tabItemLabel(title: String, systemImage: String) -> some View {
        VStack {
            Image(systemName: systemImage)
                .imageScale(.medium)
            Text(title)
        }
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint

    private let quickActions: [QuickAction] = [
        QuickAction(title: "My Calendar", systemImage: "calendar", destination: .calendar),
        QuickAction(title: "My Log", systemImage: "note.text", destination: .myLog),
        QuickAction(title: "My Squad", systemImage: "person.3.fill", destination: .squad),
        QuickAction(title: "Overtime", systemImage: "clock.fill", destination: .overtime),
        QuickAction(title: "Directed Patrols", systemImage: "scope", destination: .patrols),
        QuickAction(title: "Vehicle Roster", systemImage: "car.fill", destination: .vehicles)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    logoHeader
                    welcomeCard
                    quickActionsGrid
                    actionItemsCard
                    sendNotificationCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { Task { await auth.signOut() } }
                }
            }
            .navigationDestination(for: QuickActionDestination.self) { destination in
                switch destination {
                case .myLog:
                    MyLogView()
                case .squad:
                    SquadRosterView()
                case .overtime:
                    OvertimeBoardView()
                case .patrols:
                    PatrolAssignmentsView()
                case .vehicles:
                    VehicleRosterView()
                case .calendar:
                    MyCalendarView()
                }
            }
        }
    }

    private var logoHeader: some View {
        VStack(spacing: 8) {
            if UIImage(named: "DUTYWIRE") != nil {
                Image("DUTYWIRE")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .accessibilityLabel("DutyWire")
            } else {
                Image("DWLOGO")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .accessibilityLabel("DutyWire")
            }
            Text("Built for Departments. Designed by You.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentAssignmentTitle: String {
        auth.currentAssignment?.title ?? "Assignment Pending"
    }

    private var currentAssignmentDetail: String? {
        auth.currentAssignment?.detail ?? auth.currentAssignment?.location
    }

    private var welcomeCard: some View {
        let displayName = auth.userProfile.displayName
            ?? auth.currentUser?.username
            ?? auth.userProfile.email
            ?? "Officer"
        let roleLabel = auth.userProfile.rank
            ?? auth.primaryRoleDisplayName
            ?? (auth.isAdmin ? "Administrator" : RoleLabels.defaultRole)

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.21, blue: 0.37),
                            Color(red: 0.14, green: 0.31, blue: 0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back,")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))

                        Text(roleLabel)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text(displayName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Assignment")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(currentAssignmentTitle)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white)
                            if let detail = currentAssignmentDetail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "bell.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Notifications")
                }

            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(quickActions) { action in
                    NavigationLink(value: action.destination) {
                        QuickActionTile(action: action)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.7)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action Items")
                .font(.headline)
            Text("You're all caught up.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("New action items will appear here as supervisors assign them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
    }

    private var sendNotificationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Send Notification/Alert")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(appTint))
                }
                .accessibilityLabel("Compose Notification")
                .disabled(!auth.isAdmin)
                .opacity(auth.isAdmin ? 1 : 0.4)
            }

            Text(auth.notifications.isEmpty ? "No alerts at the moment." : "You have \(auth.notifications.count) alerts ready to send.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !auth.isAdmin {
                Text("Administrator access required to send alerts.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
    }
}

private struct QuickAction: Identifiable {
    let title: String
    let systemImage: String
    let destination: QuickActionDestination

    var id: String { title }
}

private struct QuickActionTile: View {
    let action: QuickAction

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                    .frame(width: 38, height: 38)
                Image(systemName: action.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(.label))
            }

            Text(action.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

private struct AdministratorPortalView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var destination: AdminPortalDestination?

    var body: some View {
        NavigationStack {
            List {
                Section("Operations") {
                    NavigationLink(value: AdminPortalDestination.sendAlert) {
                        ManagementActionRow(
                            title: "Send Department Alert",
                            detail: "Notify teams about schedule changes.",
                            systemImage: "megaphone.fill"
                        )
                    }

                    NavigationLink(value: AdminPortalDestination.managePatrols) {
                        ManagementActionRow(
                            title: "Manage Patrols",
                            detail: "Assign coverage and review availability.",
                            systemImage: "target"
                        )
                    }

                    NavigationLink(value: AdminPortalDestination.vehicleRoster) {
                        ManagementActionRow(
                            title: "Vehicle Roster",
                            detail: "Track assignments and maintenance.",
                            systemImage: "car.fill"
                        )
                    }

                    NavigationLink(value: AdminPortalDestination.departmentRoster) {
                        ManagementActionRow(
                            title: "Dept Roster & Assignments",
                            detail: "Review officers and update posts.",
                            systemImage: "person.crop.rectangle.stack.fill"
                        )
                    }
                }

                Section("Tools") {
                    NavigationLink(value: AdminPortalDestination.shiftTemplates) {
                        ManagementActionRow(
                            title: "Shift Templates",
                            detail: "Create reusable scheduling presets.",
                            systemImage: "calendar.badge.clock"
                        )
                    }
                    NavigationLink(value: AdminPortalDestination.overtimeAudit) {
                        ManagementActionRow(
                            title: "Overtime Audit",
                            detail: "Search overtime by date, shift, or officer.",
                            systemImage: "chart.bar.doc.horizontal"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Admin Portal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { Task { await auth.signOut() } }
                }
            }
            .navigationDestination(for: AdminPortalDestination.self) { route in
                switch route {
                case .sendAlert:
                    SendDepartmentAlertView()
                case .managePatrols:
                    PatrolAssignmentsView()
                case .vehicleRoster:
                    VehicleRosterView()
                case .shiftTemplates:
                    ShiftTemplateLibraryView()
                case .overtimeAudit:
                    OvertimeAuditView()
                case .departmentRoster:
                    DepartmentRosterAssignmentsView()
                }
            }
        }
    }
}

private enum SupervisorDestination: Hashable {
    case squad
    case overtime
    case vehicles
}

private struct SupervisorPortalView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Team Ops") {
                    NavigationLink(value: SupervisorDestination.squad) {
                        ManagementActionRow(
                            title: "My Squad",
                            detail: "Send updates and manage assignments.",
                            systemImage: "person.3.fill"
                        )
                    }
                    NavigationLink(value: SupervisorDestination.overtime) {
                        ManagementActionRow(
                            title: "Overtime Board",
                            detail: "Review and post overtime needs.",
                            systemImage: "clock.badge.plus"
                        )
                    }
                }

                Section("Resources") {
                    NavigationLink(value: SupervisorDestination.vehicles) {
                        ManagementActionRow(
                            title: "Vehicle Roster",
                            detail: "Check availability and status.",
                            systemImage: "car.2.fill"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Supervisor")
            .navigationDestination(for: SupervisorDestination.self) { destination in
                switch destination {
                case .squad:
                    SquadRosterView()
                case .overtime:
                    OvertimeBoardView()
                case .vehicles:
                    VehicleRosterView()
                }
            }
        }
    }
}

private struct ManagementActionRow: View {
    var title: String
    var detail: String
    var systemImage: String
    @Environment(\.appTint) private var appTint

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(appTint)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(appTint.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Dept Roster & Assignments

private struct DepartmentRosterAssignmentsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = DepartmentRosterAssignmentsViewModel()
    @State private var editingDraft: OfficerAssignmentDraft?
    @State private var alertMessage: String?
    @State private var searchText = ""
    @State private var sortOrder: AssignmentSortOrder = .nameAscending

    private var orgId: String? { auth.userProfile.orgID }

    private var filteredAssignments: [OfficerAssignmentDTO] {
        var items = viewModel.assignments
        if !searchText.isEmpty {
            let term = searchText.lowercased()
            items = items.filter { assignment in
                assignment.displayName.lowercased().contains(term) ||
                assignment.badgeNumber.lowercased().contains(term) ||
                assignment.title.lowercased().contains(term)
            }
        }
        switch sortOrder {
        case .nameAscending:
            items.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .badgeAscending:
            items.sort { $0.badgeNumber.localizedStandardCompare($1.badgeNumber) == .orderedAscending }
        }
        return items
    }

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(filteredAssignments) { assignment in
                Button {
                    editingDraft = OfficerAssignmentDraft(from: assignment)
                } label: {
                    OfficerRosterCardView(assignment: assignment)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await deleteAssignment(id: assignment.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if filteredAssignments.isEmpty && viewModel.errorMessage == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No roster entries match your search.")
                        .font(.headline)
                    Text("Add an officer to capture where they are posted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Dept Roster & Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort Order", selection: $sortOrder) {
                        ForEach(AssignmentSortOrder.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let orgId else {
                        alertMessage = "Missing org ID on profile."
                        return
                    }
                    editingDraft = OfficerAssignmentDraft(
                        assignmentId: nil,
                        orgId: orgId,
                        badgeNumber: "",
                        fullName: "",
                        rank: "",
                        assignmentTitle: "",
                        vehicle: "",
                        specialAssignment: "",
                        departmentPhone: "",
                        departmentExtension: "",
                        departmentEmail: "",
                        squad: ""
                    )
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(orgId == nil)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .task {
            await viewModel.load(orgId: orgId)
        }
        .refreshable {
            await viewModel.load(orgId: orgId)
        }
        .sheet(item: $editingDraft, onDismiss: { editingDraft = nil }) { draft in
            OfficerAssignmentEditorView(
                draft: draft,
                onSave: { updated in
                    do {
                        try await viewModel.save(draft: updated)
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                },
                onDelete: draft.assignmentId != nil ? {
                    await deleteAssignment(id: draft.assignmentId!)
                } : nil
            )
        }
        .alert("Roster & Assignments", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func deleteAssignment(id: String) async {
        do {
            try await viewModel.delete(id: id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

// MARK: - Assignment Filters

private enum AssignmentSortOrder: String, CaseIterable, Identifiable {
    case nameAscending
    case badgeAscending

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .badgeAscending: return "Badge Number (A-Z)"
        }
    }
}

private struct OfficerRosterCardView: View {
    let assignment: OfficerAssignmentDTO

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                Text(assignment.initials)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.displayName)
                    .font(.headline)
                Text(assignment.assignmentDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let special = assignment.specialAssignment {
                    Text("Special: \(special)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let vehicle = assignment.vehicleDisplay {
                    Text("Vehicle: \(vehicle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let squad = assignment.squad {
                    Text("Squad: \(squad)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("#\(assignment.badgeNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .padding(.vertical, 2)
    }
}

@MainActor
private final class DepartmentRosterAssignmentsViewModel: ObservableObject {
    @Published var assignments: [OfficerAssignmentDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var currentOrgId: String?

    func load(orgId: String?) async {
        guard let orgId, !orgId.isEmpty else {
            assignments = []
            errorMessage = "Missing org ID. Update the user's profile with custom:orgID."
            return
        }

        currentOrgId = orgId
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            assignments = try await ShiftlinkAPI.listAssignments(orgId: orgId)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(draft: OfficerAssignmentDraft) async throws {
        guard let orgId = currentOrgId else { throw ShiftlinkAPIError.missingIdentifiers }
        let updated = try await ShiftlinkAPI.upsertAssignment(
            for: draft.badgeNumber,
            orgId: orgId,
            assignmentTitle: draft.assignmentTitle,
            rank: draft.rank,
            vehicle: draft.vehicle,
            profile: draft.assignmentProfile
        )
        assignments.removeAll { $0.id == updated.id }
        assignments.append(updated)
        assignments.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func delete(id: String) async throws {
        try await ShiftlinkAPI.deleteAssignment(id: id)
        assignments.removeAll { $0.id == id }
    }
}

private struct OfficerAssignmentDraft: Identifiable {
    var assignmentId: String?
    var orgId: String
    var badgeNumber: String
    var fullName: String
    var rank: String
    var assignmentTitle: String
    var vehicle: String
    var specialAssignment: String
    var departmentPhone: String
    var departmentExtension: String
    var departmentEmail: String
    var squad: String
    private let uuid = UUID()

    var id: UUID { uuid }

    init(assignmentId: String?, orgId: String, badgeNumber: String, fullName: String, rank: String, assignmentTitle: String, vehicle: String, specialAssignment: String, departmentPhone: String, departmentExtension: String, departmentEmail: String, squad: String) {
        self.assignmentId = assignmentId
        self.orgId = orgId
        self.badgeNumber = badgeNumber
        self.fullName = fullName
        self.rank = rank
        self.assignmentTitle = assignmentTitle
        self.vehicle = vehicle
        self.specialAssignment = specialAssignment
        self.departmentPhone = departmentPhone
        self.departmentExtension = departmentExtension
        self.departmentEmail = departmentEmail
        self.squad = squad
    }

    init(from dto: OfficerAssignmentDTO) {
        self.assignmentId = dto.id
        self.orgId = dto.orgId
        self.badgeNumber = dto.badgeNumber
        self.fullName = dto.profile.fullName ?? ""
        self.rank = dto.profile.rank ?? dto.detail ?? ""
        self.assignmentTitle = dto.title
        self.vehicle = dto.profile.vehicle ?? dto.location ?? ""
        self.specialAssignment = dto.profile.specialAssignment ?? ""
        self.departmentPhone = dto.profile.departmentPhone ?? ""
        self.departmentExtension = dto.profile.departmentExtension ?? ""
        self.departmentEmail = dto.profile.departmentEmail ?? ""
        self.squad = dto.profile.squad ?? ""
    }

    var assignmentProfile: OfficerAssignmentProfile {
        OfficerAssignmentProfile(
            fullName: sanitize(fullName),
            rank: sanitize(rank),
            vehicle: sanitize(vehicle),
            specialAssignment: sanitize(specialAssignment),
            departmentPhone: sanitize(departmentPhone),
            departmentExtension: sanitize(departmentExtension),
            departmentEmail: sanitize(departmentEmail),
            squad: sanitize(squad)
        )
    }

    private func sanitize(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct OfficerAssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OfficerAssignmentDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSave: (OfficerAssignmentDraft) async throws -> Void
    let onDelete: (() async -> Void)?

    init(draft: OfficerAssignmentDraft, onSave: @escaping (OfficerAssignmentDraft) async throws -> Void, onDelete: (() async -> Void)? = nil) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Officer") {
                    TextField("Full Name", text: $draft.fullName)
                    TextField("Badge / Computer #", text: $draft.badgeNumber)
                        .textInputAutocapitalization(.none)
                        .keyboardType(.asciiCapable)
                    TextField("Rank", text: $draft.rank)
                }
                Section("Assignment") {
                    TextField("Assignment Title", text: $draft.assignmentTitle)
                    TextField("Squad", text: $draft.squad)
                    TextField("Special Assignment", text: $draft.specialAssignment)
                    TextField("Vehicle / Callsign", text: $draft.vehicle)
                }
                Section("Department Contact") {
                    TextField("Department Email", text: $draft.departmentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Work Phone", text: $draft.departmentPhone)
                        .keyboardType(.phonePad)
                    TextField("Extension", text: $draft.departmentExtension)
                        .keyboardType(.numberPad)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(draft.assignmentId == nil ? "New Officer" : "Edit Officer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(!isValid)
                    }
                }
                if let onDelete {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete Officer", role: .destructive) {
                            Task {
                                await onDelete()
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !draft.badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        guard isValid else { return }
        isSaving = true
        do {
            try await onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Inbox

private struct InboxView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint

    var body: some View {
        NavigationStack {
            List {
                ForEach(auth.notifications) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title)
                                .font(.headline)
                            Spacer()
                            if !item.isRead {
                                Capsule()
                                    .fill(appTint.opacity(0.2))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        Text(item.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(item.sentAt.relativeTimeString())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .onTapGesture { auth.markNotificationRead(item) }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") { Task { await auth.loadSampleData() } }
                }
            }
        }
    }
}

// MARK: - Profile

private struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Username", value: auth.userProfile.preferredUsername ?? auth.currentUser?.username ?? "—")
                    LabeledContent("Name", value: auth.userProfile.fullName ?? auth.userProfile.displayName ?? "—")
                    LabeledContent("Email", value: auth.userProfile.email ?? "—")
                    LabeledContent("Rank", value: auth.userProfile.rank ?? auth.primaryRoleDisplayName ?? (auth.isAdmin ? "Administrator" : RoleLabels.defaultRole))
                    LabeledContent("Org ID", value: auth.userProfile.orgID ?? "—")
                    LabeledContent("Site Key", value: auth.userProfile.siteKey ?? "—")
                    LabeledContent("Status", value: auth.isAuthenticated ? "Signed In" : "Signed Out")
                    LabeledContent("Admin Access", value: auth.isAdmin ? "Enabled" : "Not enabled")
                }
                Section("Actions") {
                    Button("Sign Out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showingEditor = true }
                        .disabled(auth.isLoading)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ProfileEditView(
                initialName: auth.userProfile.fullName ?? "",
                initialUsername: auth.userProfile.preferredUsername ?? auth.currentUser?.username ?? ""
            )
            .environmentObject(auth)
        }
    }
}

private struct ProfileEditView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var username: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(initialName: String, initialUsername: String) {
        _name = State(initialValue: initialName)
        _username = State(initialValue: initialUsername)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(!isValidInput)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var isValidInput: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() async {
        guard isValidInput else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await auth.updateProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                         preferredUsername: username.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Login & Confirmation

private struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @AppStorage("shiftlink.siteKey") private var siteKey = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: LoginField?

    private enum LoginField: Hashable {
        case siteKey
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGray6),
                        Color(uiColor: .systemGray5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        credentialCard
                        createAccountButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 36)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .onSubmit(handleSubmit)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("DUTYWIRE")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(.bottom, 4)

            Text("Built for Departments. Designed by You.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var credentialCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("SIGN IN")
                .font(.footnote.weight(.semibold))
                .kerning(3)
                .foregroundStyle(appTint)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 18) {
                inputField(
                    label: "Site Key",
                    placeholder: "e.g. SBPDNJ-1234",
                    text: $siteKey,
                    focus: .siteKey,
                    keyboard: .asciiCapable,
                    textInputAutocapitalization: .characters,
                    submitLabel: .next
                )

                inputField(
                    label: "Email",
                    placeholder: "you@agency.gov",
                    text: $email,
                    focus: .email,
                    keyboard: .emailAddress,
                    textContentType: .emailAddress,
                    submitLabel: .next
                )

                inputField(
                    label: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    focus: .password,
                    isSecure: true,
                    textContentType: .password,
                    submitLabel: .go
                )
            }

            Button(action: signIn) {
                HStack(spacing: 8) {
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(auth.isLoading ? "Signing In…" : "Sign In")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.white)
                .background(
                    LinearGradient(
                        colors: [
                            appTint.opacity(0.95),
                            appTint.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(isSignInDisabled ? 0.5 : 1)
                )
                .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSignInDisabled)
            .shadow(color: appTint.opacity(0.3), radius: 12, y: 4)

            Button(action: forgotPasswordTapped) {
                Text("Forgot password?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 30, y: 20)
    }

    private var createAccountButton: some View {
        Button(action: createAccount) {
            Text("Create Account")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(appTint)
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
    }

    private var isSignInDisabled: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        password.count < 6 ||
        auth.isLoading
    }

    @ViewBuilder
    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        focus: LoginField,
        isSecure: Bool = false,
        keyboard: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        textInputAutocapitalization: TextInputAutocapitalization = .never,
        submitLabel: SubmitLabel = .next
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(textContentType)
                        .submitLabel(submitLabel)
                        .focused($focusedField, equals: focus)
                } else {
                    TextField(placeholder, text: text)
                        .textContentType(textContentType)
                        .submitLabel(submitLabel)
                        .focused($focusedField, equals: focus)
                }
            }
            .keyboardType(keyboard)
            .textInputAutocapitalization(textInputAutocapitalization)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func signIn() {
        guard !isSignInDisabled else { return }
        Task { await auth.signIn(username: email, password: password) }
    }

    private func handleSubmit() {
        switch focusedField {
        case .siteKey:
            focusedField = .email
        case .email:
            focusedField = .password
        case .password:
            signIn()
        case .none:
            break
        }
    }

    private func forgotPasswordTapped() {
        auth.alertMessage = "Please contact your ShiftLink administrator to reset your password."
    }

    private func createAccount() {
        Task { await auth.signUp(username: email, password: password) }
    }
}

private struct ConfirmationView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var code = ""
    let username: String

    var body: some View {
        VStack(spacing: 18) {
            Text("Confirm Your Account")
                .font(.title3.weight(.semibold))
            Text("Enter the verification code sent to \(username)")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            TextField("Confirmation code", text: $code)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button("Confirm") {
                Task { await auth.confirm(username: username, code: code) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.isEmpty)
        }
        .padding(28)
    }
}

// MARK: - Auth Model

@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthFlow {
        case signedOut
        case needsConfirmation(String)
        case signedIn
    }

    enum ProfileUpdateError: LocalizedError {
        case invalidName
        case invalidUsername
        case confirmationRequired

        var errorDescription: String? {
            switch self {
            case .invalidName:
                return "Please provide a valid name."
            case .invalidUsername:
                return "Please provide a valid username."
            case .confirmationRequired:
                return "Additional verification is required to update your profile. Check your email for a confirmation code."
            }
        }
    }

    @Published var authFlow: AuthFlow? = .signedOut
    @Published var isAuthenticated = false
    @Published var currentUser: AuthUser?
    @Published var isAdmin = false
    @Published var isSupervisor = false
    @Published var primaryRole: String? = nil
    @Published var userProfile = UserProfileDetails()
    @Published var currentAssignment: OfficerAssignmentDTO?
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = false
    @Published var alertMessage: String?
    @Published var statusMessage: String? = nil
    
    var primaryRoleDisplayName: String? {
        guard let primaryRole, !primaryRole.isEmpty else { return nil }
        return RoleLabels.displayName(for: primaryRole)
    }

    func refreshAuthState() async {
        guard !isLoading else { return }
        isLoading = true
        statusMessage = "Checking authentication…"
        defer { isLoading = false; statusMessage = nil }
        do {
            let authSession = try await Amplify.Auth.fetchAuthSession()
            if authSession.isSignedIn {
                currentUser = try await Amplify.Auth.getCurrentUser()
                isAuthenticated = true
                authFlow = .signedIn
                updatePrivileges(from: authSession)
                await loadUserAttributes()
                await loadCurrentAssignment()
                await loadSampleData()
            } else {
                currentUser = nil
                isAuthenticated = false
                authFlow = .signedOut
                clearPrivileges()
            }
        } catch let authError as AuthError {
            presentAuthError(authError)
            resetAuthState()
        } catch {
            alertMessage = error.localizedDescription
            print("Unexpected auth session error:", error)
            resetAuthState()
        }
    }

    func signIn(username rawUsername: String, password: String) async {
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !password.isEmpty else { return }
        guard !isLoading else { return }
        isLoading = true
        alertMessage = nil
        do {
            let authSession = try await Amplify.Auth.fetchAuthSession()
            if authSession.isSignedIn {
                isLoading = false
                await refreshAuthState()
                return
            }

            let result = try await Amplify.Auth.signIn(username: username, password: password)
            if result.isSignedIn {
                isLoading = false
                await refreshAuthState()
            } else {
                if case .confirmSignUp = result.nextStep {
                    authFlow = .needsConfirmation(username)
                } else {
                    alertMessage = "Sign-in requires additional steps."
                }
                isLoading = false
            }
        } catch let authError as AuthError {
            presentAuthError(authError)
            resetAuthState()
            isLoading = false
        } catch {
            alertMessage = error.localizedDescription
            print("Unexpected sign-in error:", error)
            resetAuthState()
            isLoading = false
        }
    }

    func signUp(username rawUsername: String, password: String) async {
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            alertMessage = "Enter an email address before creating an account."
            return
        }

        guard username.contains("@"), username.contains(".") else {
            alertMessage = "Email address looks incomplete. Please double-check it."
            return
        }

        guard password.count >= 8 else {
            alertMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        alertMessage = nil
        do {
            let attributes = [AuthUserAttribute(.email, value: username)]
            let result = try await Amplify.Auth.signUp(
                username: username,
                password: password,
                options: .init(userAttributes: attributes)
            )
            if !result.isSignUpComplete {
                authFlow = .needsConfirmation(username)
                alertMessage = "Check your email for a confirmation code."
            } else {
                alertMessage = "Account created. You can sign in now."
                authFlow = .signedOut
            }
        } catch let authError as AuthError {
            presentAuthError(authError)
        } catch {
            alertMessage = error.localizedDescription
            print("Unexpected sign-up error:", error)
        }
        isLoading = false
    }

    func confirm(username: String, code: String) async {
        guard !code.isEmpty else { return }
        isLoading = true
        do {
            let result = try await Amplify.Auth.confirmSignUp(for: username, confirmationCode: code)
            if result.isSignUpComplete {
                alertMessage = "Account confirmed. Please sign in."
                authFlow = .signedOut
            } else {
                alertMessage = "Confirmation pending. Try again."
            }
        } catch let authError as AuthError {
            presentAuthError(authError)
        } catch {
            alertMessage = error.localizedDescription
            print("Unexpected confirm error:", error)
        }
        isLoading = false
    }

    func signOut() async {
        isLoading = true
        let result = await Amplify.Auth.signOut()

        func handleLocalSignOut(sidecarMessage: String? = nil) {
            resetAuthState()
            notifications.removeAll()
            if let sidecarMessage, !sidecarMessage.isEmpty {
                alertMessage = sidecarMessage
            }
        }

        if let cognitoResult = result as? AWSCognitoSignOutResult {
            switch cognitoResult {
            case .complete:
                handleLocalSignOut()
            case .partial(let revokeTokenError, let globalSignOutError, let hostedUIError):
                let issues = [
                    revokeTokenError?.error,
                    globalSignOutError?.error,
                    hostedUIError?.error
                ].compactMap { $0 }
                let message: String?
                if issues.isEmpty {
                    message = nil
                } else {
                    let details = issues.map { $0.errorDescription }.joined(separator: "\n\n")
                    message = """
                    Signed out locally, but some remote sessions could not be revoked.

                    \(details)
                    """
                }
                handleLocalSignOut(sidecarMessage: message)
            case .failed(let error):
                presentAuthError(error)
            }
        } else {
            handleLocalSignOut()
        }

        isLoading = false
    }

    func markNotificationRead(_ item: NotificationItem) {
        guard let index = notifications.firstIndex(where: { $0.id == item.id }) else { return }
        notifications[index].isRead = true
    }

    /// Temporary sample data to mimic the original Firebase-driven dashboards.
    func loadSampleData() async {
        guard notifications.isEmpty else { return }
        notifications = [
            NotificationItem(
                id: UUID(),
                title: "Amplify Connected",
                body: "Your ShiftLink app now uses AWS Amplify instead of Firebase.",
                sentAt: Date(),
                isRead: false
            ),
            NotificationItem(
                id: UUID(),
                title: "Team Update",
                body: "Share overtime assignments via the new AWS backend.",
                sentAt: Date().addingTimeInterval(-3600),
                isRead: false
            )
        ]
    }

    private func loadUserAttributes() async {
        do {
            let attributes = try await Amplify.Auth.fetchUserAttributes()
            #if DEBUG
            print("[ShiftLink] Cognito attributes:", attributes.map { "\($0.key): \($0.value)" })
            #endif
            var profile = UserProfileDetails()
            for attribute in attributes {
                switch attribute.key {
                case .email:
                    profile.email = attribute.value
                case .name:
                    profile.fullName = attribute.value
                case .nickname:
                    profile.nickname = attribute.value
                case .preferredUsername:
                    profile.preferredUsername = attribute.value
                case .custom(let name) where name.caseInsensitiveCompare("orgID") == .orderedSame:
                    profile.orgID = attribute.value
                case .custom(let name) where name.caseInsensitiveCompare("siteKey") == .orderedSame:
                    profile.siteKey = attribute.value
                case .custom(let name) where name.caseInsensitiveCompare("rank") == .orderedSame:
                    profile.rank = attribute.value
                default:
                    continue
                }
            }

            if (profile.siteKey?.isEmpty ?? true), let storedSiteKey = storedSiteKeyValue() {
                profile.siteKey = storedSiteKey
                await persistSiteKeyAttributeIfMissing(storedSiteKey)
            } else if let siteKey = profile.siteKey, !siteKey.isEmpty {
                cacheSiteKey(siteKey)
            }

            if (profile.orgID?.isEmpty ?? true), let storedOrgID = storedOrgIDValue() {
                profile.orgID = storedOrgID
                await persistOrgIDAttributeIfMissing(storedOrgID)
            } else if let orgID = profile.orgID, !orgID.isEmpty {
                cacheOrgID(orgID)
            }

            userProfile = profile
            if let rank = profile.rank, !rank.isEmpty {
                primaryRole = rank
            }
        } catch let error as AuthError {
            print("Failed to fetch user attributes:", error)
        } catch {
            print("Failed to fetch user attributes:", error)
        }
    }

    private func loadCurrentAssignment() async {
        guard
            let orgId = userProfile.orgID,
            !orgId.isEmpty,
            let badgeNumber = currentUser?.username ?? currentUser?.userId
        else {
            currentAssignment = nil
            return
        }

        do {
            currentAssignment = try await ShiftlinkAPI.fetchCurrentAssignment(orgId: orgId, badgeNumber: badgeNumber)
        } catch {
            print("Failed to fetch current assignment:", error)
            currentAssignment = nil
        }
    }

    private func storedSiteKeyValue() -> String? {
        UserDefaults.standard.string(forKey: "shiftlink.siteKey")?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cacheSiteKey(_ value: String) {
        UserDefaults.standard.set(value, forKey: "shiftlink.siteKey")
    }

    private func persistSiteKeyAttributeIfMissing(_ siteKey: String) async {
        guard !siteKey.isEmpty else { return }
        do {
            let attribute = AuthUserAttribute(.custom("siteKey"), value: siteKey)
            _ = try await Amplify.Auth.update(userAttributes: [attribute])
        } catch {
            print("Failed to persist siteKey attribute:", error)
        }
    }

    private func storedOrgIDValue() -> String? {
        UserDefaults.standard.string(forKey: "shiftlink.orgID")?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cacheOrgID(_ value: String) {
        UserDefaults.standard.set(value, forKey: "shiftlink.orgID")
    }

    private func persistOrgIDAttributeIfMissing(_ orgID: String) async {
        guard !orgID.isEmpty else { return }
        do {
            let attribute = AuthUserAttribute(.custom("orgID"), value: orgID)
            _ = try await Amplify.Auth.update(userAttributes: [attribute])
        } catch {
            print("Failed to persist orgID attribute:", error)
        }
    }

    func updateProfile(name rawName: String, preferredUsername rawUsername: String) async throws {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { throw ProfileUpdateError.invalidName }
        guard !username.isEmpty else { throw ProfileUpdateError.invalidUsername }

        let attributes = [
            AuthUserAttribute(.name, value: name),
            AuthUserAttribute(.preferredUsername, value: username),
            AuthUserAttribute(.nickname, value: name)
        ]

        let results = try await Amplify.Auth.update(userAttributes: attributes)
        let requiresConfirmation = results.values.contains { result in
            if case .confirmAttributeWithCode = result.nextStep { return true }
            return false
        }

        if requiresConfirmation {
            throw ProfileUpdateError.confirmationRequired
        }

        await loadUserAttributes()
    }

    private func updatePrivileges(from session: AuthSession) {
        guard let cognitoSession = session as? AWSAuthCognitoSession else {
            clearPrivileges()
            return
        }

        switch cognitoSession.userPoolTokensResult {
        case .success(let tokens):
            let rawGroups = AuthViewModel.extractGroups(from: tokens.idToken)
            let groups = rawGroups
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let normalizedGroups = groups.map { $0.lowercased() }
            isAdmin = normalizedGroups.contains("admin")
            isSupervisor = normalizedGroups.contains("supervisor")
            if let primary = groups.first(where: { $0.caseInsensitiveCompare("admin") != ComparisonResult.orderedSame }) ?? groups.first {
                primaryRole = primary
            } else {
                primaryRole = nil
            }
        case .failure:
            clearPrivileges()
        }
    }

    private func clearPrivileges() {
        isAdmin = false
        isSupervisor = false
        primaryRole = nil
    }

    private static func extractGroups(from idToken: String) -> [String] {
        guard let payload = decodeJWTPayload(idToken) else { return [] }
        if let groups = payload["cognito:groups"] as? [String] {
            return groups
        }
        if let groups = payload["cognito:groups"] as? [Any] {
            return groups.compactMap { $0 as? String }
        }
        if let group = payload["cognito:groups"] as? String {
            return [group]
        }
        return []
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = String(segments[1])
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func resetAuthState() {
        currentUser = nil
        isAuthenticated = false
        authFlow = .signedOut
        clearPrivileges()
        userProfile = UserProfileDetails()
        currentAssignment = nil
    }

    private func presentAuthError(_ error: AuthError) {
        var messageParts: [String] = []

        func append(_ text: String?) {
            guard let text = text, !text.isEmpty else { return }
            if !messageParts.contains(text) {
                messageParts.append(text)
            }
        }

        switch error {
        case .service(let message, let suggestion, let underlying),
             .notAuthorized(let message, let suggestion, let underlying),
             .configuration(let message, let suggestion, let underlying),
             .signedOut(let message, let suggestion, let underlying),
             .invalidState(let message, let suggestion, let underlying),
             .sessionExpired(let message, let suggestion, let underlying):
            append(message)
            append(suggestion)
            append((underlying as NSError?)?.localizedDescription)
        case .validation(_, let message, let suggestion, let underlying):
            append(message)
            append(suggestion)
            append((underlying as NSError?)?.localizedDescription)
        case .unknown(let message, let underlying):
            append(message)
            append((underlying as NSError?)?.localizedDescription)
        default:
            append(error.errorDescription)
            append(error.recoverySuggestion)
            append((error.underlyingError as NSError?)?.localizedDescription)
        }

        if messageParts.isEmpty {
            messageParts.append("Authentication failed. Please try again.")
        }

        alertMessage = messageParts.joined(separator: "\n\n")
        print("Amplify AuthError:", error)
    }
}

// MARK: - Models

struct UserProfileDetails {
    var email: String?
    var fullName: String?
    var nickname: String?
    var preferredUsername: String?
    var orgID: String?
    var siteKey: String?
    var rank: String?

    var displayName: String? {
        if let name = fullName, !name.isEmpty { return name }
        if let preferred = preferredUsername, !preferred.isEmpty { return preferred }
        if let nickname = nickname, !nickname.isEmpty { return nickname }
        if let email = email, !email.isEmpty { return email }
        return nil
    }
}

struct NotificationItem: Identifiable {
    let id: UUID
    var title: String
    var body: String
    var sentAt: Date
    var isRead: Bool
}

extension Date {
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Placeholder Destination Views

private struct PlaceholderPane: View {
    var title: String
    var systemImage: String
    var message: String
    @Environment(\.appTint) private var appTint

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(appTint)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Temporary Destination Stubs

private struct SquadRosterView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = RosterEntriesViewModel()
    @State private var actionMessage: String?
    @State private var hasLoaded = false
    @State private var activeSheet: SquadSheet?

    private enum SquadSheet: String, Identifiable {
        case newNotification
        case manageMembers

        var id: String { rawValue }
    }

    private var squadName: String {
        if let role = auth.primaryRoleDisplayName, !role.isEmpty {
            return role
        }
        if let nickname = auth.userProfile.displayName, !nickname.isEmpty {
            return "\(nickname)'s Squad"
        }
        return "Unassigned Squad"
    }

    private var assignedSupervisors: [String] {
        let supervisorHints = [
            auth.userProfile.rank,
            auth.isSupervisor ? auth.userProfile.displayName : nil
        ].compactMap { $0 }.filter { !$0.isEmpty }

        if supervisorHints.isEmpty {
            return []
        }
        return supervisorHints
    }

    private var canManageSquad: Bool {
        auth.isAdmin || auth.isSupervisor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                squadHeaderCard
                squadRosterCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Squad")
        .alert(
            "Squad Actions",
            isPresented: Binding(
                get: { actionMessage != nil },
                set: { if !$0 { actionMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newNotification:
                NewSquadNotificationView()
            case .manageMembers:
                ManageSquadMembersView(
                    viewModel: viewModel,
                    orgId: auth.userProfile.orgID
                )
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.load(orgId: auth.userProfile.orgID, badgeNumber: nil)
        }
    }

    private var squadHeaderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Squad")
                    .font(.title2.weight(.semibold))
                Text(squadName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Assigned Supervisors")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if assignedSupervisors.isEmpty {
                    Text("No supervisors have been assigned yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assignedSupervisors, id: \.self) { supervisor in
                        Label(supervisor, systemImage: "badge")
                            .font(.subheadline)
                    }
                }
            }

            if canManageSquad {
                VStack(spacing: 12) {
                    Button {
                        activeSheet = .newNotification
                    } label: {
                        Label("+ Send New Squad Notification", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        activeSheet = .manageMembers
                    } label: {
                        Label("Manage Squad Members", systemImage: "person.3.sequence.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var squadRosterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Squad Roster")
                .font(.headline)

            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView("Loading assignments…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if viewModel.entries.isEmpty {
                Text("No roster entries are currently assigned to your squad.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(previewEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.shiftLabel)
                                    .font(.subheadline.weight(.semibold))
                                Text("Badge / Computer #: \(entry.badgeNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(entry.durationDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < previewEntries.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var previewEntries: [RosterEntryDTO] {
        viewModel.entries
            .sorted { $0.startsAt < $1.startsAt }
            .prefix(5)
            .map { $0 }
    }
}


private struct OvertimeBoardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @StateObject private var viewModel = OvertimeBoardViewModel()

    private var orgId: String? { auth.userProfile.orgID }

    private var userId: String? {
        if let id = auth.currentUser?.userId, !id.isEmpty { return id }
        if let username = auth.userProfile.preferredUsername, !username.isEmpty { return username }
        if let email = auth.userProfile.email, !email.isEmpty { return email }
        return nil
    }

    var body: some View {
        List {
            summarySection
            recentAssignmentsSection
            openPositionsSection
            if !recentlyFilled.isEmpty {
                recentlyFilledSection
            }
            historySection
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading overtime…")
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .navigationTitle("Overtime")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.load(orgId: orgId, userId: userId)
        }
        .alert(
            "Overtime",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("Year to Date") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Hours worked", systemImage: "clock.badge.checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(yearToDateHours, specifier: "%.1f") hrs")
                        .font(.title3.weight(.semibold))
                }
                HStack {
                    Label("Assignments", systemImage: "badge.clock.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(assignmentsThisYear)")
                        .font(.title3.weight(.semibold))
                }
                if let latest = recentAssignments.first {
                    Text("Most recent: \(latest.title) on \(latest.startsAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No overtime recorded yet this year.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var recentAssignmentsSection: some View {
        Section("Recent Jobs") {
            if recentAssignments.isEmpty {
                Text("Any overtime you accept will appear here along with the total hours credited to you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentAssignments) { assignment in
                    assignmentRow(for: assignment)
                }
            }
        }
    }

    @ViewBuilder
    private var openPositionsSection: some View {
        Section {
            if viewModel.available.isEmpty {
                Text("No overtime assignments are open right now. Pull to refresh or check back later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.available) { posting in
                    infoCard(
                        posting,
                        badge: "Open Position",
                        accent: .green,
                        footer: posting.details?.contact?.isEmpty == false
                            ? "Contact \(posting.details?.contact ?? "your supervisor") to volunteer."
                            : nil
                    )
                }
            }
        } header: {
            Text("Open Overtime Positions")
        } footer: {
            Text("ShiftLink notifies you when new overtime openings are posted.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recentlyFilledSection: some View {
        Section("Latest Coverage") {
            ForEach(recentlyFilled) { posting in
                infoCard(
                    posting,
                    badge: "Covered",
                    accent: .gray,
                    footer: "Covered by \(posting.ownerId)"
                )
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section {
            if historyAssignments.isEmpty {
                Text("You haven't completed overtime shifts yet, but your history will show here once you do.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    OvertimeHistoryView(assignments: historyAssignments)
                } label: {
                    Label("Review past overtime", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var yearToDateHours: Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return viewModel.myAssignments
            .filter { calendar.component(.year, from: $0.startsAt) == currentYear }
            .reduce(0) { $0 + hours(for: $1) }
    }

    private var assignmentsThisYear: Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return viewModel.myAssignments.filter { calendar.component(.year, from: $0.startsAt) == currentYear }.count
    }

    private var recentAssignments: [OvertimePostingDTO] {
        viewModel.myAssignments
            .sorted { $0.startsAt > $1.startsAt }
            .prefix(5)
            .map { $0 }
    }

    private var historyAssignments: [OvertimePostingDTO] {
        viewModel.myAssignments
            .filter { $0.endsAt < Date() }
            .sorted { $0.startsAt > $1.startsAt }
    }

    private var recentlyFilled: [OvertimePostingDTO] {
        viewModel.filled
            .sorted { $0.startsAt > $1.startsAt }
            .prefix(5)
            .map { $0 }
    }

    private func assignmentRow(for posting: OvertimePostingDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(posting.title)
                        .font(.headline)
                    Text(posting.windowDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(hoursString(for: posting))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(appTint.opacity(0.12), in: Capsule())
            }
            overtimeDetailStack(for: posting)
        }
        .padding(.vertical, 4)
    }

    private func infoCard(
        _ posting: OvertimePostingDTO,
        badge: String,
        accent: Color,
        footer: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(posting.title)
                    .font(.headline)
                Spacer()
                Text(badge.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(accent)
            }
            Text(posting.windowDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            overtimeDetailStack(for: posting)
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func hours(for posting: OvertimePostingDTO) -> Double {
        max(0, posting.endsAt.timeIntervalSince(posting.startsAt) / 3600)
    }

    private func hoursString(for posting: OvertimePostingDTO) -> String {
        let value = hours(for: posting)
        if value >= 10 {
            return String(format: "%.0f hrs", value)
        } else {
            return String(format: "%.1f hrs", value)
        }
    }
}

@MainActor
private final class OvertimeBoardViewModel: ObservableObject {
    @Published private(set) var available: [OvertimePostingDTO] = []
    @Published private(set) var filled: [OvertimePostingDTO] = []
    @Published private(set) var myAssignments: [OvertimePostingDTO] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var cachedOrgId: String?
    private var cachedUserId: String?

    func load(orgId: String?, userId: String?) async {
        guard let orgId, !orgId.isEmpty else {
            available = []
            filled = []
            myAssignments = []
            errorMessage = "Missing agency identifier. Ask an administrator to add the custom:orgID attribute to your profile."
            return
        }

        cachedOrgId = orgId
        cachedUserId = userId
        await fetchOvertime(orgId: orgId, userId: userId)
    }

    func refresh() async {
        guard let orgId = cachedOrgId, !orgId.isEmpty else { return }
        await fetchOvertime(orgId: orgId, userId: cachedUserId)
    }

    private func fetchOvertime(orgId: String, userId: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let postings = try await ShiftlinkAPI.listOvertimePostings(orgId: orgId)
            updateCollections(with: postings, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateCollections(with postings: [OvertimePostingDTO], userId: String?) {
        let unassignedToken = ShiftlinkAPI.unassignedOwnerToken

        available = postings
            .filter { $0.ownerId.caseInsensitiveCompare(unassignedToken) == .orderedSame }
            .sorted { $0.startsAt < $1.startsAt }

        filled = postings
            .filter { $0.ownerId.caseInsensitiveCompare(unassignedToken) != .orderedSame }
            .sorted { $0.startsAt > $1.startsAt }

        if let userId, !userId.isEmpty {
            myAssignments = postings
                .filter { $0.ownerId.caseInsensitiveCompare(userId) == .orderedSame }
                .sorted { $0.startsAt > $1.startsAt }
        } else {
            myAssignments = []
        }
    }
}

private struct OvertimeHistoryView: View {
    let assignments: [OvertimePostingDTO]
    @Environment(\.appTint) private var appTint

    private var groupedHistory: [(year: Int, records: [OvertimePostingDTO])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: assignments) { calendar.component(.year, from: $0.startsAt) }
        return groups
            .map { (year: $0.key, records: $0.value.sorted { $0.startsAt > $1.startsAt }) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        List {
            if groupedHistory.isEmpty {
                Text("No overtime history recorded yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(groupedHistory, id: \.year) { entry in
                    Section("\(entry.year)") {
                        ForEach(entry.records) { record in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.title)
                                            .font(.headline)
                                        Text(record.windowDescription)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(hoursString(for: record))
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(appTint.opacity(0.12), in: Capsule())
                                }
                                overtimeDetailStack(for: record)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Overtime History")
    }

    private func hoursString(for posting: OvertimePostingDTO) -> String {
        let value = max(0, posting.endsAt.timeIntervalSince(posting.startsAt) / 3600)
        if value >= 10 {
            return String(format: "%.0f hrs", value)
        } else {
            return String(format: "%.1f hrs", value)
        }
    }
}

@ViewBuilder
private func overtimeDetailStack(for posting: OvertimePostingDTO) -> some View {
    if let details = posting.details {
        VStack(alignment: .leading, spacing: 4) {
            Label(details.location, systemImage: "mappin.and.ellipse")
                .font(.footnote)
            Label("Rate: \(details.rate)", systemImage: "dollarsign.circle")
                .font(.footnote)
            if let contact = details.contact, !contact.isEmpty {
                Label(contact, systemImage: "envelope")
                    .font(.footnote)
            }
            if let poster = details.postedByName {
                Label("Posted by \(poster)", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PatrolAssignmentsView: View {
    var body: some View {
        PlaceholderPane(
            title: "Patrol assignments unavailable",
            systemImage: "target",
            message: "We’re rebuilding this workflow. Check back later."
        )
        .navigationTitle("Patrols")
    }
}

private struct VehicleRosterView: View {
    var body: some View {
        PlaceholderPane(
            title: "Vehicle roster unavailable",
            systemImage: "car.fill",
            message: "Vehicle assignments will be restored soon."
        )
        .navigationTitle("Vehicle Roster")
    }
}

private struct ShiftTemplateLibraryView: View {
    var body: some View {
        PlaceholderPane(
            title: "Shift templates unavailable",
            systemImage: "calendar.badge.clock",
            message: "Template management is disabled while calendar work is underway."
        )
        .navigationTitle("Shift Templates")
    }
}

private struct SendDepartmentAlertView: View {
    var body: some View {
        PlaceholderPane(
            title: "Department alerts unavailable",
            systemImage: "megaphone.fill",
            message: "Alert sending is temporarily offline. Please notify your team manually."
        )
        .navigationTitle("Send Alert")
    }
}

private struct NewSquadNotificationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var titleText = ""
    @State private var descriptionText = ""
    @State private var includeDateTime = false
    @State private var scheduledDate = Date()
    @State private var recipientScope: RecipientScope = .entireSquad
    @State private var requiresAcknowledgment = true
    @State private var deliveryPriority: DeliveryPriority = .normal
    @State private var attachments: [MockAttachment] = []

    private let attachmentFormatsDescription = "Max 10 • JPG, PNG, HEIC, MP4, MOV, PDF, TXT, DOC, DOCX, XLSX • ≤ 50 MB each"

    var body: some View {
        NavigationStack {
            Form {
                Section("DETAILS") {
                    TextField("Title", text: $titleText)
                        .textInputAutocapitalization(.sentences)
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)

                    Toggle(isOn: $includeDateTime) {
                        Text("Add Date & Time")
                    }
                    if includeDateTime {
                        DatePicker(
                            "Scheduled for",
                            selection: $scheduledDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("ATTACHMENTS") {
                    Button {
                        addPlaceholderAttachment()
                    } label: {
                        Label("Add Attachment", systemImage: "paperclip")
                    }

                    if attachments.isEmpty {
                        Text("No attachments added.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { attachment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(attachment.name)
                                        .font(.subheadline)
                                    Text(attachment.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    removeAttachment(attachment)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Color.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Text(attachmentFormatsDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("RECIPIENTS") {
                    Picker("Recipients", selection: $recipientScope) {
                        ForEach(RecipientScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    if recipientScope == .selectRecipients {
                        Text("Select specific recipients after composing the notification.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("DELIVERY") {
                    Toggle("Requires acknowledgment", isOn: $requiresAcknowledgment)

                    Picker("Priority", selection: $deliveryPriority) {
                        ForEach(DeliveryPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        dismiss()
                    }
                    .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addPlaceholderAttachment() {
        guard attachments.count < 10 else { return }
        let nextNumber = attachments.count + 1
        attachments.append(.init(name: "Attachment \(nextNumber).pdf"))
    }

    private func removeAttachment(_ attachment: MockAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    private enum RecipientScope: String, CaseIterable, Identifiable {
        case entireSquad
        case selectRecipients

        var id: String { rawValue }

        var title: String {
            switch self {
            case .entireSquad: return "Entire Squad"
            case .selectRecipients: return "Select Recipients"
            }
        }
    }

    private enum DeliveryPriority: String, CaseIterable, Identifiable {
        case normal
        case urgent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .normal: return "Normal"
            case .urgent: return "Urgent"
            }
        }
    }

    private struct MockAttachment: Identifiable {
        let id = UUID()
        let name: String

        var detail: String {
            "Placeholder attachment"
        }
    }
}

private struct ManageSquadMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RosterEntriesViewModel
    let orgId: String?

    @State private var newBadgeNumberInput = ""
    @State private var newShift = ""
    @State private var shiftStartsAt = Date()
    @State private var shiftEndsAt = Date().addingTimeInterval(4 * 3600)
    @State private var isMutating = false
    @State private var alertMessage: String?

    private var trimmedBadgeNumber: String {
        newBadgeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedShiftName: String {
        newShift.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isMissingOrgId: Bool {
        orgId?.isEmpty ?? true
    }

    private var canAddAssignment: Bool {
        guard !isMissingOrgId else { return false }
        return !trimmedBadgeNumber.isEmpty && shiftEndsAt > shiftStartsAt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("CURRENT SQUAD") {
                    if viewModel.entries.isEmpty {
                        Text("No officers are assigned to this squad yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.shiftLabel)
                                    .font(.headline)
                                Text("Badge / Computer #: \(entry.badgeNumber)")
                                    .font(.subheadline)
                                Text(entry.durationDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await removeEntry(id: entry.id) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            Task { await deleteEntries(at: offsets) }
                        }
                    }
                }

                Section("ADD OFFICER") {
                    if isMissingOrgId {
                        Text("Missing the custom:orgID attribute. Ask an administrator to update your profile before managing squad assignments.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    TextField("Badge / Computer #", text: $newBadgeNumberInput)
                        .textInputAutocapitalization(.characters)

                    TextField("Shift name (optional)", text: $newShift)

                    DatePicker(
                        "Starts",
                        selection: $shiftStartsAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "Ends",
                        selection: $shiftEndsAt,
                        in: shiftStartsAt...Date().addingTimeInterval(60 * 60 * 24 * 180),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Button {
                        Task { await addOfficer() }
                    } label: {
                        Label("Add To Squad", systemImage: "plus.circle.fill")
                    }
                    .disabled(!canAddAssignment || isMutating)
                }

                Section {
                    Text("Add or remove squad members and the changes sync immediately with your AWS backend.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Manage Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .onChange(of: shiftStartsAt, initial: false) { _, newValue in
                if shiftEndsAt <= newValue {
                    shiftEndsAt = newValue.addingTimeInterval(60 * 60)
                }
            }
            .alert(
                "Manage Squad",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func addOfficer() async {
        guard let orgId, !orgId.isEmpty else { return }
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            try await viewModel.addRosterEntry(
                orgId: orgId,
                badgeNumber: trimmedBadgeNumber,
                shift: trimmedShiftName.isEmpty ? nil : trimmedShiftName,
                startsAt: shiftStartsAt,
                endsAt: shiftEndsAt
            )
            resetFormDates()
            newBadgeNumberInput = ""
            newShift = ""
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func resetFormDates() {
        let newStart = Date()
        shiftStartsAt = newStart
        shiftEndsAt = newStart.addingTimeInterval(4 * 3600)
    }

    private func removeEntry(id: String) async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            try await viewModel.removeRosterEntry(id: id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deleteEntries(at offsets: IndexSet) async {
        for index in offsets {
            guard viewModel.entries.indices.contains(index) else { continue }
            let entry = viewModel.entries[index]
            await removeEntry(id: entry.id)
        }
    }
}

@MainActor
private final class RosterEntriesViewModel: ObservableObject {
    @Published private(set) var entries: [RosterEntryDTO] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var cachedOrgId: String?
    private var cachedBadgeNumber: String?

    func load(orgId: String?, badgeNumber: String?) async {
        guard let orgId, !orgId.isEmpty else {
            entries = []
            errorMessage = "Missing agency identifier. Ask an administrator to add the custom:orgID attribute to your profile."
            return
        }

        cachedOrgId = orgId
        cachedBadgeNumber = badgeNumber
        await fetchRoster(orgId: orgId, badgeNumber: badgeNumber)
    }

    func refresh() async {
        guard let orgId = cachedOrgId else { return }
        await fetchRoster(orgId: orgId, badgeNumber: cachedBadgeNumber)
    }

    func addRosterEntry(
        orgId: String,
        badgeNumber: String,
        shift: String?,
        startsAt: Date,
        endsAt: Date
    ) async throws {
        let input = NewRosterEntryInput(
            orgId: orgId,
            badgeNumber: badgeNumber,
            shift: shift,
            startsAt: startsAt,
            endsAt: endsAt
        )
        let newEntry = try await ShiftlinkAPI.createRosterEntry(input)
        upsert(entry: newEntry)
    }

    func removeRosterEntry(id: String) async throws {
        try await ShiftlinkAPI.deleteRosterEntry(id: id)
        entries.removeAll { $0.id == id }
    }

    private func fetchRoster(orgId: String, badgeNumber: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await ShiftlinkAPI.listRosterEntries(orgId: orgId, badgeNumber: badgeNumber)
            entries = fetched.sorted { $0.startsAt < $1.startsAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(entry: RosterEntryDTO) {
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        entries.sort { $0.startsAt < $1.startsAt }
    }
}

private enum MyLogDestination: Hashable {
    case notes
    case certifications

    var title: String {
        switch self {
        case .notes: return "My Notes"
        case .certifications: return "My Certifications"
        }
    }

    var systemImage: String {
        switch self {
        case .notes: return "note.text"
        case .certifications: return "rosette"
        }
    }

    var placeholderMessage: String {
        switch self {
        case .notes: return "Review and manage personal notes from your shifts."
        case .certifications: return "Keep an eye on certification status and expirations."
        }
    }
}

private struct MyLogView: View {
    private let logDestinations: [MyLogDestination] = [
        .notes,
        .certifications
    ]

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                Text("My Log")
                    .font(.largeTitle.weight(.bold))

                VStack(spacing: 16) {
                    ForEach(logDestinations, id: \.self) { destination in
                        NavigationLink(value: destination) {
                            MyLogMenuButton(
                                title: destination.title,
                                systemImage: destination.systemImage
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Log")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MyLogDestination.self) { destination in
            switch destination {
            case .notes:
                MyNotesView()
            case .certifications:
                MyCertificationsView()
            }
        }
    }
}

private struct MyLogMenuButton: View {
    let title: String
    let systemImage: String
    @Environment(\.appTint) private var appTint

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(appTint)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(appTint.opacity(0.12))
                )

            Text(title)
                .font(.headline)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 6)
    }
}

// MARK: - My Calendar

private struct MyCalendarView: View {
    @State private var focusDate = Date()
    private let entries = ShiftScheduleEntry.sampleUpcoming
    private var calendar: Calendar { Calendar.current }

    private var nextShift: ShiftScheduleEntry? {
        entries
            .sorted { $0.start < $1.start }
            .first { $0.end > Date() }
    }

    private var selectedDayEntries: [ShiftScheduleEntry] {
        let target = calendar.startOfDay(for: focusDate)
        return entries.filter { calendar.isDate($0.start, inSameDayAs: target) }
    }

    private var weekAheadGroups: [(date: Date, entries: [ShiftScheduleEntry])] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.start) }
        return grouped.keys
            .sorted()
            .map { date in
                (date, grouped[date]?.sorted { $0.start < $1.start } ?? [])
            }
    }

    var body: some View {
        List {
            if let nextShift {
                Section("Next shift") {
                    NextShiftCard(entry: nextShift)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            Section {
                DatePicker("Select date", selection: $focusDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }

            Section(focusDate.formatted(date: .complete, time: .omitted)) {
                if selectedDayEntries.isEmpty {
                    Text("No shifts scheduled for this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(selectedDayEntries) { entry in
                        CalendarShiftRow(entry: entry)
                    }
                }
            }

            Section("Week ahead") {
                ForEach(weekAheadGroups, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.date.formatted(date: .complete, time: .omitted))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(group.entries) { entry in
                            CalendarShiftRow(entry: entry)
                            if entry.id != group.entries.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Calendar")
    }
}

private struct NextShiftCard: View {
    let entry: ShiftScheduleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.assignment)
                        .font(.headline)
                    Text(entry.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(entry.durationDescription)
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(entry.kind.tint.opacity(0.18), in: Capsule())
            }

            HStack(alignment: .center, spacing: 12) {
                Label(
                    entry.start.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                )
                .font(.subheadline)

                Spacer()

                Label(
                    entry.timeRangeDescription,
                    systemImage: "clock.fill"
                )
                .font(.subheadline)
            }

            Text(entry.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            entry.kind.tint.opacity(0.15),
                            entry.kind.tint.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct CalendarShiftRow: View {
    let entry: ShiftScheduleEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Text(entry.start.formatted(date: .omitted, time: .shortened))
                    .font(.callout.weight(.semibold))
                Text(entry.end.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.assignment)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Label(entry.kind.label, systemImage: entry.kind.icon)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(entry.kind.tint)
                        .background(entry.kind.tint.opacity(0.12), in: Capsule())
                }
                Text(entry.location)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ShiftScheduleEntry: Identifiable {
    enum Kind {
        case patrol, overtime, training, court

        var label: String {
            switch self {
            case .patrol: return "Patrol"
            case .overtime: return "Overtime"
            case .training: return "Training"
            case .court: return "Court"
            }
        }

        var tint: Color {
            switch self {
            case .patrol: return .blue
            case .overtime: return .orange
            case .training: return .purple
            case .court: return .red
            }
        }

        var icon: String {
            switch self {
            case .patrol: return "shield"
            case .overtime: return "clock.arrow.circlepath"
            case .training: return "graduationcap.fill"
            case .court: return "building.columns.fill"
            }
        }
    }

    let id = UUID()
    let start: Date
    let end: Date
    let assignment: String
    let location: String
    let detail: String
    let kind: Kind

    var durationDescription: String {
        let hours = Int(end.timeIntervalSince(start) / 3600)
        return "\(hours)h shift"
    }

    var timeRangeDescription: String {
        "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    static var sampleUpcoming: [ShiftScheduleEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        return [
            ShiftScheduleEntry(
                start: day(0, hour: 7),
                end: day(0, hour: 15),
                assignment: "Day Watch - Patrol",
                location: "3rd Precinct / Beat 12",
                detail: "Briefing at 06:45 with Sgt. Powell.",
                kind: .patrol
            ),
            ShiftScheduleEntry(
                start: day(1, hour: 12),
                end: day(1, hour: 16),
                assignment: "Court Appearance",
                location: "County Courthouse Room 4B",
                detail: "Bring case #24-1187 evidence binder.",
                kind: .court
            ),
            ShiftScheduleEntry(
                start: day(2, hour: 9),
                end: day(2, hour: 17),
                assignment: "Crisis Negotiator Training",
                location: "HQ Training Center",
                detail: "Business casual attire.",
                kind: .training
            ),
            ShiftScheduleEntry(
                start: day(3, hour: 18),
                end: day(3, hour: 22),
                assignment: "Overtime - Special Event",
                location: "Riverfront Stadium",
                detail: "Event channel 4, stage near Gate B.",
                kind: .overtime
            ),
            ShiftScheduleEntry(
                start: day(5, hour: 7),
                end: day(5, hour: 15),
                assignment: "Day Watch - Patrol",
                location: "3rd Precinct / Beat 12",
                detail: "Partner with Officer Chen.",
                kind: .patrol
            )
        ]
    }
}

// MARK: - My Log Feature Views

private struct MyOvertimeView: View {
    var body: some View {
        OvertimeBoardView()
    }
}

private struct MyNotesView: View {
    @StateObject private var viewModel = MyNotesViewModel()
    @State private var searchText = ""
    @State private var showingComposeSheet = false

    private var visibleNotes: [ShiftNote] {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.notes
            .filter { note in
                guard !searchTerm.isEmpty else { return true }
                return note.title.lowercased().contains(searchTerm) ||
                    note.body.lowercased().contains(searchTerm)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section("My Notes") {
                if visibleNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No notes yet.")
                            .font(.headline)
                        Text(searchText.isEmpty ? "Tap the compose button to capture a private note for yourself." : "Try a different search term or clear the search field.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(visibleNotes) { note in
                        NavigationLink {
                            ShiftNoteDetailView(
                                note: note,
                                onSave: { updated in viewModel.update(note: updated) }
                            )
                        } label: {
                            ShiftNoteRow(note: note)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search My Notes")
        .navigationTitle("My Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingComposeSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Add note")
            }
        }
        .sheet(isPresented: $showingComposeSheet) {
            NavigationStack {
                NewShiftNoteSheet(viewModel: viewModel)
            }
        }
    }
}

private final class MyNotesViewModel: ObservableObject {
    @Published private(set) var notes: [ShiftNote]

    init() {
        notes = Self.sampleNotes
    }

    func add(note: ShiftNote) {
        notes.insert(note, at: 0)
    }

    func update(note: ShiftNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
    }

    private static var sampleNotes: [ShiftNote] {
        let calendar = Calendar.current
        let now = Date()

        return [
            ShiftNote(
                id: UUID(),
                title: "Robbery follow-up checklist",
                body: """
• Confirm video request submitted to Metro Storage
• Call victim to provide status update before 1800
• Prepare lineup packet for Det. Harper
""",
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            ShiftNote(
                id: UUID(),
                title: "Patrol debrief – Sector 4",
                body: """
Noted increased loitering near Riverside Park restrooms after 2200. Request directed patrol for next week and coordinate with parks liaison. Logged incident #24-8841 for reference.
""",
                createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now
            ),
            ShiftNote(
                id: UUID(),
                title: "Training takeaways – Crisis Intervention",
                body: """
Key phrase reminder: “I'm here to listen and keep you safe.” Add to pocket card.
Need to share scenario #3 insights with squad at next roll call.
""",
                createdAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now
            )
        ]
    }
}

private struct ShiftNote: Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var createdAt: Date
}

private struct ShiftNoteRow: View {
    let note: ShiftNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title)
                    .font(.headline)
                Spacer()
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(note.body)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
    }
}

private struct NewShiftNoteSheet: View {
    @ObservedObject var viewModel: MyNotesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Give this note a title", text: $title)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Note") {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("Write your private notes here…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.horizontal, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section {
                Button {
                    saveNote()
                } label: {
                    Label("Save Note", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                }
                .disabled(isSaveDisabled)
            }
        }
        .navigationTitle("New Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func saveNote() {
        let note = ShiftNote(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Note" : title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

        viewModel.add(note: note)
        dismiss()
    }
}

private struct ShiftNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ShiftNote
    let onSave: (ShiftNote) -> Void

    init(note: ShiftNote, onSave: @escaping (ShiftNote) -> Void) {
        _draft = State(initialValue: note)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $draft.title)
                    .textInputAutocapitalization(.sentences)
                Text("Created \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Note") {
                TextEditor(text: $draft.body)
                    .frame(minHeight: 220)
                    .overlay(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text("Write your private notes here…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.horizontal, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct MyCertificationsView: View {
    @StateObject private var viewModel = MyCertificationsViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section("Overview") {
                Text("Keep digital copies of your certifications, licenses, or course completions. Upload a PDF or photo for each record so supervisors can verify them quickly.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Uploaded Certifications") {
                if viewModel.certifications.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No certifications uploaded yet.")
                            .font(.headline)
                        Text("Tap \"Add Certification\" to attach a file and keep it handy in ShiftLink.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(viewModel.certifications) { certification in
                        CertificationUploadRow(certification: certification)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Certifications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Certification", systemImage: "plus.circle.fill")
                }
                .accessibilityLabel("Add certification")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                AddCertificationSheet(viewModel: viewModel)
            }
        }
    }
}

private struct OvertimeAuditView: View {
    @StateObject private var viewModel = OvertimeAuditViewModel()
    @State private var startDate: Date = {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: Date())
        return calendar.date(from: components) ?? Date()
    }()
    @State private var endDate = Date()
    @State private var selectedShift = "All"
    @State private var officerQuery = ""

    private let shiftOptions = ["All", "Day", "Evening", "Night"]

    var body: some View {
        List {
            Section("Filters") {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)

                Picker("Shift", selection: $selectedShift) {
                    ForEach(shiftOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }

                TextField("Officer name or badge", text: $officerQuery)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Button {
                    runAudit()
                } label: {
                    Label("Run Audit", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section {
                if viewModel.filteredRecords.isEmpty {
                    Text("No overtime records match your filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(viewModel.filteredRecords) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(record.assignment)
                                    .font(.headline)
                                Spacer()
                                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Label(record.officer, systemImage: "badge.clock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                Label(record.shift, systemImage: "clock")
                                Label("\(record.hours.formatted(.number.precision(.fractionLength(1)))) hrs", systemImage: "hourglass")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Results")
            } footer: {
                Text("Total hours: \(viewModel.totalHours.formatted(.number.precision(.fractionLength(1))))")
                    .font(.caption.weight(.semibold))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Overtime Audit")
        .onAppear {
            runAudit()
        }
    }

    private func runAudit() {
        viewModel.runAudit(
            startDate: startDate,
            endDate: endDate,
            shift: selectedShift,
            officerQuery: officerQuery
        )
    }
}

private struct CertificationUploadRow: View {
    let certification: CertificationUpload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(certification.title)
                .font(.headline)

            if let agency = certification.issuingAgency, !agency.isEmpty {
                Label(agency, systemImage: "building.columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let issued = certification.issuedOn {
                Label("Issued \(issued.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let attachmentName = certification.attachmentName {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                    Text(attachmentName)
                    Spacer()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                Text("No attachment yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AddCertificationSheet: View {
    @ObservedObject var viewModel: MyCertificationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var issuingAgency = ""
    @State private var issuedOn = Date()
    @State private var includeIssueDate = true
    @State private var attachmentURL: URL?
    @State private var showingDocumentPicker = false

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Certification name", text: $title)
                    .textInputAutocapitalization(.words)

                TextField("Issuing agency (optional)", text: $issuingAgency)
                    .textInputAutocapitalization(.words)

                Toggle("Include issue date", isOn: $includeIssueDate.animation())
                if includeIssueDate {
                    DatePicker("Issued on", selection: $issuedOn, displayedComponents: .date)
                }
            }

            Section("Attachment") {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Label("Select file", systemImage: "paperclip")
                }

                if let attachmentURL {
                    Text(attachmentURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Accepted formats: PDF, images, text, video.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Save Certification", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isSaveDisabled)
            }
        }
        .navigationTitle("Add Certification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                attachmentURL = url
                showingDocumentPicker = false
            }
        }
    }

    private func save() {
        let sanitisedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let upload = CertificationUpload(
            id: UUID(),
            title: sanitisedTitle.isEmpty ? "Untitled Certification" : sanitisedTitle,
            issuingAgency: issuingAgency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : issuingAgency.trimmingCharacters(in: .whitespacesAndNewlines),
            issuedOn: includeIssueDate ? issuedOn : nil,
            attachmentURL: attachmentURL
        )
        viewModel.add(upload: upload)
        dismiss()
    }
}

private struct CertificationUpload: Identifiable, Hashable {
    let id: UUID
    var title: String
    var issuingAgency: String?
    var issuedOn: Date?
    var attachmentURL: URL?

    var attachmentName: String? {
        attachmentURL?.lastPathComponent
    }
}

private final class MyCertificationsViewModel: ObservableObject {
    @Published private(set) var certifications: [CertificationUpload]

    init() {
        certifications = Self.sample
    }

    func add(upload: CertificationUpload) {
        certifications.insert(upload, at: 0)
    }

    private static var sample: [CertificationUpload] {
        [
            CertificationUpload(
                id: UUID(),
                title: "POST Firearms Instructor",
                issuingAgency: "State Police Academy",
                issuedOn: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
                attachmentURL: nil
            ),
            CertificationUpload(
                id: UUID(),
                title: "Crisis Intervention (CIT)",
                issuingAgency: "Regional Training Center",
                issuedOn: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
                attachmentURL: nil
            )
        ]
    }
}

private final class OvertimeAuditViewModel: ObservableObject {
    @Published private(set) var filteredRecords: [OvertimeAuditRecord] = []

    private let allRecords: [OvertimeAuditRecord]

    init() {
        self.allRecords = OvertimeAuditViewModel.sampleData
        self.filteredRecords = allRecords
    }

    func runAudit(startDate: Date, endDate: Date, shift: String, officerQuery: String) {
        let normalizedQuery = officerQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filteredRecords = allRecords.filter { record in
            guard record.date >= startDate && record.date <= endDate else { return false }
            if shift != "All", record.shift.caseInsensitiveCompare(shift) != .orderedSame { return false }
            if !normalizedQuery.isEmpty && !record.officer.lowercased().contains(normalizedQuery) { return false }
            return true
        }
    }

    var totalHours: Double {
        filteredRecords.reduce(0) { $0 + $1.hours }
    }

    private static var sampleData: [OvertimeAuditRecord] {
        let calendar = Calendar.current
        let now = Date()
        return [
            OvertimeAuditRecord(
                officer: "Officer Daniels",
                shift: "Day",
                assignment: "Parade detail",
                date: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                hours: 6.5
            ),
            OvertimeAuditRecord(
                officer: "Officer Ruiz",
                shift: "Evening",
                assignment: "Coverage - Squad B",
                date: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
                hours: 4.0
            ),
            OvertimeAuditRecord(
                officer: "Officer Patel",
                shift: "Night",
                assignment: "Late arrest processing",
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                hours: 3.2
            )
        ]
    }
}

private struct OvertimeAuditRecord: Identifiable, Hashable {
    let id = UUID()
    var officer: String
    var shift: String
    var assignment: String
    var date: Date
    var hours: Double
}
