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
import PhotosUI
import UniformTypeIdentifiers

private struct AppTintKey: EnvironmentKey {
    static let defaultValue: Color = Color(.systemBlue)
}

extension EnvironmentValues {
    var appTint: Color {
        get { self[AppTintKey.self] }
        set { self[AppTintKey.self] = newValue }
    }
}

@MainActor
final class NotificationPermissionController: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published var showReminderBanner = false
    private var dismissedReminderThisSession = false
    private var hasPromptedThisSession = false
    private var isRequestingAuthorization = false

    func refreshStatus() async {
        let settings = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { configuredSettings in
                continuation.resume(returning: configuredSettings)
            }
        }
        status = settings.authorizationStatus
        updateBannerVisibility()
        if status == .notDetermined && !hasPromptedThisSession {
            requestAuthorizationPrompt()
        } else if status == .authorized || status == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func requestAuthorizationPrompt() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isRequestingAuthorization = false
                self.hasPromptedThisSession = true
                Task { await self.refreshStatus() }
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    func snoozeReminder() {
        dismissedReminderThisSession = true
        showReminderBanner = false
    }

    private func updateBannerVisibility() {
        switch status {
        case .denied:
            showReminderBanner = !dismissedReminderThisSession
        case .notDetermined:
            showReminderBanner = true
        default:
            showReminderBanner = false
            dismissedReminderThisSession = false
        }
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
    @StateObject private var notificationPermissionController = NotificationPermissionController()
    private let appTint = Color(.systemBlue)

    var body: some View {
        Group {
            if auth.isLoading {
                OrgLoadingView(message: auth.statusMessage)
            } else if let flow = auth.authFlow {
                switch flow {
                case .signedIn:
                    RootTabsView()
                case .newPasswordRequired(let context):
                    NewPasswordChallengeView(context: context)
                case .needsConfirmation(let username):
                    ConfirmationView(username: username)
                case .signedOut:
                    LoginView()
                }
            } else {
                LoginView()
            }
        }
        .tint(appTint)
        .environment(\.appTint, appTint)
        .environmentObject(notificationPermissionController)
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
            Text(message ?? "Loading your DutyWire workspace…")
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
    case tenantSecurity
    case pushDevices
}

struct RootTabsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var notificationPermissionController: NotificationPermissionController
    @State private var selection: AppTab = .dashboard

    var body: some View {
        ZStack(alignment: .top) {
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

            if notificationPermissionController.showReminderBanner {
                NotificationPermissionBanner(
                    status: notificationPermissionController.status,
                    requestPermission: { notificationPermissionController.requestAuthorizationPrompt() },
                    openSettings: { notificationPermissionController.openSettings() },
                    dismiss: { notificationPermissionController.snoozeReminder() }
                )
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
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
        .fullScreenCover(isPresented: Binding(
            get: { requiresMFAGate },
            set: { _ in }
        )) {
            if let message = mfaMessage {
                MFAGateView(
                    message: message,
                    onAcknowledge: handleMFAGateAcknowledge,
                    onSignOut: { Task { await auth.signOut() } }
                )
            }
        }
        .task {
            await notificationPermissionController.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await notificationPermissionController.refreshStatus() }
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

    private var requiresMFAGate: Bool {
        if case .needsUpgrade = auth.mfaCompliance {
            return true
        }
        return false
    }

    private var mfaMessage: String? {
        if case .needsUpgrade(let message) = auth.mfaCompliance {
            return message
        }
        return nil
    }

    private func handleMFAGateAcknowledge() {
        Task { await auth.markMfaVerified() }
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @State private var notificationFlow: NotificationFlowState?
    @State private var notificationAlertMessage: String?

    private let quickActions: [QuickAction] = [
        QuickAction(title: "My Calendar", systemImage: "calendar", destination: .calendar),
        QuickAction(title: "My Log", systemImage: "note.text", destination: .myLog),
        QuickAction(title: "My Squad", systemImage: "person.3.fill", destination: .squad),
        QuickAction(title: "Overtime", systemImage: "clock.fill", destination: .overtime),
        QuickAction(title: "Directed Patrols", systemImage: "scope", destination: .patrols),
        QuickAction(title: "Vehicle Roster", systemImage: "car.fill", destination: .vehicles)
    ]

    private var currentOrgId: String? {
        auth.userProfile.orgID?.nilIfEmpty
    }

    private var currentSenderId: String? {
        if let id = auth.currentUser?.userId, !id.isEmpty { return id }
        if let username = auth.userProfile.preferredUsername, !username.isEmpty { return username }
        if let email = auth.userProfile.email, !email.isEmpty { return email }
        return nil
    }

    private var creatorDisplayName: String? {
        auth.userProfile.displayName ?? auth.userProfile.preferredUsername ?? auth.userProfile.email
    }

    private var currentCreatorId: String? {
        if let id = auth.currentUser?.userId, !id.isEmpty { return id }
        if let username = auth.userProfile.preferredUsername, !username.isEmpty { return username }
        if let email = auth.userProfile.email, !email.isEmpty { return email }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    logoHeader
                    welcomeCard
                    quickActionsGrid
                    notificationLauncher
                    actionItemsCard
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
        .task {
            await LocalNotify.requestAuthOnce()
        }
        .sheet(item: $notificationFlow) { flow in
            switch flow {
            case .picker:
                NotificationTypePickerView(
                    onSelect: handleNotificationSelection,
                    onClose: { notificationFlow = nil }
                )
            case .composer(let template):
                if let orgId = currentOrgId {
                    NotificationComposerView(
                        orgId: orgId,
                        senderId: currentSenderId,
                        senderDisplayName: creatorDisplayName,
                        template: template
                    )
                } else {
                    MissingOrgConfigurationView()
                }
            case .squad:
                SquadNotificationLauncherView(orgId: currentOrgId)
            case .overtime:
                OvertimePostingLauncherView(orgId: currentOrgId, creatorId: currentCreatorId)
            }
        }
        .alert("DutyWire Notifications", isPresented: Binding(
            get: { notificationAlertMessage != nil },
            set: { if !$0 { notificationAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { notificationAlertMessage = nil }
        } message: {
            Text(notificationAlertMessage ?? "")
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
        let rankLine = auth.userProfile.rank?.nilIfEmpty
            ?? auth.primaryRoleDisplayName
            ?? (auth.isAdmin ? "Administrator" : RoleLabels.defaultRole)
        let officerName = auth.userProfile.fullName?.nilIfEmpty
            ?? auth.userProfile.usernameForDisplay
            ?? auth.userProfile.email
            ?? "DutyWire Officer"

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

                        Text(rankLine)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text(officerName)
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

    @ViewBuilder
    private var notificationLauncher: some View {
        if auth.isAdmin || auth.isSupervisor {
            Button(action: composeNotification) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2.weight(.bold))
                    Text("Send New Notification")
                        .font(.headline)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(appTint)
                )
                .shadow(color: appTint.opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send a new notification")
            .accessibilityHint("Opens the DutyWire notifications composer")
        }
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

    private func composeNotification() {
        guard auth.userProfile.orgID?.nilIfEmpty != nil else {
            notificationAlertMessage = "Add your agency's Org ID before sending notifications."
            return
        }
        notificationFlow = .picker
    }

    private func handleNotificationSelection(_ option: NotificationTypeOption) {
        switch option {
        case .general:
            notificationFlow = .composer(.general)
        case .task:
            notificationFlow = .composer(.task)
        case .overtime:
            notificationFlow = .overtime
        case .squad:
            notificationFlow = .squad
        case .other:
            notificationFlow = .composer(.other)
        }
    }
}

private struct NotificationPermissionBanner: View {
    let status: UNAuthorizationStatus
    let requestPermission: () -> Void
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .imageScale(.large)
                    .foregroundStyle(Color.white)
                    .padding(8)
                    .background(Circle().fill(Color.orange))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Turn on DutyWire notifications")
                        .font(.headline)
                    Text(status == .denied ?
                         "Enable notifications in Settings so you don’t miss overtime or squad alerts." :
                         "Stay informed about overtime, squad tasks, and alerts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    if status == .denied {
                        openSettings()
                    } else {
                        requestPermission()
                    }
                } label: {
                    Label(status == .denied ? "Open Settings" : "Allow Notifications", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Maybe Later") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
        )
        .padding(.top, 12)
    }
}

private enum NotificationFlowState: Identifiable {
    case picker
    case composer(NotificationComposerTemplate)
    case squad
    case overtime

    var id: String {
        switch self {
        case .picker:
            return "picker"
        case .composer(let template):
            return "composer-\(template.id.rawValue)"
        case .squad:
            return "squad"
        case .overtime:
            return "overtime"
        }
    }
}

private enum NotificationTypeOption: String, CaseIterable, Identifiable {
    case general
    case task
    case overtime
    case squad
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General Bulletin"
        case .task: return "Task Alert"
        case .overtime: return "Post New Overtime"
        case .squad: return "Message My Squad"
        case .other: return "Other"
        }
    }

    var detail: String {
        switch self {
        case .general:
            return "Share agency-wide updates or reminders."
        case .task:
            return "Assign or follow up on specific tasks."
        case .overtime:
            return "Launch the overtime posting workflow."
        case .squad:
            return "Send a targeted message to selected squad members."
        case .other:
            return "Compose a custom message."
        }
    }
}

private struct NotificationTypePickerView: View {
    let onSelect: (NotificationTypeOption) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image("DUTYWIRE")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                        VStack(spacing: 4) {
                            Text("Select your notification type")
                                .font(.title3.weight(.semibold))
                            Text("Choose how you'd like to reach your team.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 16) {
                        ForEach(NotificationTypeOption.allCases) { option in
                            Button {
                                onSelect(option)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(option.title)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(option.detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Notification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}

private struct SquadNotificationLauncherView: View {
    let orgId: String?
    @StateObject private var viewModel = RosterEntriesViewModel()

    var body: some View {
        NewSquadNotificationView(viewModel: viewModel, orgId: orgId)
    }
}

private struct OvertimePostingLauncherView: View {
    let orgId: String?
    let creatorId: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OvertimeRotationViewModel()
    @State private var formState = RotationPostingFormState()

    var body: some View {
        OvertimePostingFlowView(
            viewModel: viewModel,
            formState: $formState,
            onDismiss: { dismiss() }
        )
        .task {
            await viewModel.load(orgId: orgId, creatorId: creatorId)
        }
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
                            title: "DutyWire Roster",
                            detail: "Review officers and update posts (custom:orgID > roster).",
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

                Section("Security") {
                    NavigationLink(value: AdminPortalDestination.tenantSecurity) {
                        ManagementActionRow(
                            title: "Tenant Security",
                            detail: "View site keys, invites, and audit activity.",
                            systemImage: "lock.shield.fill"
                        )
                    }
                    NavigationLink(value: AdminPortalDestination.pushDevices) {
                        ManagementActionRow(
                            title: "Push Devices",
                            detail: "Track and disable registered phones and tablets.",
                            systemImage: "antenna.radiowaves.left.and.right"
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
                case .tenantSecurity:
                    TenantSecurityCenterView()
                case .pushDevices:
                    AdminPushDevicesView()
                }
            }
        }
    }
}

private struct TenantSecurityCenterView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var auditLogger = AuditLogger.shared
    @State private var showingAuditInfo = false
    @State private var showingMFAGuidance = false
    @StateObject private var rosterViewModel = DepartmentRosterAssignmentsViewModel()

    private var tenant: TenantMetadata? { auth.activeTenant }

    private var recentTenantEvents: [AuditEvent] {
        guard let tenantId = tenant?.orgId.lowercased() else { return [] }
        return auditLogger.events
            .filter { $0.tenantId?.lowercased() == tenantId }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(10)
            .map { $0 }
    }

    private var rosterMFAStatuses: [OfficerAssignmentDTO] {
        rosterViewModel.assignments.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if let tenant {
                if case .needsUpgrade(let message) = auth.mfaCompliance {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.orange)
                            Button("View MFA Guidance") {
                                showingMFAGuidance = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("MFA Compliance")
                    }
                }

                Section("Tenant Overview") {
                    LabeledContent("Organization", value: tenant.displayName)
                    LabeledContent("Org ID", value: tenant.orgId)
                    LabeledContent("Site Key", value: tenant.siteKey)
                    LabeledContent("Status", value: tenant.onboardingStatus.displayName)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verified Domains")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if tenant.verifiedDomains.isEmpty {
                            Text("No domains verified yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(tenant.verifiedDomains, id: \.self) { domain in
                                Text(domain)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground), in: Capsule())
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                Section("Security Policy") {
                    PolicyRow(
                        title: "Phishing-resistant MFA",
                        value: tenant.securityPolicy.requiresPhishingResistantMFA ? "Required" : "Recommended",
                        icon: tenant.securityPolicy.requiresPhishingResistantMFA ? "lock.shield.fill" : "shield.lefthalf.filled",
                        tint: tenant.securityPolicy.requiresPhishingResistantMFA ? .green : .orange
                    )
                    PolicyRow(
                        title: "Invite Expiry",
                        value: "\(tenant.securityPolicy.inviteExpiryHours)h"
                    )
                    PolicyRow(
                        title: "Self-registration",
                        value: tenant.securityPolicy.allowSelfRegistration ? "Allowed (site key required)" : "Disabled",
                        icon: tenant.securityPolicy.allowSelfRegistration ? "person.badge.key.fill" : "nosign",
                        tint: tenant.securityPolicy.allowSelfRegistration ? .blue : .red
                    )
                    PolicyRow(
                        title: "Default Role",
                        value: tenant.securityPolicy.defaultRole
                    )
                }

                Section("Department MFA Status") {
                    if rosterViewModel.isLoading && rosterViewModel.assignments.isEmpty {
                        ProgressView("Loading roster…")
                    } else if rosterMFAStatuses.isEmpty {
                        Text("No roster data yet. Members will appear here once they sign in and DutyWire creates their roster entry automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rosterMFAStatuses) { assignment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(assignment.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    if let email = assignment.profile.departmentEmail {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(assignment.profile.mfaVerified == true ? "Verified" : "Pending")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(assignment.profile.mfaVerified == true ? .green : .orange)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Onboarding & Support") {
                    Text("DutyWire Support provisions all new accounts from your roster submissions. Contact support@dutywire.com for onboarding assistance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                Section("Recent Access Activity") {
                    if recentTenantEvents.isEmpty {
                        Text("No audit events yet. Sign-ins, invite evaluations, and roster changes will appear here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentTenantEvents) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.message)
                                    .font(.subheadline.weight(.semibold))
                                Text(event.timestamp.relativeTimeString())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !event.metadata.isEmpty {
                                    Text(event.metadata.map { "\($0.key): \($0.value)" }.joined(separator: " • "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Button("View Audit Details") {
                            showingAuditInfo = true
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
            } else {
                Section {
                    Text("No tenant metadata is associated with this account yet. Ask DutyWire Support to link your user to a tenant or provide a site key.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tenant Security")
        .sheet(isPresented: $showingMFAGuidance) {
            MFAGuidanceSheet()
                .presentationDetents([.medium, .large])
        }
        .alert("Audit Log", isPresented: $showingAuditInfo) {
            Button("OK", role: .cancel) { showingAuditInfo = false }
        } message: {
            Text("Full audit export will be powered by CloudWatch/Firehose in a future release.")
        }
        .task(id: tenant?.orgId) {
            if let orgId = tenant?.orgId {
                await rosterViewModel.load(orgId: orgId)
            }
        }
    }

    private struct PolicyRow: View {
        var title: String
        var value: String
        var icon: String = "checkmark.shield.fill"
        var tint: Color = .accentColor

        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

}

// MARK: - Admin Push Devices

private struct AdminPushDevicesView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = AdminPushDevicesViewModel()
    @State private var searchText = ""

    private var filteredUsers: [String] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty { return viewModel.sortedUsers }
        return viewModel.sortedUsers.filter { $0.lowercased().contains(text) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Search by user ID", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.75)
                            .padding(.leading, 6)
                    } else {
                        Button {
                            Task { await loadData() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
                if let message = viewModel.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(filteredUsers, id: \.self) { userId in
                Section(userId) {
                    ForEach(viewModel.devices(for: userId)) { endpoint in
                        deviceRow(for: endpoint)
                    }
                }
            }

            if filteredUsers.isEmpty && !viewModel.isLoading {
                Section {
                    Text(searchText.isEmpty ? "No registered devices yet." : "No devices match “\(searchText)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Push Devices")
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private func deviceRow(for endpoint: NotificationEndpointRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(endpoint.deviceName?.nilIfEmpty ?? "Device")
                        .font(.subheadline.weight(.semibold))
                    Text(endpoint.platform == NotificationPlatformKind.android.rawValue ? "Android" : "iOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(
                    endpoint.enabled ?? true ? "Enabled" : "Disabled",
                    isOn: Binding(
                        get: { endpoint.enabled ?? true },
                        set: { newValue in
                            Task {
                                await viewModel.setEnabled(endpoint: endpoint, enabled: newValue)
                            }
                        }
                    )
                )
                .labelsHidden()
            }
            if let arn = endpoint.platformEndpointArn {
                Text(arn)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let lastUsed = viewModel.lastUsedDescription(for: endpoint) {
                Text("Last used \(lastUsed)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadData() async {
        guard auth.isAdmin else { return }
        await viewModel.load(orgId: auth.userProfile.orgID)
    }
}

private final class AdminPushDevicesViewModel: ObservableObject {
    @Published private(set) var grouped: [String: [NotificationEndpointRecord]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    var sortedUsers: [String] {
        grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func devices(for userId: String) -> [NotificationEndpointRecord] {
        grouped[userId]?.sorted { ($0.deviceName ?? "") < ($1.deviceName ?? "") } ?? []
    }

    func load(orgId: String?) async {
        guard let orgId, !orgId.isEmpty else {
            await MainActor.run {
                grouped = [:]
                message = "Missing organization identifier."
            }
            return
        }
        await MainActor.run {
            isLoading = true
            message = nil
        }
        do {
            let endpoints = try await NotificationEndpointService.listEndpointsForOrg(orgId: orgId, limit: 1000)
            let groupedRecords = Dictionary(grouping: endpoints, by: { $0.userId })
            await MainActor.run {
                grouped = groupedRecords
                isLoading = false
            }
        } catch {
            await MainActor.run {
                message = error.userFacingMessage
                grouped = [:]
                isLoading = false
            }
        }
    }

    func setEnabled(endpoint: NotificationEndpointRecord, enabled: Bool) async {
        do {
            try await NotificationEndpointService.setEnabled(endpointId: endpoint.id, enabled: enabled)
            await MainActor.run {
                var current = grouped[endpoint.userId] ?? []
                if let index = current.firstIndex(where: { $0.id == endpoint.id }) {
                    current[index].enabled = enabled
                    grouped[endpoint.userId] = current
                }
            }
        } catch {
            await MainActor.run {
                message = error.userFacingMessage
            }
        }
    }

    func lastUsedDescription(for endpoint: NotificationEndpointRecord) -> String? {
        guard let lastUsed = endpoint.lastUsedAt,
              let date = ISO8601DateFormatter().date(from: lastUsed) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct MFAGuidanceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why passkeys?")
                        .font(.title3.weight(.semibold))
                    Text("Tenant policies require phishing-resistant MFA (passkeys, FIDO2 keys, or PIV/CAC). Passkeys prevent credential theft by binding authentication to your device.")
                        .font(.body)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended Steps")
                            .font(.headline)
                        StepLabel(number: 1, text: "Create a passkey (Settings → Passwords → Passkeys on iOS, or use your hardware key).")
                        StepLabel(number: 2, text: "Enroll the key with DutyWire when prompted during sign-in.")
                        StepLabel(number: 3, text: "Set up an authenticator app (TOTP) only as a backup.")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resources")
                            .font(.headline)
                        Link("Apple Passkey Guide", destination: URL(string: "https://support.apple.com/en-us/HT213305")!)
                        Link("YubiKey for FIDO2", destination: URL(string: "https://www.yubico.com/")!)
                        Link("CISA: Phishing-Resistant MFA", destination: URL(string: "https://www.cisa.gov/resources-tools/resources/phishing-resistant-mfa")!)
                    }
                    Text("Need help? Contact DutyWire support to confirm compliance before onboarding the rest of your agency.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("MFA Guidance")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private struct StepLabel: View {
        let number: Int
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
            }
        }
    }
}

private struct MFAGateView: View {
    let message: String
    let onAcknowledge: () -> Void
    let onSignOut: () -> Void
    @State private var showingGuidance = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text("Secure MFA Required")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                VStack(spacing: 12) {
                    Button {
                        showingGuidance = true
                    } label: {
                        Label("View MFA Guidance", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("I've set up my passkey") {
                        onAcknowledge()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    Button("Sign Out", role: .destructive) {
                        onSignOut()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingGuidance) {
            MFAGuidanceSheet()
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

// MARK: - DutyWire Roster

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
        .navigationTitle("DutyWire Roster")
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
                        departmentEmail: ""
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
                if let vehicle = assignment.vehicleDisplay {
                    Text("Vehicle: \(vehicle)")
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
    var userId: String?
    private let uuid = UUID()

    var id: UUID { uuid }

    init(assignmentId: String?, orgId: String, badgeNumber: String, fullName: String, rank: String, assignmentTitle: String, vehicle: String, specialAssignment: String, departmentPhone: String, departmentExtension: String, departmentEmail: String, userId: String? = nil) {
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
        self.userId = userId
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
        self.userId = dto.profile.userId
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
            squad: nil,
            mfaVerified: nil,
            userId: userId
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
                    TextField("Vehicle / Callsign", text: $draft.vehicle)
                }
                Section("Special Assignment") {
                    TextField("Special Assignment", text: $draft.specialAssignment)
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
                    NavigationLink {
                        InboxMessageDetailView(
                            item: item,
                            markRead: { auth.markNotificationRead(item) },
                            onDelete: {
                                auth.deleteNotification(item)
                            }
                        )
                    } label: {
                        InboxMessageRow(item: item, tint: appTint)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            auth.deleteNotification(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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

private struct InboxMessageRow: View {
    let item: NotificationItem
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.headline)
                Spacer()
                if !item.isRead {
                    Circle()
                        .fill(tint.opacity(0.9))
                        .frame(width: 10, height: 10)
                }
            }
            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(item.sentAt.relativeTimeString())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct InboxMessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: NotificationItem
    let markRead: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteDialog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title2.weight(.semibold))

                Text(item.sentAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding()
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteDialog = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear(perform: markRead)
        .confirmationDialog(
            "Delete this message?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete Message", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) { showingDeleteDialog = false }
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
                NotificationPreferencesSection()
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
        .task {
            await auth.ensureNotificationPreferencesLoaded()
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

// MARK: - Notification Preferences

private struct NotificationPreferencesSection: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var draft = NotificationPreferenceDTO(userId: "")
    @State private var statusMessage: String?
    @State private var didSync = false

    private var isSaveDisabled: Bool {
        auth.isSavingNotificationPreferences || draft == auth.notificationPreferences
    }

    var body: some View {
        Group {
            if auth.isLoadingNotificationPreferences && !didSync {
                Section("Notification Preferences") {
                    ProgressView("Loading preferences…")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                preferencesForm
            }
        }
        .onAppear {
            syncDraftIfNeeded()
        }
        .onChange(of: auth.notificationPreferences) { _, newValue in
            draft = newValue
            didSync = true
            statusMessage = nil
        }
        .onChange(of: draft) { _, _ in
            statusMessage = nil
        }
    }

    @ViewBuilder
    private var preferencesForm: some View {
        Section("Notification Preferences") {
            Text("Choose which alerts you want to receive. These toggles apply to DutyWire push notifications and any alternate contact channels your agency enables.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("General Bulletins", isOn: $draft.generalBulletin)
            Toggle("Task Alerts", isOn: $draft.taskAlert)
            Toggle("New Overtime Posts", isOn: $draft.overtime)
            Toggle("Squad Messages", isOn: $draft.squadMessages)
            Toggle("Other / Custom Notices", isOn: $draft.other)
        }

        Section("Alternate Contact Methods") {
            Text("Add optional contact info so supervisors can escalate urgent alerts via phone or email.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Personal phone", text: Binding(
                get: { draft.contactPhone ?? "" },
                set: { draft.contactPhone = $0 }
            ))
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)

            TextField("Primary email", text: Binding(
                get: { draft.contactEmail ?? "" },
                set: { draft.contactEmail = $0 }
            ))
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)

            TextField("Backup email (optional)", text: Binding(
                get: { draft.backupEmail ?? "" },
                set: { draft.backupEmail = $0 }
            ))
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
        }

        Section {
            Button {
                savePreferences()
            } label: {
                if auth.isSavingNotificationPreferences {
                    ProgressView()
                } else {
                    Label("Save Preferences", systemImage: "checkmark.circle.fill")
                }
            }
            .disabled(isSaveDisabled)

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let backendMessage = auth.notificationPreferencesMessage {
                Text(backendMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func syncDraftIfNeeded() {
        if draft.userId.isEmpty || draft == NotificationPreferenceDTO(userId: draft.userId) {
            draft = auth.notificationPreferences
            didSync = true
        }
    }

    private func savePreferences() {
        statusMessage = nil
        Task {
            let success = await auth.saveNotificationPreferences(draft)
            await MainActor.run {
                statusMessage = success ? "Preferences saved." : nil
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
                        restrictedAccessNotice
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

    private var restrictedAccessNotice: some View {
        VStack(spacing: 6) {
            Text("Access limited to provisioned agencies.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            Text("DutyWire Support onboards agencies from verified rosters. Contact support@dutywire.com if your department needs access.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var isSignInDisabled: Bool {
        siteKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
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
        let decision = OnboardingAccessController.shared.evaluate(
            siteKey: siteKey,
            email: email
        )
        switch decision {
        case .blocked(let reason):
            auth.alertMessage = reason
            return
        case .allowed(let tenant):
            auth.alertMessage = nil
            siteKey = tenant.siteKey
            Task { await auth.signIn(username: email, password: password) }
        }
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
        auth.alertMessage = "Please contact your DutyWire administrator to reset your password."
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

struct ForcedPasswordChangeContext: Equatable {
    let username: String
    let requiredAttributes: [String]
    let existingAttributes: [String: String]
    let message: String?
}

private struct NewPasswordChallengeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var attributeValues: [String: String]
    @FocusState private var focusedField: Field?

    let context: ForcedPasswordChangeContext

    private enum Field: Hashable {
        case newPassword
        case confirmPassword
        case attribute(String)
    }

    init(context: ForcedPasswordChangeContext) {
        self.context = context
        var defaults: [String: String] = [:]
        for key in context.requiredAttributes {
            defaults[key] = context.existingAttributes[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        _attributeValues = State(initialValue: defaults)
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
                        formCard
                        alternateAccountButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 36)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .onSubmit(handleSubmit)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Finish setting up your account")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(context.message ?? "Enter a new password for \(context.username) to continue.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formCard: some View {
        VStack(spacing: 20) {
            passwordFields

            if !context.requiredAttributes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Missing details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(context.requiredAttributes, id: \.self) { attribute in
                        attributeField(for: attribute)
                    }
                }
            }

            Button(action: completeSetup) {
                HStack(spacing: 8) {
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(auth.isLoading ? "Submitting…" : "Complete Setup")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.white)
                .background(appTint.opacity(canSubmit ? 1 : 0.5))
                .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 30, y: 20)
    }

    private var passwordFields: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("New Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Enter a new password", text: $newPassword)
                    .textContentType(.newPassword)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .newPassword)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Re-enter the password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .submitLabel(context.requiredAttributes.isEmpty ? .done : .next)
                    .focused($focusedField, equals: .confirmPassword)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if !passwordsMatch && !confirmPassword.isEmpty {
                Text("Passwords must match.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func attributeField(for key: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(attributeLabel(for: key))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(attributePlaceholder(for: key), text: binding(for: key))
                .keyboardType(attributeKeyboard(for: key))
                .textInputAutocapitalization(attributeAutocapitalization(for: key))
                .autocorrectionDisabled()
                .submitLabel(key == context.requiredAttributes.last ? .done : .next)
                .focused($focusedField, equals: .attribute(key))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var alternateAccountButton: some View {
        Button("Use a different account") {
            auth.authFlow = .signedOut
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(appTint)
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
    }

    private var canSubmit: Bool {
        guard !auth.isLoading else { return false }
        guard newPassword.count >= 8, passwordsMatch else { return false }
        for key in context.requiredAttributes {
            guard let value = attributeValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return false }
        }
        return true
    }

    private var passwordsMatch: Bool {
        confirmPassword.isEmpty || newPassword == confirmPassword
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { attributeValues[key] ?? "" },
            set: { attributeValues[key] = $0 }
        )
    }

    private func attributeLabel(for key: String) -> String {
        switch key {
        case "given_name": return "First Name"
        case "family_name": return "Last Name"
        case "name": return "Full Name"
        case "phone_number": return "Mobile Number"
        case "email": return "Email"
        case "preferred_username": return "Preferred Username"
        default:
            if key.hasPrefix("custom:") {
                let trimmed = key.replacingOccurrences(of: "custom:", with: "")
                return trimmed.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func attributePlaceholder(for key: String) -> String {
        "Enter \(attributeLabel(for: key).lowercased())"
    }

    private func attributeKeyboard(for key: String) -> UIKeyboardType {
        switch key {
        case "email", "preferred_username":
            return .emailAddress
        case "phone_number":
            return .phonePad
        default:
            return .default
        }
    }

    private func attributeAutocapitalization(for key: String) -> TextInputAutocapitalization {
        switch key {
        case "email", "preferred_username", "phone_number":
            return .never
        case "given_name", "family_name", "name":
            return .words
        default:
            return .sentences
        }
    }

    private func handleSubmit() {
        switch focusedField {
        case .newPassword:
            focusedField = .confirmPassword
        case .confirmPassword:
            if let firstAttribute = context.requiredAttributes.first {
                focusedField = .attribute(firstAttribute)
            } else {
                completeSetup()
            }
        case .attribute(let key):
            if let index = context.requiredAttributes.firstIndex(of: key), index + 1 < context.requiredAttributes.count {
                focusedField = .attribute(context.requiredAttributes[index + 1])
            } else {
                completeSetup()
            }
        case .none:
            break
        }
    }

    private func completeSetup() {
        guard canSubmit else { return }
        let sanitizedAttributes = context.requiredAttributes.reduce(into: [String: String]()) { partialResult, key in
            partialResult[key] = attributeValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        Task {
            await auth.completeNewPasswordChallenge(
                username: context.username,
                newPassword: newPassword,
                attributes: sanitizedAttributes
            )
        }
    }
}

// MARK: - Auth Model

enum MfaComplianceState: Equatable {
    case unknown
    case satisfied(policy: TenantSecurityPolicy)
    case needsUpgrade(message: String)
}

@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthFlow {
        case signedOut
        case needsConfirmation(String)
        case newPasswordRequired(ForcedPasswordChangeContext)
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
    @Published var activeTenant: TenantMetadata?
    @Published var mfaCompliance: MfaComplianceState = .unknown
    @Published var isLoading = false
    @Published var alertMessage: String?
    @Published var statusMessage: String? = nil
    @Published private(set) var notificationEndpoints: [NotificationEndpointRecord] = []
    @Published var notificationEndpointMessage: String?
    @Published private(set) var notificationPreferences = NotificationPreferenceDTO(userId: "")
    @Published private(set) var isLoadingNotificationPreferences = false
    @Published private(set) var isSavingNotificationPreferences = false
    @Published var notificationPreferencesMessage: String?
    private var rosterEntryAutoCreationAttempted = false
    private var pushTokenObserver: NSObjectProtocol?
    private var latestPushToken: String?
    private var didLoadNotificationPreferences = false

    init() {
        latestPushToken = UserDefaults.standard.string(forKey: PushNotificationCoordinator.tokenDefaultsKey)
        pushTokenObserver = NotificationCenter.default.addObserver(
            forName: .pushTokenUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                self?.latestPushToken = token
                self?.registerCurrentPushToken()
            }
        }
    }

    deinit {
        if let observer = pushTokenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    var primaryRoleDisplayName: String? {
        guard let primaryRole, !primaryRole.isEmpty else { return nil }
        return RoleLabels.displayName(for: primaryRole)
    }

    var calendarOwnerIdentifiers: [String] {
        var identifiers: [String] = []

        func append(_ value: String?) {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else { return }
            if !identifiers.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                identifiers.append(trimmed)
            }
        }

        append(currentUser?.username)
        append(userProfile.preferredUsername)
        append(userProfile.email)
        append(currentUser?.userId)
        return identifiers
    }

    var primaryCalendarOwnerIdentifier: String? {
        calendarOwnerIdentifiers.first
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
                if let userId = currentUser?.userId {
                    notificationPreferences = NotificationPreferenceDTO.placeholder(userId: userId)
                } else {
                    notificationPreferences = NotificationPreferenceDTO(userId: "")
                }
                didLoadNotificationPreferences = false
                isAuthenticated = true
                authFlow = .signedIn
                updatePrivileges(from: authSession)
                await loadUserAttributes()
                await loadCurrentAssignment()
                await loadSampleData()
                await refreshNotificationEndpoints()
                registerCurrentPushToken()
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
                switch result.nextStep {
                case .confirmSignUp:
                    authFlow = .needsConfirmation(username)
                case .confirmSignInWithNewPassword(let info):
                    authFlow = .newPasswordRequired(
                        Self.passwordChallengeContext(username: username, additionalInfo: info)
                    )
                default:
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

    func completeNewPasswordChallenge(
        username: String,
        newPassword rawPassword: String,
        attributes rawAttributes: [String: String]
    ) async {
        let newPassword = rawPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newPassword.isEmpty else {
            alertMessage = "Enter a new password to continue."
            return
        }

        guard newPassword.count >= 8 else {
            alertMessage = "New password must be at least 8 characters."
            return
        }

        guard !isLoading else { return }
        isLoading = true
        alertMessage = nil
        defer { isLoading = false }

        var normalizedAttributes = Self.trimmedAttributes(rawAttributes)
        if let preferred = Self.computedPreferredUsername(from: normalizedAttributes) {
            normalizedAttributes["preferred_username"] = preferred
            if normalizedAttributes["name"]?.nilIfEmpty == nil {
                normalizedAttributes["name"] = preferred
            }
        }

        let sanitizedAttributes = normalizedAttributes.reduce(into: [AuthUserAttribute]()) { result, entry in
            guard !entry.value.isEmpty else { return }
            let key = Self.attributeKey(for: entry.key)
            result.append(AuthUserAttribute(key, value: entry.value))
        }

        let pluginOptions = sanitizedAttributes.isEmpty
        ? nil
        : AWSAuthConfirmSignInOptions(userAttributes: sanitizedAttributes)
        let options = AuthConfirmSignInRequest.Options(pluginOptions: pluginOptions)

        do {
            let result = try await Amplify.Auth.confirmSignIn(
                challengeResponse: newPassword,
                options: options
            )
            if result.isSignedIn {
                isLoading = false
                await refreshAuthState()
            } else {
                switch result.nextStep {
                case .confirmSignInWithNewPassword(let info):
                    authFlow = .newPasswordRequired(
                        Self.passwordChallengeContext(username: username, additionalInfo: info)
                    )
                    alertMessage = "Please supply the requested details to finish signing in."
                case .confirmSignUp:
                    authFlow = .needsConfirmation(username)
                default:
                    alertMessage = "Sign-in requires additional steps."
                }
            }
        } catch let authError as AuthError {
            presentAuthError(authError)
        } catch {
            alertMessage = error.localizedDescription
            print("Unexpected confirm sign-in error:", error)
        }
    }

    func signOut() async {
        isLoading = true
        let result = await Amplify.Auth.signOut()

        func handleLocalSignOut(sidecarMessage: String? = nil) {
            Task {
                await NotificationEndpointRegistrar.shared.disableAfterSignOut()
            }
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

    func deleteNotification(_ item: NotificationItem) {
        notifications.removeAll { $0.id == item.id }
    }

    /// Temporary sample data to mimic the original Firebase-driven dashboards.
    func loadSampleData() async {
        guard notifications.isEmpty else { return }
        notifications = [
            NotificationItem(
                id: UUID(),
                title: "Amplify Connected",
                body: "Your DutyWire app now uses AWS Amplify instead of Firebase.",
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
            print("[DutyWire] Cognito attributes:", attributes.map { "\($0.key): \($0.value)" })
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
                case .custom(let name) where name.caseInsensitiveCompare("mfaVerified") == .orderedSame:
                    profile.isMfaVerified = attribute.value.lowercased() == "true"
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
            updateActiveTenant(using: profile)
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
            if let assignment = try await ShiftlinkAPI.fetchCurrentAssignment(orgId: orgId, badgeNumber: badgeNumber) {
                currentAssignment = assignment
            } else {
                try await ensureRosterEntryIfNeeded(orgId: orgId, badgeNumber: badgeNumber)
                currentAssignment = try await ShiftlinkAPI.fetchCurrentAssignment(orgId: orgId, badgeNumber: badgeNumber)
            }
        } catch {
            print("Failed to fetch current assignment:", error)
            currentAssignment = nil
        }
    }

    private func ensureRosterEntryIfNeeded(orgId: String, badgeNumber: String) async throws {
        guard !rosterEntryAutoCreationAttempted else { return }
        rosterEntryAutoCreationAttempted = true
        let displayName = userProfile.displayName ?? userProfile.email ?? badgeNumber
        let profile = OfficerAssignmentProfile(
            fullName: displayName,
            rank: userProfile.rank,
            vehicle: nil,
            specialAssignment: "Pending assignment",
            departmentPhone: nil,
            departmentExtension: nil,
            departmentEmail: userProfile.email,
            squad: nil,
            mfaVerified: userProfile.isMfaVerified,
            userId: currentUser?.userId
        )
        let title = userProfile.rank ?? "Officer"
        do {
            _ = try await ShiftlinkAPI.upsertAssignment(
                for: badgeNumber,
                orgId: orgId,
                assignmentTitle: title,
                rank: userProfile.rank,
                vehicle: nil,
                profile: profile
            )
        } catch {
            rosterEntryAutoCreationAttempted = false
            throw error
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

    private func updateActiveTenant(using profile: UserProfileDetails) {
        let tenant = TenantRegistry.shared.resolveTenant(
            siteKey: profile.siteKey,
            orgId: profile.orgID,
            email: profile.email
        )
        activeTenant = tenant
        evaluateMFACompliance(for: tenant)
    }

    private func evaluateMFACompliance(for tenant: TenantMetadata?) {
        guard let tenant else {
            mfaCompliance = .unknown
            return
        }
        if tenant.securityPolicy.requiresPhishingResistantMFA {
            if userProfile.isMfaVerified {
                mfaCompliance = .satisfied(policy: tenant.securityPolicy)
            } else {
                mfaCompliance = .needsUpgrade(
                    message: "\(tenant.displayName) requires phishing-resistant MFA. Register a passkey or hardware key before deployment."
                )
            }
        } else {
            mfaCompliance = .satisfied(policy: tenant.securityPolicy)
        }
    }

    @MainActor
    func markMfaVerified() async {
        guard !userProfile.isMfaVerified else { return }
        do {
            let attribute = AuthUserAttribute(.custom("mfaVerified"), value: "true")
            _ = try await Amplify.Auth.update(userAttributes: [attribute])
            userProfile.isMfaVerified = true
            evaluateMFACompliance(for: activeTenant)
            await updateRosterMfaFlag()
        } catch {
            alertMessage = "Unable to record MFA status. \(error.localizedDescription)"
        }
    }

    private func updateRosterMfaFlag() async {
        guard
            let orgId = userProfile.orgID,
            !orgId.isEmpty,
            let badgeNumber = currentAssignment?.badgeNumber ?? currentUser?.username ?? currentUser?.userId
        else { return }

        var profile = currentAssignment?.profile ?? OfficerAssignmentProfile(
            fullName: userProfile.displayName ?? userProfile.email ?? badgeNumber,
            rank: userProfile.rank,
            vehicle: currentAssignment?.location,
            specialAssignment: currentAssignment?.profile.specialAssignment,
            departmentPhone: currentAssignment?.profile.departmentPhone,
            departmentExtension: currentAssignment?.profile.departmentExtension,
            departmentEmail: currentAssignment?.profile.departmentEmail ?? userProfile.email,
            squad: currentAssignment?.profile.squad,
            mfaVerified: nil,
            userId: currentAssignment?.profile.userId ?? currentUser?.userId
        )
        profile.mfaVerified = true
        do {
            let updated = try await ShiftlinkAPI.upsertAssignment(
                for: badgeNumber,
                orgId: orgId,
                assignmentTitle: currentAssignment?.title ?? (userProfile.rank ?? "Officer"),
                rank: profile.rank ?? userProfile.rank,
                vehicle: currentAssignment?.location ?? profile.vehicle,
                profile: profile
            )
            currentAssignment = updated
        } catch {
            print("Failed to update roster MFA flag:", error)
        }
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
        activeTenant = nil
        mfaCompliance = .unknown
        rosterEntryAutoCreationAttempted = false
        notificationEndpoints = []
        notificationPreferences = NotificationPreferenceDTO(userId: "")
        notificationPreferencesMessage = nil
        didLoadNotificationPreferences = false
    }

    private func registerCurrentPushToken() {
        guard
            let token = latestPushToken,
            isAuthenticated,
            let userId = currentUser?.userId,
            let orgId = userProfile.orgID
        else { return }
        Task {
            await NotificationEndpointRegistrar.shared.registerCurrentDevice(token: token, userId: userId, orgId: orgId)
            await refreshNotificationEndpoints()
        }
    }

    func refreshNotificationEndpoints() async {
        guard let userId = currentUser?.userId else {
            notificationEndpoints = []
            return
        }
        do {
            let endpoints = try await NotificationEndpointService.listEndpointsForUser(userId: userId)
            notificationEndpoints = endpoints
            notificationEndpointMessage = nil
        } catch {
            notificationEndpointMessage = error.localizedDescription
        }
    }

    func setNotificationEndpoint(id: String, enabled: Bool) async {
        do {
            try await NotificationEndpointService.setEnabled(endpointId: id, enabled: enabled)
            if let index = notificationEndpoints.firstIndex(where: { $0.id == id }) {
                notificationEndpoints[index].enabled = enabled
            }
            notificationEndpointMessage = nil
        } catch {
            notificationEndpointMessage = error.localizedDescription
        }
    }

    func ensureNotificationPreferencesLoaded() async {
        guard isAuthenticated else { return }
        guard !didLoadNotificationPreferences else { return }
        await refreshNotificationPreferencesFromServer()
    }

    func refreshNotificationPreferencesFromServer() async {
        guard let userId = currentUser?.userId else {
            notificationPreferences = NotificationPreferenceDTO(userId: "")
            return
        }
        isLoadingNotificationPreferences = true
        defer {
            isLoadingNotificationPreferences = false
            didLoadNotificationPreferences = true
        }

        do {
            if let prefs = try await ShiftlinkAPI.fetchNotificationPreferences(userId: userId) {
                notificationPreferences = prefs
            } else {
                notificationPreferences = NotificationPreferenceDTO.placeholder(userId: userId)
            }
            notificationPreferencesMessage = nil
        } catch {
            notificationPreferencesMessage = error.userFacingMessage
        }
    }

    @discardableResult
    func saveNotificationPreferences(_ prefs: NotificationPreferenceDTO) async -> Bool {
        guard let userId = currentUser?.userId else { return false }
        var payload = prefs
        payload.userId = userId
        isSavingNotificationPreferences = true
        defer { isSavingNotificationPreferences = false }
        do {
            let saved = try await ShiftlinkAPI.upsertNotificationPreferences(payload)
            notificationPreferences = saved
            notificationPreferencesMessage = nil
            didLoadNotificationPreferences = true
            return true
        } catch {
            notificationPreferencesMessage = error.userFacingMessage
            return false
        }
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
        }

        if messageParts.isEmpty {
            messageParts.append("Authentication failed. Please try again.")
        }

        alertMessage = messageParts.joined(separator: "\n\n")
        print("Amplify AuthError:", error)
    }

    private static func passwordChallengeContext(
        username: String,
        additionalInfo: AdditionalInfo?
    ) -> ForcedPasswordChangeContext {
        let requiredAttributes = decodeRequiredAttributes(from: additionalInfo?["requiredAttributes"])
        let existingAttributes = decodeUserAttributes(from: additionalInfo?["userAttributes"])
        let normalizedExisting = existingAttributes.reduce(into: [String: String]()) { result, entry in
            let normalizedKey = normalizeAttributeKey(entry.key)
            guard !normalizedKey.isEmpty else { return }
            result[normalizedKey] = entry.value
        }
        return ForcedPasswordChangeContext(
            username: username,
            requiredAttributes: requiredAttributes,
            existingAttributes: normalizedExisting,
            message: additionalInfo?["message"]
        )
    }

    private static func decodeRequiredAttributes(from rawValue: String?) -> [String] {
        guard
            let rawValue,
            let data = rawValue.data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: data) as? [String]
        else {
            return []
        }

        var ordered: [String] = []
        var seen = Set<String>()

        for entry in array {
            let normalized = normalizeAttributeKey(entry)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            ordered.append(normalized)
        }

        return ordered
    }

    private static func decodeUserAttributes(from rawValue: String?) -> [String: String] {
        guard
            let rawValue,
            let data = rawValue.data(using: .utf8),
            let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        return dictionary.reduce(into: [String: String]()) { result, entry in
            let normalizedKey = normalizeAttributeKey(entry.key)
            guard !normalizedKey.isEmpty else { return }
            switch entry.value {
            case let string as String where !string.isEmpty:
                result[normalizedKey] = string
            case let number as NSNumber:
                result[normalizedKey] = number.stringValue
            default:
                break
            }
        }
    }

    private static func normalizeAttributeKey(_ key: String) -> String {
        var normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("userAttributes.") {
            normalized = String(normalized.dropFirst("userAttributes.".count))
        }
        if normalized.hasPrefix("\""), normalized.hasSuffix("\""), normalized.count >= 2 {
            normalized = String(normalized.dropFirst().dropLast())
        }
        return normalized
    }

    private static func attributeKey(for name: String) -> AuthUserAttributeKey {
        let normalized = normalizeAttributeKey(name)
        switch normalized.lowercased() {
        case "email":
            return .email
        case "phone_number":
            return .phoneNumber
        case "given_name":
            return .givenName
        case "family_name":
            return .familyName
        case "name":
            return .name
        case "preferred_username":
            return .preferredUsername
        case "nickname":
            return .nickname
        case "address":
            return .address
        case "birthdate", "birth_date":
            return .birthDate
        case "gender":
            return .gender
        case "locale":
            return .locale
        case "middle_name":
            return .middleName
        case "picture":
            return .picture
        case "profile":
            return .profile
        case "website":
            return .website
        case "zoneinfo", "zone_info":
            return .zoneInfo
        case "updated_at":
            return .updatedAt
        default:
            if normalized.hasPrefix("custom:") {
                let customKey = String(normalized.dropFirst("custom:".count))
                return .custom(customKey)
            }
            return .unknown(normalized)
        }
    }

    private static func trimmedAttributes(_ attributes: [String: String]) -> [String: String] {
        attributes.reduce(into: [String: String]()) { result, entry in
            guard let normalizedValue = normalizeAttributeValue(entry.value) else { return }
            let normalizedKey = normalizeAttributeKey(entry.key)
            guard !normalizedKey.isEmpty else { return }
            result[normalizedKey] = normalizedValue
        }
    }

    private static func normalizeAttributeValue(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    private static func computedPreferredUsername(from attributes: [String: String]) -> String? {
        if let composed = composedFullName(from: attributes) {
            return composed
        }
        if let nickname = attributes["nickname"]?.nilIfEmpty {
            return nickname
        }
        if let existing = attributes["preferred_username"]?.nilIfEmpty {
            return existing
        }
        if let email = attributes["email"]?.nilIfEmpty {
            let localPart = email.split(separator: "@").first.map(String.init) ?? email
            return normalizeAttributeValue(localPart)
        }
        return nil
    }

    private static func composedFullName(from attributes: [String: String]) -> String? {
        var components: [String] = []
        if let first = attributes["given_name"]?.nilIfEmpty ?? attributes["first_name"]?.nilIfEmpty,
           let normalized = normalizeAttributeValue(first) {
            components.append(normalized)
        }
        if let last = attributes["family_name"]?.nilIfEmpty ?? attributes["last_name"]?.nilIfEmpty,
           let normalized = normalizeAttributeValue(last) {
            components.append(normalized)
        }
        if components.isEmpty,
           let fallback = attributes["name"]?.nilIfEmpty,
           let normalized = normalizeAttributeValue(fallback) {
            components.append(normalized)
        }
        guard !components.isEmpty else { return nil }
        return components.joined(separator: " ")
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
    var isMfaVerified: Bool = false

    var displayName: String? {
        let base = fullName?.nilIfEmpty ??
        preferredUsername?.nilIfEmpty ??
        nickname?.nilIfEmpty ??
        email?.nilIfEmpty

        guard let resolved = base else { return nil }
        if let rank {
            let normalizedRank = rank.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedRank.isEmpty {
                return "\(normalizedRank) \(resolved)"
            }
        }
        return resolved
    }

    var usernameForDisplay: String? {
        preferredUsername?.nilIfEmpty ?? fullName?.nilIfEmpty ?? nickname?.nilIfEmpty ?? email?.nilIfEmpty
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

private struct MissingOrgConfigurationView: View {
    var body: some View {
        PlaceholderPane(
            title: "Org ID Required",
            systemImage: "exclamationmark.triangle.fill",
            message: "DutyWire needs an organization ID on your profile to deliver notifications. Ask an administrator to update your account."
        )
    }
}

// MARK: - Temporary Destination Stubs

private struct SquadRosterView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @StateObject private var rosterViewModel = DepartmentRosterAssignmentsViewModel()
    @StateObject private var rosterEntriesViewModel = RosterEntriesViewModel()
    @State private var actionMessage: String?
    @State private var hasLoaded = false
    @State private var activeSheet: SquadSheet?
    @State private var selectedAssignmentIds: Set<String> = []

    private enum SquadSheet: String, Identifiable {
        case newNotification
        case manageMembers
        case notificationInbox

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

    private var canManageSquad: Bool {
        auth.isAdmin || auth.isSupervisor
    }

    private var supervisorTitle: String {
        let name = auth.userProfile.displayName ??
        auth.userProfile.fullName ??
        auth.currentUser?.username ??
        "DutyWire Member"

        if let rank = auth.userProfile.rank, !rank.isEmpty {
            return "\(rank) \(name)"
        }
        return name
    }

    private var supervisorInitials: String {
        let letters = supervisorTitle.split(separator: " ").compactMap { $0.first }.prefix(2)
        let joined = letters.map { String($0) }.joined()
        return joined.isEmpty ? "DW" : joined.uppercased()
    }

    private var supervisorDetailLine: String {
        var components: [String] = []
        if let unit = auth.userProfile.siteKey, !unit.isEmpty {
            components.append(unit)
        } else if let org = auth.userProfile.orgID, !org.isEmpty {
            components.append("Org \(org)")
        }
        if let role = auth.primaryRoleDisplayName, !role.isEmpty {
            components.append(role)
        } else {
            components.append(auth.isSupervisor ? "Supervisor" : "Officer")
        }
        return components.joined(separator: " • ")
    }

    private var supervisorEmail: String? {
        if let email = auth.userProfile.email, !email.isEmpty { return email }
        if let preferred = auth.userProfile.preferredUsername, preferred.contains("@") { return preferred }
        return nil
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
                NewSquadNotificationView(
                    viewModel: rosterEntriesViewModel,
                    orgId: auth.userProfile.orgID
                )
            case .manageMembers:
                ManageSquadMembersView(
                    orgId: auth.userProfile.orgID
                )
            case .notificationInbox:
                NavigationStack {
                    PlaceholderPane(
                        title: "Squad Notifications",
                        systemImage: "envelope.open",
                        message: "A dedicated inbox for recent squad notifications is coming soon."
                    )
                    .navigationTitle("Squad Notifications")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await rosterViewModel.load(orgId: auth.userProfile.orgID)
            await rosterEntriesViewModel.load(orgId: auth.userProfile.orgID, badgeNumber: nil)
            refreshSquadSelection()
        }
        .onChange(of: activeSheet) { _, newValue in
            if newValue == nil {
                refreshSquadSelection()
            }
        }
        .onAppear {
            refreshSquadSelection()
        }
    }

    private var squadHeaderCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [appTint, appTint.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    Text(supervisorInitials)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(supervisorTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(supervisorDetailLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let email = supervisorEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Text(squadName.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color(.systemBackground).opacity(0.35))
                )

            VStack(spacing: 12) {
                if canManageSquad {
                    Button {
                        activeSheet = .newNotification
                    } label: {
                        Label("+ New Squad Notification", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(SquadActionButtonStyle(variant: .primary, tint: appTint))
                } else {
                    Text("Stay tuned for upcoming squad alerts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    activeSheet = .notificationInbox
                } label: {
                    Label("View Squad Notifications", systemImage: "tray.full.fill")
                }
                .buttonStyle(SquadActionButtonStyle(variant: .secondary, tint: appTint))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            appTint.opacity(0.25),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 12)
    }

    private var squadRosterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SQUAD ROSTER")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if rosterViewModel.isLoading && selectedAssignments.isEmpty {
                ProgressView("Loading assignments…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = rosterViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if selectedAssignments.isEmpty {
                Text("No officers are currently assigned to your squad.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(selectedAssignments.enumerated()), id: \.element.id) { index, assignment in
                        rosterRow(for: assignment)
                            .padding(.vertical, 12)
                        if index < selectedAssignments.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }

            if canManageSquad {
                Button {
                    activeSheet = .manageMembers
                } label: {
                    Label("Manage My Squad", systemImage: "person.3.sequence.fill")
                }
                .buttonStyle(SquadActionButtonStyle(variant: .secondary, tint: appTint))
                .padding(.top, 16)
            }
        }
        .padding(20)
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

    private var selectedAssignments: [OfficerAssignmentDTO] {
        rosterViewModel.assignments.filter { selectedAssignmentIds.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func rosterRow(for assignment: OfficerAssignmentDTO) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(appTint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(assignment.initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(appTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(assignment.assignmentDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let email = assignment.departmentEmail {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

private func refreshSquadSelection() {
        selectedAssignmentIds = SquadSelectionStore.shared.selection(for: auth.userProfile.orgID)
    }
}

private struct SquadActionButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
    }

    var variant: Variant = .primary
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: variant == .primary ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return tint
        case .secondary:
            return Color(.systemBackground)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return tint
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return .clear
        case .secondary:
            return tint.opacity(0.25)
        }
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
            rotationPreviewSection
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
    private var rotationPreviewSection: some View {
        Section {
            NavigationLink {
                OvertimeRotationBoardView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open Rotation Dashboard")
                            .font(.headline)
                        Text("Plan invites with the new overtime policy engine (beta).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.forward.circle.fill")
                        .foregroundStyle(appTint)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Rotation Engine Preview")
        } footer: {
            Text("Beta: keeps the legacy board intact while you test the rotation-based workflow.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
            Text("DutyWire notifies you when new overtime openings are posted.")
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

// MARK: - Rotation Engine Preview

private struct OvertimeRotationBoardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @StateObject private var viewModel = OvertimeRotationViewModel()
    @State private var isPresentingForm = false
    @State private var formState = RotationPostingFormState()

    private var orgId: String? { auth.userProfile.orgID }
    private var creatorId: String? {
        if let id = auth.currentUser?.userId, !id.isEmpty { return id }
        if let username = auth.userProfile.preferredUsername, !username.isEmpty { return username }
        return auth.userProfile.email
    }

    var body: some View {
        List {
            Section {
                Button {
                    formState = RotationPostingFormState()
                    isPresentingForm = true
                } label: {
                    Label("Post New Overtime", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .disabled(orgId == nil || creatorId == nil)
            } footer: {
                Text("Creates a posting with a stored rotation snapshot and invite plan while the legacy board remains available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Scheduled Postings") {
                if viewModel.postings.isEmpty {
                    Text("No rotation-based postings found for your agency.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.postings) { posting in
                        NavigationLink {
                            RotationPostingDetailView(posting: posting, viewModel: viewModel)
                        } label: {
                            rotationPostingRow(posting)
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading rotation postings…")
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .navigationTitle("Rotation (Beta)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await viewModel.load(orgId: orgId, creatorId: creatorId)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $isPresentingForm) {
            OvertimePostingFlowView(
                viewModel: viewModel,
                formState: $formState,
                onDismiss: { isPresentingForm = false }
            )
        }
        .alert(
            "Overtime Rotation",
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
    private func rotationPostingRow(_ posting: RotationOvertimePostingDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(posting.title)
                        .font(.headline)
                    Text(
                        posting.startsAt.formatted(date: .abbreviated, time: .shortened)
                        + " – "
                        + posting.endsAt.formatted(date: .omitted, time: .shortened)
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(posting.state.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appTint.opacity(0.15), in: Capsule())
                    .foregroundStyle(appTint)
            }
            Text("Scenario: \(posting.scenario.displayName) • Slots: \(posting.slots)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct RotationPostingDetailView: View {
    @State private var posting: RotationOvertimePostingDTO
    @ObservedObject var viewModel: OvertimeRotationViewModel
    @Environment(\.appTint) private var appTint
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel
    @State private var isShowingEditSheet = false
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingEscalateSheet = false
    @State private var isShowingForceAssignSheet = false
    @State private var editForm = RotationPostingFormState()
    @State private var escalateSelection: Set<RosterRankCategory> = []
    @State private var forceAssignSearch = ""
    @State private var escalationMessage: String?

    init(posting: RotationOvertimePostingDTO, viewModel: OvertimeRotationViewModel) {
        _posting = State(initialValue: posting)
        self.viewModel = viewModel
    }

    private var invites: [OvertimeInviteDTO] {
        viewModel.invites(for: posting.id)
    }

    private var auditEvents: [OvertimeAuditEventDTO] {
        viewModel.auditTrail(for: posting.id)
    }

    private var nonForceAuditEvents: [OvertimeAuditEventDTO] {
        auditEvents.filter { !$0.isForceAssignment }
    }

    private var forceAssignmentEntries: [ForceAssignmentEntry] {
        auditEvents.compactMap(forceAssignmentEntry(from:))
    }

    var body: some View {
        List {
            if shouldShowEscalationBanner {
                escalationBanner
            }
            detailSections
        }
        .navigationTitle(posting.title)
        .task {
            await viewModel.ensureDetails(for: posting.id)
        }
        .toolbar {
            if auth.isAdmin || auth.isSupervisor {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        editForm = RotationPostingFormState(posting: posting)
                        isShowingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    Menu {
                        Button("Resend Current Ranks") {
                            Task { await resendPosting(with: nil, successMessage: "Invites resent to current ranks.") }
                        }
                        Button("Add Ranks & Resend") {
                            escalateSelection = currentCategorySelection
                            isShowingEscalateSheet = true
                        }
                        Button("Force Assign") {
                            forceAssignSearch = ""
                            isShowingForceAssignSheet = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    Button(role: .destructive) {
                        isShowingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Posting?",
            isPresented: $isShowingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Posting", role: .destructive) {
                Task {
                    await deletePosting()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the overtime posting and all scheduled invites.")
        }
        .sheet(isPresented: $isShowingEditSheet) {
            NavigationStack {
                RotationPostingFormView(
                    viewModel: viewModel,
                    form: $editForm,
                    isSaving: viewModel.isSaving,
                    onCancel: { isShowingEditSheet = false },
                    onSubmit: { state in
                        Task {
                            if let updated = await viewModel.updatePosting(posting: posting, form: state) {
                                posting = updated
                                isShowingEditSheet = false
                            }
                        }
                    },
                    formTitle: "Edit Overtime Posting",
                    submitLabel: "Save"
                )
            }
        }
        .sheet(isPresented: $isShowingEscalateSheet) {
            NavigationStack {
                Form {
                    Section("Recipients") {
                        ForEach(RosterRankCategory.allCases.filter { $0 != .allSworn }) { category in
                            Toggle(isOn: Binding(
                                get: { escalateSelection.contains(category) },
                                set: { newValue in
                                    if newValue {
                                        escalateSelection.insert(category)
                                    } else {
                                        escalateSelection.remove(category)
                                    }
                                }
                            )) {
                                Text(category.displayName)
                            }
                        }
                    }
                }
                .navigationTitle("Escalate Ranks")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingEscalateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Resend") {
                            isShowingEscalateSheet = false
                            Task {
                                await resendPosting(
                                    with: escalateSelection,
                                    successMessage: "Escalated to new ranks and resent invites."
                                )
                            }
                        }
                        .disabled(escalateSelection.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingForceAssignSheet) {
            NavigationStack {
                List(filteredAssignmentsForForceAssign) { assignment in
                    Button {
                        isShowingForceAssignSheet = false
                        Task {
                            let success = await viewModel.forceAssign(posting: posting, officer: assignment)
                            if success {
                                await MainActor.run {
                                    escalationMessage = "Force assignment recorded for \(assignment.displayName)."
                                }
                            }
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(assignment.displayName)
                                .font(.headline)
                            Text(assignment.rankDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Force Assign")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isShowingForceAssignSheet = false }
                    }
                }
                .searchable(text: $forceAssignSearch)
            }
        }
        .onReceive(viewModel.$postings) { updatedPostings in
            if let updated = updatedPostings.first(where: { $0.id == posting.id }) {
                posting = updated
            }
        }
        .alert(
            "Rotation Overtime",
            isPresented: Binding(
                get: { escalationMessage != nil },
                set: { if !$0 { escalationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { escalationMessage = nil }
        } message: {
            Text(escalationMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailSections: some View {
        Section {
            LabeledContent("Title", value: posting.title)
            if let location = posting.location {
                LabeledContent("Location", value: location)
            }
            LabeledContent("Scenario", value: posting.scenario.displayName)
            LabeledContent("Selection Policy", value: posting.selectionPolicy.displayName)
            LabeledContent(
                "Window",
                value: posting.startsAt.formatted(date: .abbreviated, time: .shortened)
                    + " – "
                    + posting.endsAt.formatted(date: .omitted, time: .shortened)
            )
            LabeledContent("Slots", value: "\(posting.slots)")
            LabeledContent("Created By", value: posting.createdBy)
            LabeledContent("Sequence Delay", value: "\(posting.policySnapshot.inviteDelayMinutes) min")
            if let deadline = posting.policySnapshot.responseDeadline {
                LabeledContent(
                    "Response Deadline",
                    value: deadline.formatted(date: .abbreviated, time: .shortened)
                )
            }
        } header: {
            Text("Overview")
        }

        Section {
            ForEach(OvertimeRankBucket.allCases, id: \.self) { bucket in
                if let snapshot = posting.policySnapshot.buckets[bucket] {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bucket.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("Order: \(snapshot.orderedOfficerIds.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let last = snapshot.lastServedOfficerId, !last.isEmpty {
                            Text("Last served: \(last)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Rotation Buckets")
        }

        Section {
            if invites.isEmpty {
                Text("No invites recorded yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(invites) { invite in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(invite.sequence) • \(invite.officerId)")
                                .font(.subheadline.weight(.semibold))
                            Text("\(invite.bucket.displayName) • \(invite.reason.displayLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge(for: invite.status)
                    }
                    .padding(.vertical, 2)
                    if let scheduled = scheduledTime(for: invite) {
                        Text("Opens at \(scheduled.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Invites")
        }

        if let notes = posting.policySnapshot.additionalNotes, !notes.isEmpty {
            Section("Details") {
                Text(notes)
                    .font(.body)
            }
        }

        if !forceAssignmentEntries.isEmpty {
            Section("Force Assignments") {
                ForEach(forceAssignmentEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.officerName)
                            .font(.subheadline.weight(.semibold))
                        if let badge = entry.badgeNumber {
                            Text("#\(badge) \(entry.bucket ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let bucket = entry.bucket {
                            Text(bucket)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let timestamp = entry.timestamp {
                            Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        Section {
            if nonForceAuditEvents.isEmpty {
                Text("No audit events yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nonForceAuditEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.type)
                            .font(.subheadline.weight(.semibold))
                        if let details = event.details, !details.isEmpty {
                            Text(details.prettyPrinted())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let createdAt = event.createdAt {
                            Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Audit Trail")
        }
    }

    private var filteredAssignmentsForForceAssign: [OfficerAssignmentDTO] {
        let assignments = viewModel.rosterAssignments
        guard !forceAssignSearch.isEmpty else { return assignments }
        return assignments.filter { assignment in
            let term = forceAssignSearch.lowercased()
            return assignment.displayName.lowercased().contains(term) ||
                assignment.badgeNumber.lowercased().contains(term)
        }
    }

    private var currentCategorySelection: Set<RosterRankCategory> {
        var selection = RotationPostingFormState(posting: posting).selectedCategories
        if selection.contains(.allSworn) {
            selection = Set(RosterRankCategory.allCases.filter { $0 != .allSworn })
        }
        return selection
    }

    private func resendPosting(with categories: Set<RosterRankCategory>?, successMessage: String? = nil) async {
        let selection = categories ?? RotationPostingFormState(posting: posting).selectedCategories
        if let updated = await viewModel.resendPosting(posting: posting, categories: selection) {
            await viewModel.setEscalationFlag(postingId: posting.id, value: false)
            if let refreshed = viewModel.postings.first(where: { $0.id == posting.id }) {
                posting = refreshed
            } else {
                posting = updated
            }
            if let successMessage {
                await MainActor.run {
                    escalationMessage = successMessage
                }
            }
        }
    }

    private func scheduledTime(for invite: OvertimeInviteDTO) -> Date? {
        if let scheduled = invite.scheduledAt {
            return scheduled
        }
        let delay = posting.policySnapshot.inviteDelayMinutes
        guard delay > 0 else { return nil }
        let base = posting.createdAt ?? posting.startsAt
        let offset = Double(max(invite.sequence - 1, 0) * delay * 60)
        return base.addingTimeInterval(offset)
    }

    private func forceAssignmentEntry(from event: OvertimeAuditEventDTO) -> ForceAssignmentEntry? {
        guard event.isForceAssignment, let details = event.details else { return nil }
        let badge = details.stringValue(forKey: "officerId")
        let name = details.stringValue(forKey: "name") ?? {
            if let badge {
                return "Officer \(badge)"
            }
            return "Force Assigned Officer"
        }()
        let bucket = details.stringValue(forKey: "bucket")?.capitalized
        return ForceAssignmentEntry(
            id: event.id,
            officerName: name,
            badgeNumber: badge,
            bucket: bucket,
            timestamp: event.createdAt
        )
    }

    private struct ForceAssignmentEntry: Identifiable {
        let id: String
        let officerName: String
        let badgeNumber: String?
        let bucket: String?
        let timestamp: Date?
    }

    private var shouldShowEscalationBanner: Bool {
        guard (auth.isAdmin || auth.isSupervisor) else { return false }
        if posting.needsEscalation { return true }
        guard !invites.isEmpty else { return false }
        if invites.contains(where: { $0.status == .accepted }) { return false }
        let latestTime = invites.compactMap { scheduledTime(for: $0) }.max()
        guard let latest = latestTime else { return false }
        return Date() > latest
    }

    @ViewBuilder
    private var escalationBanner: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("No one has accepted this posting yet.")
                .font(.subheadline.weight(.semibold))
            Text("Escalate or force assign to keep the shift covered.")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Button("Resend Current Ranks") {
                    Task { await resendPosting(with: nil, successMessage: "Invites resent to current ranks.") }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("Add Ranks & Resend") {
                    escalateSelection = currentCategorySelection
                    isShowingEscalateSheet = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Force Assign") {
                    forceAssignSearch = ""
                    isShowingForceAssignSheet = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusBadge(for status: OvertimeInviteStatusKind) -> some View {
        Text(status.displayName)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.badgeColor.opacity(0.2), in: Capsule())
            .foregroundStyle(status.badgeColor)
    }

    private func deletePosting() async {
        guard await viewModel.deletePosting(postingId: posting.id) else { return }
        await MainActor.run {
            dismiss()
        }
    }
}

private struct OvertimePostingFlowView: View {
    @ObservedObject var viewModel: OvertimeRotationViewModel
    @Binding var formState: RotationPostingFormState
    let onDismiss: () -> Void

    @State private var path: [OvertimeSelectionPolicyKind] = []

    var body: some View {
        NavigationStack(path: $path) {
            OvertimePolicyPickerView(
                onSelectPolicy: { policy in
                    formState.prepareForPolicy(policy)
                    path = [policy]
                },
                onClose: onDismiss
            )
            .navigationDestination(for: OvertimeSelectionPolicyKind.self) { policy in
                RotationPostingFormView(
                    viewModel: viewModel,
                    form: $formState,
                    isSaving: viewModel.isSaving,
                    onCancel: { path = [] },
                    onSubmit: handleSubmit,
                    formTitle: "New Overtime Posting",
                    submitLabel: "Create"
                )
                .onAppear {
                    formState.prepareForPolicy(policy)
                }
            }
        }
    }

    private func handleSubmit(_ form: RotationPostingFormState) {
        Task {
            await viewModel.createPosting(form: form)
            await MainActor.run {
                if viewModel.errorMessage == nil {
                    formState.resetForNextPosting()
                    path = []
                    onDismiss()
                }
            }
        }
    }
}

private struct OvertimePolicyPickerView: View {
    let onSelectPolicy: (OvertimeSelectionPolicyKind) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Text("Choose the overtime")
                    .font(.title3.weight(.semibold))
                Text("Pick the workflow that matches your agency's policy.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                ForEach(OvertimeSelectionPolicyKind.allCases, id: \.self) { policy in
                    Button {
                        onSelectPolicy(policy)
                    } label: {
                        Text(policy.displayName)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color.blue.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("New Overtime")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: onClose)
            }
        }
    }
}

private struct RotationPostingFormView: View {
    @ObservedObject var viewModel: OvertimeRotationViewModel
    @Binding var form: RotationPostingFormState
    let isSaving: Bool
    let onCancel: () -> Void
    let onSubmit: (RotationPostingFormState) -> Void
    let formTitle: String
    let submitLabel: String
    @State private var isEditingLastServed = false
    @State private var isEditingNotes = false
    @State private var showingAttachmentDocumentPicker = false
    @State private var attachmentPhotoPickerItem: PhotosPickerItem?

    var body: some View {
        Form {
            detailsSection
            attachmentsSection
            recipientsSection
            invitePreviewSection
            lastServedSection
        }
        .navigationTitle(formTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button(submitLabel) {
                        onSubmit(form)
                    }
                    .disabled(!form.isValid)
                }
            }
        }
        .onAppear {
            Task { await viewModel.ensureRosterLoaded() }
            refreshQueues()
            prefillLastServedIfNeeded()
        }
        .onChange(of: viewModel.rosterAssignments.count, initial: false) { _, _ in
            refreshQueues()
        }
        .sheet(isPresented: $showingAttachmentDocumentPicker) {
            DocumentPicker { url in
                if let draft = AttachmentDraftFactory.makeDraft(fromDocumentAt: url),
                   totalAttachmentCount < AttachmentConstraints.maxAttachmentCount {
                    form.attachmentDrafts.append(draft)
                }
                showingAttachmentDocumentPicker = false
            }
        }
        .onChange(of: attachmentPhotoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let draft = await makeAttachmentDraft(from: newItem) {
                    await MainActor.run {
                        if totalAttachmentCount < AttachmentConstraints.maxAttachmentCount {
                            form.attachmentDrafts.append(draft)
                        }
                    }
                }
                await MainActor.run {
                    attachmentPhotoPickerItem = nil
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $form.title)
            TextField("Location", text: $form.location)
            Picker("Reason", selection: $form.scenario) {
                ForEach(OvertimeScenarioKind.creationOptions, id: \.self) { scenario in
                    Text(scenario.displayName).tag(scenario)
                }
            }
            Picker("Selection Method", selection: $form.selectionPolicy) {
                Text("Rotation Queue").tag(OvertimeSelectionPolicyKind.rotation)
                Text("Seniority Based").tag(OvertimeSelectionPolicyKind.seniority)
                Text("First Come / First Served").tag(OvertimeSelectionPolicyKind.firstCome)
            }
            .pickerStyle(.segmented)
            DatePicker("Starts", selection: $form.startsAt)
            DatePicker("Ends", selection: $form.endsAt)
            Stepper(value: $form.slots, in: 1...50) {
                Text("Slots: \(form.slots)")
            }
            if form.selectionPolicy == .rotation {
                Stepper(value: $form.sergeantsOnDuty, in: 0...5) {
                    Text("Sergeants On Duty: \(form.sergeantsOnDuty)")
                }
                Stepper(value: $form.inviteDelayMinutes, in: 1...10) {
                    Text("Delay Between Invites: \(form.inviteDelayMinutes) min")
                }
            }
            if form.selectionPolicy == .seniority || form.selectionPolicy == .firstCome {
                Toggle("Set Response Deadline", isOn: $form.hasResponseDeadline.animation())
                if form.hasResponseDeadline {
                    DatePicker("Response Deadline", selection: $form.responseDeadline, in: Date()...)
                }
            }
            if isEditingNotes || !form.additionalNotes.isEmpty {
                TextEditor(text: $form.additionalNotes)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Button("Done") { isEditingNotes = false }
                    .buttonStyle(.bordered)
            } else {
                Button("+ Add Details") { isEditingNotes = true }
                    .buttonStyle(.bordered)
            }
        }
        .onChange(of: form.selectionPolicy) { _, newValue in
            if newValue == .seniority || newValue == .firstCome {
                form.inviteDelayMinutes = 0
            }
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        Section("Attachments") {
            if form.attachmentReferences.isEmpty && form.attachmentDrafts.isEmpty {
                Text("No attachments added yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if !form.attachmentReferences.isEmpty {
                    ForEach(form.attachmentReferences) { reference in
                        attachmentRow(
                            title: reference.fileName,
                            subtitle: reference.formattedSizeLabel
                        ) {
                            form.attachmentReferences.removeAll { $0.id == reference.id }
                        }
                    }
                }
                if !form.attachmentDrafts.isEmpty {
                    ForEach(form.attachmentDrafts) { draft in
                        attachmentRow(
                            title: draft.fileName,
                            subtitle: draft.formattedSizeLabel
                        ) {
                            form.attachmentDrafts.removeAll { $0.id == draft.id }
                        }
                    }
                }
            }

            Menu {
                PhotosPicker(
                    selection: $attachmentPhotoPickerItem,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                .disabled(!canAddMoreAttachments)

                Button {
                    showingAttachmentDocumentPicker = true
                } label: {
                    Label("Files app", systemImage: "folder")
                }
                .disabled(!canAddMoreAttachments)
            } label: {
                    Label("Add attachment", systemImage: "paperclip.circle.fill")
            }
            .disabled(!canAddMoreAttachments)

            Text(canAddMoreAttachments ? AttachmentConstraints.allowedFormatsDescription : "Maximum of \(AttachmentConstraints.maxAttachmentCount) attachments reached.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recipientsSection: some View {
        Section {
            ForEach(RosterRankCategory.allCases) { category in
                Toggle(isOn: binding(for: category)) {
                    Text(category.displayName)
                }
            }
            recipientsQueueSummary
        } header: {
            Text("Recipients")
        } footer: {
            Text("Queues are generated automatically from the department roster based on the ranks you include.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private var recipientsQueueSummary: some View {
        if viewModel.rosterAssignments.isEmpty {
            Text("Loading roster…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            let preview = viewModel.buildRosterQueues(for: form.selectedCategories)
            LabeledContent("Patrol queue", value: "\(preview.patrol.count) officers")
            LabeledContent("Sergeant queue", value: "\(preview.sergeant.count) officers")
            LabeledContent("Lieutenant queue", value: "\(preview.lieutenant.count) officers")
            LabeledContent("Captain queue", value: "\(preview.captain.count) officers")
        }
    }

    @ViewBuilder
    private var invitePreviewSection: some View {
        Section {
            if let preview = viewModel.invitePreview(for: form, limit: 6), !preview.items.isEmpty {
                ForEach(preview.items) { item in
                    invitePreviewRow(for: item)
                }
                if preview.totalCount > preview.items.count {
                    Text("Showing first \(preview.items.count) of \(preview.totalCount) planned invites.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select at least one rank to preview who will be notified.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Invite Preview")
        } footer: {
            Text("Preview starts from the shift start time and applies the per-invite delay you configure.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private func invitePreviewRow(for item: OvertimeRotationViewModel.InvitePreviewItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(item.sequence) • \(item.displayName)")
                    .font(.subheadline.weight(.semibold))
                Text("\(item.bucket.displayName) • \(item.reason.displayLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.scheduledTime, style: .time)
                    .font(.subheadline.weight(.semibold))
                Text(item.scheduledLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var lastServedSection: some View {
        Section("Last Officer Who Accepted") {
            if isEditingLastServed {
                editableLastServedFields
                Button("Done") {
                    isEditingLastServed = false
                }
                .buttonStyle(.borderedProminent)
            } else {
                readOnlyLastServedRows
                Button("Edit") {
                    isEditingLastServed = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var readOnlyLastServedRows: some View {
        ForEach(rankRows, id: \.title) { row in
            LabeledContent(row.title, value: row.value?.uppercased() ?? "Not set")
        }
    }

    @ViewBuilder
    private var editableLastServedFields: some View {
        TextField("Patrolmen", text: $form.patrolLastServed)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
        TextField("Sergeant", text: $form.sergeantLastServed)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
        TextField("Lieutenant", text: $form.lieutenantLastServed)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
        TextField("Captain", text: $form.captainLastServed)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
    }

    private var totalAttachmentCount: Int {
        form.attachmentReferences.count + form.attachmentDrafts.count
    }

    private var canAddMoreAttachments: Bool {
        totalAttachmentCount < AttachmentConstraints.maxAttachmentCount
    }

    @ViewBuilder
    private func attachmentRow(title: String, subtitle: String?, removeAction: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                removeAction()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var rankRows: [(title: String, value: String?)] {
        [
            ("Patrolmen", form.patrolLastServed.nilIfEmpty),
            ("Sergeant", form.sergeantLastServed.nilIfEmpty),
            ("Lieutenant", form.lieutenantLastServed.nilIfEmpty),
            ("Captain", form.captainLastServed.nilIfEmpty)
        ]
    }

    private func refreshQueues() {
        let queues = viewModel.buildRosterQueues(for: form.selectedCategories)
        var updated = form
        updated.applyRosterQueues(queues)
        form = updated
    }

    private func prefillLastServedIfNeeded() {
        let suggestions = viewModel.suggestedLastServedMap()
        if form.patrolLastServed.isEmpty, let value = suggestions[.patrol] {
            form.patrolLastServed = value
        }
        if form.sergeantLastServed.isEmpty, let value = suggestions[.sergeant] {
            form.sergeantLastServed = value
        }
        if form.lieutenantLastServed.isEmpty, let value = suggestions[.lieutenant] {
            form.lieutenantLastServed = value
        }
        if form.captainLastServed.isEmpty, let value = suggestions[.captain] {
            form.captainLastServed = value
        }
    }

    private func binding(for category: RosterRankCategory) -> Binding<Bool> {
        Binding(
            get: {
                let selections = form.selectedCategories
                if selections.contains(.allSworn) && category != .allSworn {
                    return true
                }
                return selections.contains(category)
            },
            set: { newValue in
                var updated = form.selectedCategories
                if category == .allSworn {
                    updated = newValue ? [.allSworn] : []
                } else {
                    if newValue {
                        updated.remove(.allSworn)
                        updated.insert(category)
                    } else {
                        updated.remove(category)
                    }
                }
                form.selectedCategories = updated
                refreshQueues()
            }
        )
    }
}

@MainActor
private final class OvertimeRotationViewModel: ObservableObject {
    @Published private(set) var postings: [RotationOvertimePostingDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var rosterAssignments: [OfficerAssignmentDTO] = []
    @Published private var invitesCache: [String: [OvertimeInviteDTO]] = [:]
    @Published private var auditCache: [String: [OvertimeAuditEventDTO]] = [:]
    @Published var errorMessage: String?

    private let rotationService = OvertimeRotationService()
    private let seniorityService = OvertimeSeniorityService()
    private let firstComeService = OvertimeFirstComeService()
    private var acceptedLastServed: [OvertimeRankBucket: String] = [:]
    private var escalatedPostingIds: Set<String> = []
    private var orgId: String?
    private var creatorId: String?

    func ensureRosterLoaded() async {
        guard let orgId, rosterAssignments.isEmpty else { return }
        do {
            rosterAssignments = try await ShiftlinkAPI.listAssignments(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func invitePreview(for form: RotationPostingFormState, limit: Int = 6) -> InvitePreviewResult? {
        guard let orgId else { return nil }
        let snapshot = form.makePolicySnapshot(attachments: form.attachmentReferences)
        guard !snapshot.buckets.isEmpty else { return nil }

        do {
            let context = form.makePostingContext(orgId: orgId)
            let plan = try rotationService.planInvites(
                for: context,
                policy: snapshot,
                delayMinutes: form.inviteDelayMinutes
            )
            let items = plan.invitePlan.prefix(limit).map { step in
                InvitePreviewItem(
                    id: step.id,
                    sequence: step.sequence,
                    officerId: step.officerId,
                    displayName: officerDisplayName(for: step.officerId),
                    bucket: step.bucket,
                    reason: step.reason,
                    scheduledTime: form.startsAt.addingTimeInterval(Double(step.delayMinutes) * 60)
                )
            }
            return InvitePreviewResult(items: Array(items), totalCount: plan.invitePlan.count)
        } catch {
            return nil
        }
    }

    struct InvitePreviewResult {
        let items: [InvitePreviewItem]
        let totalCount: Int
    }

    struct InvitePreviewItem: Identifiable {
        let id: UUID
        let sequence: Int
        let officerId: String
        let displayName: String
        let bucket: OvertimeRankBucket
        let reason: RotationInviteStep.Reason
        let scheduledTime: Date

        var scheduledLabel: String {
            scheduledTime.formatted(date: .abbreviated, time: .omitted)
        }
    }

    func load(orgId: String?, creatorId: String?) async {
        self.orgId = orgId
        self.creatorId = creatorId
        await refresh()
    }

    func refresh() async {
        guard let orgId else {
            errorMessage = "Missing organization identifier for rotation overtime."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let postingsRequest = ShiftlinkAPI.listRotationOvertimePostings(orgId: orgId)
            async let rosterRequest = ShiftlinkAPI.listAssignments(orgId: orgId)

            postings = try await postingsRequest
            rosterAssignments = try await rosterRequest
            await refreshAcceptedLastServedFromInvites()
            syncEscalationNotifications(with: postings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createPosting(form: RotationPostingFormState) async {
        guard let orgId, let creatorId else {
            errorMessage = "Missing profile information required to create postings."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let combinedAttachments = try await resolveAttachments(for: form)
            let snapshot = form.makePolicySnapshot(attachments: combinedAttachments)
            guard !snapshot.buckets.isEmpty else {
                errorMessage = "Select at least one recipient queue before creating the posting."
                return
            }
            let context = form.makePostingContext(orgId: orgId)
            let plan: RotationEngineResult
            switch form.selectionPolicy {
            case .rotation:
                plan = try rotationService.planInvites(
                    for: context,
                    policy: snapshot,
                    delayMinutes: form.inviteDelayMinutes
                )
            case .seniority:
                plan = try seniorityService.planInvites(
                    for: context,
                    policy: snapshot,
                    delayMinutes: form.inviteDelayMinutes
                )
            case .firstCome:
                plan = try firstComeService.planInvites(
                    for: context,
                    policy: snapshot
                )
            }

            let input = NewRotationOvertimePostingInput(
                orgId: orgId,
                title: form.title,
                location: form.location.nilIfEmpty,
                scenario: form.scenario,
                startsAt: form.startsAt,
                endsAt: form.endsAt,
                slots: form.slots,
                policySnapshot: snapshot,
                needsEscalation: false,
                selectionPolicy: form.selectionPolicy
            )

            let posting = try await ShiftlinkAPI.createRotationOvertimePosting(createdBy: creatorId, input: input)
            let createdInvites = try await ShiftlinkAPI.createOvertimeInvites(postingId: posting.id, plan: plan.invitePlan)
            let scheduledInvites = try await ShiftlinkAPI.scheduleRotationInvites(
                posting: posting,
                plan: plan.invitePlan,
                invites: createdInvites
            )
            invitesCache[posting.id] = scheduledInvites.isEmpty ? createdInvites : scheduledInvites

            if let fallback = plan.fallback {
                _ = try await ShiftlinkAPI.logOvertimeAuditEvent(
                    postingId: posting.id,
                    type: "FallbackPlan",
                    details: [
                        "bucket": fallback.bucket.rawValue,
                        "officerId": fallback.officerId ?? "none",
                        "explanation": fallback.explanation
                    ],
                    createdBy: creatorId
                )
            }

            postings.insert(posting, at: 0)
            syncEscalationNotifications(with: postings)
            Task {
                await OvertimeNotificationCenter.notifyPostingCreated(posting)
            }
            let summary = posting.startsAt.formatted(date: .abbreviated, time: .shortened)
            sendRemoteNotification(
                for: posting,
                title: "Overtime Posted",
                body: "\(posting.title) starts \(summary)",
                category: "OVERTIME_POSTED"
            )
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func updatePosting(
        posting: RotationOvertimePostingDTO,
        form: RotationPostingFormState,
        replaceExistingInvites: Bool = true,
        bucketFilter: Set<OvertimeRankBucket>? = nil,
        needsEscalationOverride: Bool? = nil
    ) async -> RotationOvertimePostingDTO? {
        isSaving = true
        defer { isSaving = false }

        do {
            let combinedAttachments = try await resolveAttachments(for: form)
            let snapshot = form.makePolicySnapshot(attachments: combinedAttachments)
            guard !snapshot.buckets.isEmpty else {
                errorMessage = "Select at least one recipient queue before saving changes."
                return nil
            }

            let context = form.makePostingContext(orgId: posting.orgId)
            let plan: RotationEngineResult
            switch form.selectionPolicy {
            case .rotation:
                plan = try rotationService.planInvites(
                    for: context,
                    policy: snapshot,
                    delayMinutes: form.inviteDelayMinutes
                )
            case .seniority:
                plan = try seniorityService.planInvites(
                    for: context,
                    policy: snapshot,
                    delayMinutes: form.inviteDelayMinutes
                )
            case .firstCome:
                plan = try firstComeService.planInvites(
                    for: context,
                    policy: snapshot
                )
            }

            let updateInput = NewRotationOvertimePostingInput(
                orgId: posting.orgId,
                title: form.title,
                location: form.location.nilIfEmpty,
                scenario: form.scenario,
                startsAt: form.startsAt,
                endsAt: form.endsAt,
                slots: form.slots,
                policySnapshot: snapshot,
                needsEscalation: needsEscalationOverride ?? posting.needsEscalation,
                selectionPolicy: form.selectionPolicy
            )

            let updatedPosting = try await ShiftlinkAPI.updateRotationOvertimePosting(
                postingId: posting.id,
                input: updateInput
            )

            var planSteps = plan.invitePlan
            if let bucketFilter {
                planSteps = planSteps.filter { bucketFilter.contains($0.bucket) }
            }

            guard !planSteps.isEmpty else {
                if let index = postings.firstIndex(where: { $0.id == updatedPosting.id }) {
                    postings[index] = updatedPosting
                }
                Task { await OvertimeNotificationCenter.scheduleDeadlineReminderIfNeeded(posting: updatedPosting) }
                syncEscalationNotifications(with: postings)
                return updatedPosting
            }

            let existingInvites = try await fetchInvites(postingId: posting.id)
            let offset = replaceExistingInvites ? 0 : (existingInvites.map(\.sequence).max() ?? 0)

            if replaceExistingInvites && !existingInvites.isEmpty {
                try await ShiftlinkAPI.deleteOvertimeInvites(ids: existingInvites.map(\.id))
            }

            let adjustedPlan: [RotationInviteStep]
            if replaceExistingInvites || offset == 0 {
                adjustedPlan = planSteps
            } else {
                adjustedPlan = planSteps.map { $0.withOffset(offset: offset, delayIncrement: plan.delayBetweenInvites) }
            }

            guard !adjustedPlan.isEmpty else {
                if let index = postings.firstIndex(where: { $0.id == updatedPosting.id }) {
                    postings[index] = updatedPosting
                }
                Task { await OvertimeNotificationCenter.scheduleDeadlineReminderIfNeeded(posting: updatedPosting) }
                syncEscalationNotifications(with: postings)
                return updatedPosting
            }

            let createdInvites = try await ShiftlinkAPI.createOvertimeInvites(postingId: posting.id, plan: adjustedPlan)
            let scheduledInvites = try await ShiftlinkAPI.scheduleRotationInvites(
                posting: updatedPosting,
                plan: adjustedPlan,
                invites: createdInvites
            )

            if replaceExistingInvites {
                invitesCache[posting.id] = scheduledInvites.isEmpty ? createdInvites : scheduledInvites
            } else {
                var combined = existingInvites
                combined.append(contentsOf: scheduledInvites.isEmpty ? createdInvites : scheduledInvites)
                combined.sort { $0.sequence < $1.sequence }
                invitesCache[posting.id] = combined
            }

            if let index = postings.firstIndex(where: { $0.id == updatedPosting.id }) {
                postings[index] = updatedPosting
            }
            Task { await OvertimeNotificationCenter.scheduleDeadlineReminderIfNeeded(posting: updatedPosting) }
            syncEscalationNotifications(with: postings)

            return updatedPosting
        } catch {
            errorMessage = error.userFacingMessage
            return nil
        }
    }

    func deletePosting(postingId: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let invites = try await fetchInvites(postingId: postingId)
            if !invites.isEmpty {
                try await ShiftlinkAPI.deleteOvertimeInvites(ids: invites.map(\.id))
            }
            try await ShiftlinkAPI.deleteRotationOvertimePosting(postingId: postingId)
            postings.removeAll { $0.id == postingId }
            invitesCache.removeValue(forKey: postingId)
            auditCache.removeValue(forKey: postingId)
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    private func resolveAttachments(for form: RotationPostingFormState) async throws -> [AttachmentReference] {
        var references = form.attachmentReferences
        if !form.attachmentDrafts.isEmpty {
            let uploaded = try await AttachmentUploader.upload(form.attachmentDrafts)
            references.append(contentsOf: uploaded)
        }
        // Deduplicate by storage key
        var deduped: [String: AttachmentReference] = [:]
        for reference in references {
            deduped[reference.storageKey] = reference
        }
        return Array(deduped.values)
    }

    func resendPosting(posting: RotationOvertimePostingDTO, categories: Set<RosterRankCategory>) async -> RotationOvertimePostingDTO? {
        var form = RotationPostingFormState(posting: posting)
        form.selectedCategories = categories
        let queues = buildRosterQueues(for: categories)
        form.applyRosterQueues(queues)

        let existingBuckets = Set(posting.policySnapshot.buckets.keys)
        let desiredBuckets = categories.expandedBuckets
        let newBuckets = desiredBuckets.subtracting(existingBuckets)
        let filter = newBuckets.isEmpty ? nil : newBuckets

        return await updatePosting(
            posting: posting,
            form: form,
            replaceExistingInvites: false,
            bucketFilter: filter
        )
    }

    func forceAssign(posting: RotationOvertimePostingDTO, officer: OfficerAssignmentDTO) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let bucket = officer.rosterCategory?.buckets.first ?? .patrol
            let nextSequence = (invitesCache[posting.id]?.map(\.sequence).max() ?? 0) + 1
            let invite = try await ShiftlinkAPI.createForceAssignmentInvite(
                postingId: posting.id,
                officerId: officer.badgeNumber,
                bucket: bucket,
                sequence: nextSequence
            )
            invitesCache[posting.id, default: []].append(invite)
            invitesCache[posting.id]?.sort { $0.sequence < $1.sequence }

            _ = try await ShiftlinkAPI.logOvertimeAuditEvent(
                postingId: posting.id,
                type: "ForceAssignment",
                details: [
                    "officerId": officer.badgeNumber,
                    "name": officer.displayName,
                    "bucket": bucket.rawValue
                ],
                createdBy: creatorId
            )

            await setEscalationFlag(postingId: posting.id, value: false)
            Task { await OvertimeNotificationCenter.notifyForceAssignment(posting: posting, officer: officer) }
            sendRemoteNotification(
                for: posting,
                title: "Force Assignment Logged",
                body: "\(officer.displayName) assigned to \(posting.title).",
                category: "OVERTIME_FORCE_ASSIGN"
            )
            return true
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    func setEscalationFlag(postingId: String, value: Bool) async {
        do {
            let updated = try await ShiftlinkAPI.updatePostingEscalationStatus(
                postingId: postingId,
                needsEscalation: value
            )
            if let index = postings.firstIndex(where: { $0.id == postingId }) {
                postings[index] = updated
            }
            if value {
                escalatedPostingIds.insert(postingId)
                Task { await OvertimeNotificationCenter.notifyEscalationNeeded(posting: updated) }
                sendRemoteNotification(
                    for: updated,
                    title: "Escalate Overtime",
                    body: "\(updated.title) still needs coverage.",
                    category: "OVERTIME_ESCALATION"
                )
            } else {
                escalatedPostingIds.remove(postingId)
                OvertimeNotificationCenter.cancelEscalationReminder(postingId: postingId)
                Task { await OvertimeNotificationCenter.scheduleDeadlineReminderIfNeeded(posting: updated) }
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func evaluateEscalationStateIfNeeded(postingId: String, invites: [OvertimeInviteDTO]) async {
        guard let posting = postings.first(where: { $0.id == postingId }) else { return }
        if invites.contains(where: { $0.status == .accepted }) {
            if posting.needsEscalation {
                await setEscalationFlag(postingId: postingId, value: false)
            }
            return
        }
        guard !invites.isEmpty else { return }
        guard let latestTime = invites.compactMap({ scheduledTime(for: $0, posting: posting) }).max() else { return }
        if Date() > latestTime, !posting.needsEscalation {
            await setEscalationFlag(postingId: postingId, value: true)
        }
    }

    func invites(for postingId: String) -> [OvertimeInviteDTO] {
        invitesCache[postingId] ?? []
    }

    func auditTrail(for postingId: String) -> [OvertimeAuditEventDTO] {
        auditCache[postingId] ?? []
    }

    func ensureDetails(for postingId: String) async {
        await loadInvitesIfNeeded(postingId: postingId)
        await loadAuditsIfNeeded(postingId: postingId)
    }

    private func loadInvitesIfNeeded(postingId: String) async {
        guard invitesCache[postingId] == nil else { return }
        do {
            let invites = try await fetchInvites(postingId: postingId)
            await evaluateEscalationStateIfNeeded(postingId: postingId, invites: invites)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadAuditsIfNeeded(postingId: String) async {
        guard auditCache[postingId] == nil else { return }
        do {
            let audits = try await ShiftlinkAPI.listOvertimeAuditEvents(postingId: postingId)
            auditCache[postingId] = audits
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAcceptedLastServedFromInvites() async {
        guard !postings.isEmpty else {
            acceptedLastServed = [:]
            return
        }

        var resolved: [OvertimeRankBucket: String] = [:]
        let orderedPostings = postings.sorted {
            let lhs = $0.createdAt ?? $0.startsAt
            let rhs = $1.createdAt ?? $1.startsAt
            return lhs > rhs
        }

        for posting in orderedPostings.prefix(12) {
            guard resolved.count < OvertimeRankBucket.allCases.count else { break }
            let referenceDate = posting.createdAt ?? posting.startsAt
            do {
                let invites = try await fetchInvites(postingId: posting.id)
                for bucket in OvertimeRankBucket.allCases where resolved[bucket] == nil {
                    guard let acceptedInvite = invites
                        .filter({ $0.bucket == bucket && $0.status == .accepted })
                        .max(by: { inviteTimestamp($0, fallback: referenceDate) < inviteTimestamp($1, fallback: referenceDate) })
                    else { continue }
                    resolved[bucket] = acceptedInvite.officerId
                }
            } catch {
                continue
            }
        }

        acceptedLastServed = resolved
    }

    private func fetchInvites(postingId: String) async throws -> [OvertimeInviteDTO] {
        if let cached = invitesCache[postingId] {
            await evaluateEscalationStateIfNeeded(postingId: postingId, invites: cached)
            return cached
        }
        let invites = try await ShiftlinkAPI.listOvertimeInvites(postingId: postingId)
        invitesCache[postingId] = invites
        await evaluateEscalationStateIfNeeded(postingId: postingId, invites: invites)
        return invites
    }

    private func inviteTimestamp(_ invite: OvertimeInviteDTO, fallback: Date) -> Date {
        invite.respondedAt ?? invite.updatedAt ?? invite.createdAt ?? fallback
    }

    private func scheduledTime(for invite: OvertimeInviteDTO, posting: RotationOvertimePostingDTO) -> Date? {
        if let scheduled = invite.scheduledAt {
            return scheduled
        }
        let delay = posting.policySnapshot.inviteDelayMinutes
        guard delay > 0 else { return nil }
        let base = posting.createdAt ?? posting.startsAt
        let offset = Double(max(invite.sequence - 1, 0) * delay * 60)
        return base.addingTimeInterval(offset)
    }

    private func officerDisplayName(for identifier: String) -> String {
        if let assignment = rosterAssignments.first(where: { $0.badgeNumber.caseInsensitiveCompare(identifier) == .orderedSame }) {
            return assignment.displayName
        }
        if identifier.isEmpty {
            return "Unassigned"
        }
        return "Officer \(identifier)"
    }

    private func sendRemoteNotification(
        for posting: RotationOvertimePostingDTO,
        title: String,
        body: String,
        category: String
    ) {
        var recipients: Set<String> = [posting.createdBy]
        if let creatorId {
            recipients.insert(creatorId)
        }
        guard !recipients.isEmpty else { return }
        let request = OvertimeNotificationRequest(
            orgId: posting.orgId,
            recipients: Array(recipients),
            title: title,
            body: body,
            category: category,
            postingId: posting.id
        )
        Task.detached {
            _ = await ShiftlinkAPI.notifyOvertimeEvent(request: request)
        }
    }

    private func syncEscalationNotifications(with postings: [RotationOvertimePostingDTO]) {
        let nowEscalated = Set(postings.filter { $0.needsEscalation }.map(\.id))
        let newlyEscalated = nowEscalated.subtracting(escalatedPostingIds)
        for id in newlyEscalated {
            guard let posting = postings.first(where: { $0.id == id }) else { continue }
            Task { await OvertimeNotificationCenter.notifyEscalationNeeded(posting: posting) }
        }
        escalatedPostingIds = nowEscalated
    }

    func buildRosterQueues(for selections: Set<RosterRankCategory>) -> RotationRosterQueues {
        let effectiveSelection: Set<RosterRankCategory>
        if selections.contains(.allSworn) {
            effectiveSelection = Set(RosterRankCategory.allCases.filter { $0 != .allSworn })
        } else {
            effectiveSelection = selections
        }

        guard !effectiveSelection.isEmpty else {
            return .empty
        }

        var grouped: [OvertimeRankBucket: [OfficerAssignmentDTO]] = [:]

        for assignment in rosterAssignments {
            guard let category = assignment.rosterCategory else { continue }
            if effectiveSelection.contains(category) {
                for bucket in category.buckets {
                    grouped[bucket, default: []].append(assignment)
                }
            }
        }

        func badges(for bucket: OvertimeRankBucket) -> [String] {
            let list = grouped[bucket] ?? []
            return list
                .sorted { $0.badgeNumber.numericValue < $1.badgeNumber.numericValue }
                .map { $0.badgeNumber }
        }

        return RotationRosterQueues(
            patrol: badges(for: .patrol),
            sergeant: badges(for: .sergeant),
            lieutenant: badges(for: .lieutenant),
            captain: badges(for: .captain)
        )
    }
    
    func suggestedLastServedMap() -> [OvertimeRankBucket: String] {
        var map = acceptedLastServed
        guard let latest = postings.sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }).first else {
            return map
        }
        for (bucket, snapshot) in latest.policySnapshot.buckets where map[bucket] == nil {
            if let last = snapshot.lastServedOfficerId, !last.isEmpty {
                map[bucket] = last
            }
        }
        return map
    }
}

private struct RotationPostingFormState {
    var title: String = ""
    var location: String = ""
    var scenario: OvertimeScenarioKind = .patrolShortShift
    var startsAt: Date = .now
    var endsAt: Date = .now.addingTimeInterval(4 * 3600)
    var slots: Int = 1
    var sergeantsOnDuty: Int = 1
    var inviteDelayMinutes: Int = 2
    var selectedCategories: Set<RosterRankCategory> = []
    var selectionPolicy: OvertimeSelectionPolicyKind = .rotation
    var hasResponseDeadline: Bool = false
    var responseDeadline: Date = Date().addingTimeInterval(2 * 3600)
    var additionalNotes: String = ""
    var attachmentDrafts: [AttachmentDraft] = []
    var attachmentReferences: [AttachmentReference] = []

    var patrolQueue: String = ""
    var patrolLastServed: String = ""
    var sergeantQueue: String = ""
    var sergeantLastServed: String = ""
    var lieutenantQueue: String = ""
    var lieutenantLastServed: String = ""
    var captainQueue: String = ""
    var captainLastServed: String = ""

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        startsAt < endsAt
    }

    mutating func resetForNextPosting() {
        title = ""
        location = ""
        scenario = .patrolShortShift
        startsAt = .now
        endsAt = .now.addingTimeInterval(4 * 3600)
        slots = 1
        sergeantsOnDuty = 1
        inviteDelayMinutes = 2
        selectedCategories = []
        selectionPolicy = .rotation
        hasResponseDeadline = false
        responseDeadline = Date().addingTimeInterval(2 * 3600)
        additionalNotes = ""
        attachmentDrafts = []
        attachmentReferences = []
        patrolQueue = ""
        patrolLastServed = ""
        sergeantQueue = ""
        sergeantLastServed = ""
        lieutenantQueue = ""
        lieutenantLastServed = ""
        captainQueue = ""
        captainLastServed = ""
    }

    mutating func prepareForPolicy(_ policy: OvertimeSelectionPolicyKind) {
        selectionPolicy = policy
        switch policy {
        case .rotation:
            if inviteDelayMinutes == 0 {
                inviteDelayMinutes = 2
            }
            hasResponseDeadline = false
        case .seniority, .firstCome:
            inviteDelayMinutes = 0
        }
    }

    func makePostingContext(orgId: String) -> OvertimePostingContext {
        OvertimePostingContext(
            id: UUID(),
            orgId: orgId,
            start: startsAt,
            end: endsAt,
            title: title,
            location: location.nilIfEmpty,
            slots: slots,
            sergeantsOnDuty: sergeantsOnDuty,
            requiresSupervisor: false
        )
    }

    func makePolicySnapshot(attachments: [AttachmentReference]) -> RotationPolicySnapshot {
        var bucketSnapshots: [OvertimeRankBucket: RotationBucketSnapshot] = [:]
        var fallbackPools: [OvertimeRankBucket: ForcedAssignmentPool] = [:]

        for bucket in OvertimeRankBucket.allCases {
            let queue = queueString(for: bucket)
            let officers = RotationPostingFormState.parseOfficerIds(from: queue)
            guard !officers.isEmpty else { continue }
            let lastServed = lastServedId(for: bucket)
            bucketSnapshots[bucket] = RotationBucketSnapshot(
                bucket: bucket,
                orderedOfficerIds: officers,
                lastServedOfficerId: lastServed.nilIfEmpty
            )
            fallbackPools[bucket] = ForcedAssignmentPool(bucket: bucket, orderedOfficerIds: officers)
        }

        let attachmentSet = attachments.isEmpty ? nil : attachments

        return RotationPolicySnapshot(
            buckets: bucketSnapshots,
            fallbackPools: fallbackPools,
            inviteDelayMinutes: inviteDelayMinutes,
            responseDeadline: hasResponseDeadline ? responseDeadline : nil,
            additionalNotes: additionalNotes.nilIfEmpty,
            attachments: attachmentSet
        )
    }

    private func queueString(for bucket: OvertimeRankBucket) -> String {
        switch bucket {
        case .patrol: return patrolQueue
        case .sergeant: return sergeantQueue
        case .lieutenant: return lieutenantQueue
        case .captain: return captainQueue
        }
    }

    private func lastServedId(for bucket: OvertimeRankBucket) -> String {
        switch bucket {
        case .patrol: return patrolLastServed
        case .sergeant: return sergeantLastServed
        case .lieutenant: return lieutenantLastServed
        case .captain: return captainLastServed
        }
    }

    private static func parseOfficerIds(from string: String) -> [String] {
        string
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    mutating func applyRosterQueues(_ queues: RotationRosterQueues) {
        patrolQueue = queues.patrol.joined(separator: ", ")
        sergeantQueue = queues.sergeant.joined(separator: ", ")
        lieutenantQueue = queues.lieutenant.joined(separator: ", ")
        captainQueue = queues.captain.joined(separator: ", ")
    }
}

private extension RotationPostingFormState {
    init(posting: RotationOvertimePostingDTO) {
        self.title = posting.title
        self.location = posting.location ?? ""
        self.scenario = posting.scenario
        self.startsAt = posting.startsAt
        self.endsAt = posting.endsAt
        self.slots = posting.slots
        self.sergeantsOnDuty = posting.policySnapshot.fallbackPools[.sergeant]?.orderedOfficerIds.count ?? 1
        self.inviteDelayMinutes = posting.policySnapshot.inviteDelayMinutes
        self.selectionPolicy = posting.selectionPolicy
        if let deadline = posting.policySnapshot.responseDeadline {
            self.hasResponseDeadline = true
            self.responseDeadline = deadline
        }
        self.additionalNotes = posting.policySnapshot.additionalNotes ?? ""
        self.attachmentReferences = posting.policySnapshot.attachments ?? []
        self.attachmentDrafts = []

        if let patrolSnapshot = posting.policySnapshot.buckets[.patrol] {
            self.patrolQueue = patrolSnapshot.orderedOfficerIds.joined(separator: ", ")
            self.patrolLastServed = patrolSnapshot.lastServedOfficerId ?? ""
        }
        if let sergeantSnapshot = posting.policySnapshot.buckets[.sergeant] {
            self.sergeantQueue = sergeantSnapshot.orderedOfficerIds.joined(separator: ", ")
            self.sergeantLastServed = sergeantSnapshot.lastServedOfficerId ?? ""
        }
        if let lieutenantSnapshot = posting.policySnapshot.buckets[.lieutenant] {
            self.lieutenantQueue = lieutenantSnapshot.orderedOfficerIds.joined(separator: ", ")
            self.lieutenantLastServed = lieutenantSnapshot.lastServedOfficerId ?? ""
        }
        if let captainSnapshot = posting.policySnapshot.buckets[.captain] {
            self.captainQueue = captainSnapshot.orderedOfficerIds.joined(separator: ", ")
            self.captainLastServed = captainSnapshot.lastServedOfficerId ?? ""
        }

        var selections: Set<RosterRankCategory> = []
        if posting.policySnapshot.buckets[.patrol] != nil { selections.insert(.patrolOfficer) }
        if posting.policySnapshot.buckets[.sergeant] != nil { selections.insert(.sergeant) }
        if posting.policySnapshot.buckets[.lieutenant] != nil { selections.insert(.lieutenant) }
        if posting.policySnapshot.buckets[.captain] != nil { selections.insert(.captain) }
        self.selectedCategories = selections.isEmpty ? [.allSworn] : selections
    }
}

private struct RotationRosterQueues {
    var patrol: [String]
    var sergeant: [String]
    var lieutenant: [String]
    var captain: [String]

    static let empty = RotationRosterQueues(patrol: [], sergeant: [], lieutenant: [], captain: [])
}

private enum RosterRankCategory: String, CaseIterable, Identifiable {
    case patrolOfficer
    case pfc
    case detective
    case sergeant
    case lieutenant
    case captain
    case allSworn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .patrolOfficer: return "Patrolmen"
        case .pfc: return "PFC"
        case .detective: return "Detective"
        case .sergeant: return "Sergeant"
        case .lieutenant: return "Lieutenant"
        case .captain: return "Captain"
        case .allSworn: return "All Sworn"
        }
    }

    var buckets: [OvertimeRankBucket] {
        switch self {
        case .patrolOfficer, .pfc, .detective:
            return [.patrol]
        case .sergeant:
            return [.sergeant]
        case .lieutenant:
            return [.lieutenant]
        case .captain:
            return [.captain]
        case .allSworn:
            return [.patrol, .sergeant, .lieutenant, .captain]
        }
    }
}

private extension OvertimeScenarioKind {
    static var creationOptions: [OvertimeScenarioKind] {
        allCases.filter { $0 != .seniorityBased }
    }

    var displayName: String {
        switch self {
        case .patrolShortShift:
            return "Patrol Short Shift"
        case .sergeantShortShift:
            return "Sergeant Short Shift"
        case .specialEvent:
            return "Special Event"
        case .seniorityBased:
            return "Seniority Based"
        case .other:
            return "Other"
        }
    }
}

private extension OvertimePostingStateKind {
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .filled: return "Filled"
        case .closed: return "Closed"
        }
    }
}

private extension OvertimeRankBucket {
    var displayName: String {
        rawValue.capitalized
    }
}

private extension RotationInviteStep.Reason {
    var displayLabel: String {
        switch self {
        case .rotation: return "Rotation"
        case .escalatedBucket: return "Escalated"
        case .forcedAssignment: return "Forced Assignment"
        }
    }
}

private extension OvertimeSelectionPolicyKind {
    var displayName: String {
        switch self {
        case .rotation: return "Rotation Queue"
        case .seniority: return "Seniority Based"
        case .firstCome: return "First Come / First Served"
        }
    }
}

private extension OfficerAssignmentDTO {
    var rosterCategory: RosterRankCategory? {
        let rawRank = (profile.rank ?? detail ?? title)
        let normalized = rawRank
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .lowercased()
        let tokens = normalized
            .split { !$0.isLetter }
            .map { String($0) }

        func matches(_ keywords: [String]) -> Bool {
            keywords.contains { keyword in
                if keyword.contains(" ") {
                    return normalized.contains(keyword)
                }
                return tokens.contains(keyword)
            }
        }

        let isChief = matches(["chief"]) || normalized.contains("chief of police")
        let isDeputyChief = normalized.contains("deputy chief") || (tokens.contains("deputy") && tokens.contains("chief")) || tokens.contains("dc")
        let isDirector = matches(["director"])

        if isChief || isDeputyChief || isDirector {
            return .captain
        }

        if matches(["captain", "capt", "cpt"]) {
            return .captain
        } else if matches(["lieutenant", "lt", "ltc"]) || normalized.contains("lieut") {
            return .lieutenant
        } else if matches(["sergeant", "sgt", "srg"]) || normalized.contains("serg") {
            return .sergeant
        } else if matches(["detective", "det"]) && !matches(["director"]) {
            return .detective
        } else if matches(["pfc", "privatefirstclass"]) {
            return .pfc
        } else if matches(["ptl", "patrolman", "patrolwoman", "patrol", "officer"]) {
            return .patrolOfficer
        } else {
            return nil
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func prettyPrinted() -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted]),
            let string = String(data: data, encoding: .utf8)
        else { return description }
        return string
    }

    func stringValue(forKey key: String) -> String? {
        guard let raw = self[key] else { return nil }
        if let string = raw as? String {
            return string.nilIfEmpty
        }
        if let number = raw as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var numericValue: Int {
        Int(filter(\.isNumber)) ?? Int.max
    }
}

private extension OvertimeAuditEventDTO {
    var isForceAssignment: Bool {
        type.caseInsensitiveCompare("ForceAssignment") == .orderedSame
    }
}

private extension OvertimeInviteStatusKind {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .ordered: return "Ordered"
        case .expired: return "Expired"
        }
    }

    var badgeColor: Color {
        switch self {
        case .pending: return .gray
        case .accepted: return .green
        case .declined: return .orange
        case .ordered: return .blue
        case .expired: return .red
        }
    }
}

private extension Error {
    var userFacingMessage: String {
        if let localized = (self as? LocalizedError)?.errorDescription {
            return localized
        }
        return localizedDescription
    }
}

private extension RotationInviteStep {
    func withOffset(offset: Int, delayIncrement: Int) -> RotationInviteStep {
        RotationInviteStep(
            id: UUID(),
            officerId: officerId,
            bucket: bucket,
            sequence: sequence + offset,
            reason: reason,
            delayMinutes: delayMinutes + offset * delayIncrement
        )
    }
}

private extension Set where Element == RosterRankCategory {
    var expandedBuckets: Set<OvertimeRankBucket> {
        var result: Set<OvertimeRankBucket> = []
        for category in self {
            for bucket in category.buckets {
                result.insert(bucket)
            }
        }
        return result
    }
}

private struct PatrolAssignmentsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = PatrolAssignmentsViewModel()
    @State private var showingNewPatrol = false
    @State private var selectedFilter: PatrolFilter = .active

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(PatrolFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            patrolSection

            if !viewModel.completedPatrols.isEmpty {
                Section("Recently Completed") {
                    ForEach(viewModel.completedPatrols) { patrol in
                        PatrolAssignmentRow(
                            assignment: patrol,
                            actionTitle: "Reopen",
                            actionIcon: "gobackward",
                            onAction: { viewModel.markActive(patrol) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Directed Patrols")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewPatrol = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add directed patrol")
            }
        }
        .sheet(isPresented: $showingNewPatrol) {
            NewPatrolAssignmentSheet { input in
                viewModel.addPatrol(input: input, createdBy: auth.userProfile.displayName ?? "Supervisor")
            }
        }
    }

    @ViewBuilder
    private var patrolSection: some View {
        let assignments = selectedFilter == .active ? viewModel.activePatrols : viewModel.upcomingPatrols
        if assignments.isEmpty {
            Section {
                Text(selectedFilter.emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 4)
            }
        } else {
            Section(selectedFilter.sectionTitle) {
                ForEach(assignments) { patrol in
                    PatrolAssignmentRow(
                        assignment: patrol,
                        actionTitle: patrol.status == .active ? "Complete" : "Assign",
                        actionIcon: patrol.status == .active ? "checkmark.circle.fill" : "person.crop.circle.fill.badge.plus",
                        onAction: {
                            if patrol.status == .active {
                                viewModel.markCompleted(patrol)
                            } else {
                                viewModel.markActive(patrol)
                            }
                        }
                    )
                }
            }
        }
    }
}

private enum PatrolFilter: String, CaseIterable, Identifiable {
    case active
    case upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Active"
        case .upcoming: return "Upcoming"
        }
    }

    var sectionTitle: String {
        switch self {
        case .active: return "Active Patrols"
        case .upcoming: return "Scheduled Patrols"
        }
    }

    var emptyMessage: String {
        switch self {
        case .active:
            return "No directed patrols are active right now. Supervisors can assign a new patrol using the + button."
        case .upcoming:
            return "No upcoming patrols have been scheduled."
        }
    }
}

private struct PatrolAssignmentRow: View {
    let assignment: DirectedPatrolAssignment
    let actionTitle: String
    let actionIcon: String
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(assignment.title)
                    .font(.headline)
                Spacer()
                Text(assignment.priority.shortLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(assignment.priority.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(assignment.priority.tint)
            }
            Text("\(assignment.location) • \(assignment.scheduleText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !assignment.focusArea.isEmpty {
                Text("Focus: \(assignment.focusArea)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if !assignment.assignedUnits.isEmpty {
                    Label("\(assignment.assignedUnits.count) units", systemImage: "person.3.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAction) {
                    Label(actionTitle, systemImage: actionIcon)
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct NewPatrolAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = NewPatrolAssignmentInput()
    let onSave: (NewPatrolAssignmentInput) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Patrol Title", text: $input.title)
                    TextField("Location / Sector", text: $input.location)
                    Picker("Priority", selection: $input.priority) {
                        ForEach(PatrolPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    Picker("Status", selection: $input.status) {
                        ForEach(PatrolStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }
                Section("Schedule") {
                    DatePicker("Starts", selection: $input.startsAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $input.endsAt, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Focus / Notes") {
                    TextField("Focus area", text: $input.focusArea)
                    TextField("Notes (optional)", text: $input.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Patrol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(input)
                        dismiss()
                    }
                    .disabled(input.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private final class PatrolAssignmentsViewModel: ObservableObject {
    @Published private(set) var assignments: [DirectedPatrolAssignment] = DirectedPatrolAssignment.sample

    var activePatrols: [DirectedPatrolAssignment] {
        assignments.filter { $0.status == .active }
            .sorted { $0.startsAt < $1.startsAt }
    }

    var upcomingPatrols: [DirectedPatrolAssignment] {
        assignments.filter { $0.status == .upcoming }
            .sorted { $0.startsAt < $1.startsAt }
    }

    var completedPatrols: [DirectedPatrolAssignment] {
        assignments.filter { $0.status == .completed }
            .sorted { $0.endsAt > $1.endsAt }
            .prefix(5)
            .map { $0 }
    }

    func addPatrol(input: NewPatrolAssignmentInput, createdBy: String) {
        let newAssignment = DirectedPatrolAssignment(
            id: UUID(),
            title: input.title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: input.location.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: input.priority,
            startsAt: input.startsAt,
            endsAt: input.endsAt,
            focusArea: input.focusArea.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: input.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedUnits: [],
            status: input.status,
            createdBy: createdBy
        )
        assignments.append(newAssignment)
    }

    func markCompleted(_ assignment: DirectedPatrolAssignment) {
        update(assignment, status: .completed)
    }

    func markActive(_ assignment: DirectedPatrolAssignment) {
        update(assignment, status: .active)
    }

    private func update(_ assignment: DirectedPatrolAssignment, status: PatrolStatus) {
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        assignments[index].status = status
    }
}

private struct NewPatrolAssignmentInput {
    var title: String = ""
    var location: String = ""
    var priority: PatrolPriority = .medium
    var startsAt: Date = Date()
    var endsAt: Date = Date().addingTimeInterval(3600)
    var focusArea: String = ""
    var notes: String = ""
    var status: PatrolStatus = .upcoming
}

private enum PatrolStatus: String, CaseIterable, Identifiable, Codable {
    case upcoming
    case active
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}

private enum PatrolPriority: String, CaseIterable, Identifiable, Codable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var shortLabel: String {
        switch self {
        case .high: return "High"
        case .medium: return "Med"
        case .low: return "Low"
        }
    }

    var tint: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

private struct DirectedPatrolAssignment: Identifiable, Codable {
    let id: UUID
    var title: String
    var location: String
    var priority: PatrolPriority
    var startsAt: Date
    var endsAt: Date
    var focusArea: String
    var notes: String
    var assignedUnits: [String]
    var status: PatrolStatus
    var createdBy: String

    var scheduleText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: startsAt)) - \(formatter.string(from: endsAt))"
    }

    static let sample: [DirectedPatrolAssignment] = [
        DirectedPatrolAssignment(
            id: UUID(),
            title: "Sector 4 Saturation",
            location: "Midtown / Sector 4",
            priority: .high,
            startsAt: Date().addingTimeInterval(-3600),
            endsAt: Date().addingTimeInterval(3600),
            focusArea: "Vehicle burglaries near transit hub",
            notes: "On-foot checks every 20 minutes. Coordinate w/ Transit Bureau.",
            assignedUnits: ["Unit 21A", "Unit 14C"],
            status: .active,
            createdBy: "Lt. Carter"
        ),
        DirectedPatrolAssignment(
            id: UUID(),
            title: "Parks Closing Patrol",
            location: "Riverfront parks",
            priority: .medium,
            startsAt: Date().addingTimeInterval(7200),
            endsAt: Date().addingTimeInterval(10800),
            focusArea: "Noise complaints after 2200 hrs",
            notes: "",
            assignedUnits: [],
            status: .upcoming,
            createdBy: "Sgt. Lane"
        ),
        DirectedPatrolAssignment(
            id: UUID(),
            title: "School dismissal post",
            location: "Central High School",
            priority: .low,
            startsAt: Date().addingTimeInterval(-10800),
            endsAt: Date().addingTimeInterval(-3600),
            focusArea: "Traffic calming at intersections",
            notes: "Provide feedback to traffic unit.",
            assignedUnits: ["Unit 7B"],
            status: .completed,
            createdBy: "Lt. Carter"
        )
    ]
}

private struct VehicleRosterView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = VehicleRosterViewModel()
    @State private var showingFilter = false
    @State private var showingAssignmentSheet = false
    @State private var selectedVehicle: VehicleDTO?

    var body: some View {
        List {
            if !viewModel.inServiceVehicles.isEmpty {
                Section("In Service") {
                    ForEach(viewModel.inServiceVehicles) { vehicle in
                        VehicleRosterRow(
                            vehicle: vehicle,
                            actionTitle: "Assign",
                            actionIcon: "person.badge.plus",
                            onAction: { selectedVehicle = vehicle }
                        )
                    }
                }
            }

            if !viewModel.outOfServiceVehicles.isEmpty {
                Section("Out of Service") {
                    ForEach(viewModel.outOfServiceVehicles) { vehicle in
                        VehicleRosterRow(
                            vehicle: vehicle,
                            actionTitle: "Repair log",
                            actionIcon: "wrench.and.screwdriver.fill",
                            onAction: { selectedVehicle = vehicle }
                        )
                    }
                }
            }

            if viewModel.inServiceVehicles.isEmpty && viewModel.outOfServiceVehicles.isEmpty {
                Section {
                    Text("No vehicles have been added yet. Admins can import vehicles through the console or add them manually.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Vehicle Roster")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAssignmentSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add vehicle")
            }
        }
        .sheet(isPresented: $showingAssignmentSheet) {
            NewVehicleSheet { vehicle in
                viewModel.addVehicle(vehicle)
            }
        }
    }
}

private struct VehicleRosterRow: View {
    let vehicle: VehicleDTO
    let actionTitle: String
    let actionIcon: String
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.callsign)
                        .font(.headline)
                    Text(vehicle.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let plate = vehicle.plate {
                    Text(plate)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                }
            }
            HStack {
                Label(vehicle.inService == true ? "In service" : "Out of service", systemImage: vehicle.inService == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(vehicle.inService == true ? Color.green : Color.orange)
                Spacer()
                Button(action: onAction) {
                    Label(actionTitle, systemImage: actionIcon)
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct NewVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var callsign = ""
    @State private var make = ""
    @State private var model = ""
    @State private var plate = ""
    @State private var inService = true
    let onSave: (VehicleDTO) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Info") {
                    TextField("Callsign", text: $callsign)
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    TextField("Plate (optional)", text: $plate)
                    Toggle("In service", isOn: $inService)
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vehicle = VehicleDTO(
                            id: UUID().uuidString,
                            orgId: "demo",
                            callsign: callsign,
                            make: make.isEmpty ? nil : make,
                            model: model.isEmpty ? nil : model,
                            plate: plate.isEmpty ? nil : plate,
                            inService: inService
                        )
                        onSave(vehicle)
                        dismiss()
                    }
                    .disabled(callsign.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private final class VehicleRosterViewModel: ObservableObject {
    @Published private(set) var vehicles: [VehicleDTO] = VehicleDTO.sample

    var inServiceVehicles: [VehicleDTO] {
        vehicles.filter { $0.inService ?? true }
    }

    var outOfServiceVehicles: [VehicleDTO] {
        vehicles.filter { $0.inService == false }
    }

    func addVehicle(_ vehicle: VehicleDTO) {
        vehicles.append(vehicle)
    }
}

private extension VehicleDTO {
    static let sample: [VehicleDTO] = [
        VehicleDTO(id: "v1", orgId: "demo-pd", callsign: "Car 101", make: "Ford", model: "Interceptor", plate: "DPD-101", inService: true),
        VehicleDTO(id: "v2", orgId: "demo-pd", callsign: "SUV 5", make: "Chevy", model: "Tahoe", plate: "DPD-520", inService: false)
    ]
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
    @ObservedObject var viewModel: RosterEntriesViewModel
    let orgId: String?

    @State private var titleText = ""
    @State private var descriptionText = ""
    @State private var includeDateTime = false
    @State private var scheduledDate = Date()
    @State private var recipientScope: RecipientScope = .entireSquad
    @State private var requiresAcknowledgment = true
    @State private var deliveryPriority: DeliveryPriority = .normal
    @State private var attachmentDrafts: [AttachmentDraft] = []
    @State private var selectedRecipientIDs: Set<String> = []
    @State private var showingRecipientPicker = false
    @State private var showingAttachmentDocumentPicker = false
    @State private var attachmentPhotoPickerItem: PhotosPickerItem?

    private var selectedRecipients: [RosterEntryDTO] {
        selectedRecipientIDs.compactMap { viewModel.entry(withId: $0) }
    }

    private var canAddMoreAttachments: Bool {
        attachmentDrafts.count < AttachmentConstraints.maxAttachmentCount
    }

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
                    if attachmentDrafts.isEmpty {
                        Text("No attachments added.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachmentDrafts) { draft in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.fileName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    if let label = draft.formattedSizeLabel {
                                        Text(label)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    attachmentDrafts.removeAll { $0.id == draft.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Menu {
                        PhotosPicker(
                            selection: $attachmentPhotoPickerItem,
                            matching: .any(of: [.images, .videos])
                        ) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        .disabled(!canAddMoreAttachments)

                        Button {
                            showingAttachmentDocumentPicker = true
                        } label: {
                            Label("Files app", systemImage: "folder")
                        }
                        .disabled(!canAddMoreAttachments)
                    } label: {
                        Label("Add attachment", systemImage: "paperclip.circle.fill")
                    }
                    .disabled(!canAddMoreAttachments)

                    Text(canAddMoreAttachments ? AttachmentConstraints.allowedFormatsDescription : "Maximum of \(AttachmentConstraints.maxAttachmentCount) attachments reached.")
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
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                showingRecipientPicker = true
                            } label: {
                                Label("Select Recipients", systemImage: "person.crop.circle.badge.plus")
                            }

                            if selectedRecipients.isEmpty {
                                Text("Choose one or more officers from the department roster. Only recipients you pick will receive this notification.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(selectedRecipients) { recipient in
                                        HStack {
                                            RosterEntrySummaryView(entry: recipient)
                                            Spacer()
                                            Button(role: .destructive) {
                                                selectedRecipientIDs.remove(recipient.id)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                            }
                        }
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
                    .disabled(
                        titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (recipientScope == .selectRecipients && selectedRecipientIDs.isEmpty)
                    )
                }
            }
            .sheet(isPresented: $showingRecipientPicker) {
                RosterMultiPickerView(
                    viewModel: viewModel,
                    title: "Select Recipients",
                    selectedIDs: $selectedRecipientIDs,
                    orgId: orgId
                )
            }
            .sheet(isPresented: $showingAttachmentDocumentPicker) {
                DocumentPicker { url in
                    if let draft = AttachmentDraftFactory.makeDraft(fromDocumentAt: url),
                       attachmentDrafts.count < AttachmentConstraints.maxAttachmentCount {
                        attachmentDrafts.append(draft)
                    }
                    showingAttachmentDocumentPicker = false
                }
            }
            .onChange(of: attachmentPhotoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let draft = await makeAttachmentDraft(from: newItem) {
                        await MainActor.run {
                            if attachmentDrafts.count < AttachmentConstraints.maxAttachmentCount {
                                attachmentDrafts.append(draft)
                            }
                        }
                    }
                    await MainActor.run {
                        attachmentPhotoPickerItem = nil
                    }
                }
            }
            .task {
                await viewModel.ensureRosterLoaded(orgId: orgId)
            }
        }
    }

}

private struct NotificationComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel

    let orgId: String
    let senderId: String?
    let senderDisplayName: String?
    let template: NotificationComposerTemplate

    @StateObject private var recipientsViewModel = NotificationRecipientsViewModel()
    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var additionalDetails = ""
    @State private var selectedCategory: NotificationComposerCategory = .generalBulletin
    @State private var audience: NotificationAudienceScope = .entireOrg
    @State private var selectedRecipientIDs: Set<String> = []
    @State private var recipientSearchText = ""
    @State private var isSending = false
    @State private var alertMessage: String?
    @State private var dismissAfterAlert = false
    @State private var attachmentDrafts: [AttachmentDraft] = []
    @State private var showingAttachmentDocumentPicker = false
    @State private var attachmentPhotoPickerItem: PhotosPickerItem?

    init(
        orgId: String,
        senderId: String?,
        senderDisplayName: String?,
        template: NotificationComposerTemplate
    ) {
        self.orgId = orgId
        self.senderId = senderId
        self.senderDisplayName = senderDisplayName
        self.template = template
        _selectedCategory = State(initialValue: template.id)
        _audience = State(initialValue: template.defaultAudience)
    }

    private var trimmedTitle: String { titleText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedBody: String { bodyText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDetails: String { additionalDetails.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var filteredRecipients: [NotificationRecipientSummary] {
        let query = recipientSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return recipientsViewModel.recipients }
        let term = query.lowercased()
        return recipientsViewModel.recipients.filter { $0.displayName.lowercased().contains(term) }
    }

    private var preparedRecipients: [String] {
        switch audience {
        case .entireOrg:
            return ["*"]
        case .specificMembers:
            return Array(selectedRecipientIDs)
        }
    }

    private var canSend: Bool {
        !trimmedTitle.isEmpty &&
        !trimmedBody.isEmpty &&
        (audience == .entireOrg || !selectedRecipientIDs.isEmpty)
    }

    private var canAddMoreAttachments: Bool {
        attachmentDrafts.count < AttachmentConstraints.maxAttachmentCount
    }

    private func makeBaseMetadata() -> [String: Any] {
        var payload: [String: Any] = [:]
        if let notes = trimmedDetails.nilIfEmpty {
            payload["notes"] = notes
        }
        if let senderId, !senderId.isEmpty {
            payload["senderId"] = senderId
        }
        if let senderDisplayName, !senderDisplayName.isEmpty {
            payload["senderDisplayName"] = senderDisplayName
        }
        let contacts = auth.notificationPreferences.contactMetadata
        if !contacts.isEmpty {
            payload["senderContacts"] = contacts
        }
        return payload
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("MESSAGE") {
                    TextField("Title", text: $titleText)
                        .textInputAutocapitalization(.sentences)
                    TextField("Body", text: $bodyText, axis: .vertical)
                        .lineLimit(4...8)
                        .textInputAutocapitalization(.sentences)
                }

                Section("CATEGORY") {
                    Picker("Type", selection: $selectedCategory) {
                        ForEach(NotificationComposerCategory.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(selectedCategory.helpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("RECIPIENTS") {
                    Picker("Audience", selection: $audience) {
                        ForEach(NotificationAudienceScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch audience {
                    case .entireOrg:
                        Text("All rostered DutyWire members in this organization will receive the alert.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    case .specificMembers:
                        TextField("Search recipients", text: $recipientSearchText)
                            .textInputAutocapitalization(.never)
                        recipientsSelector
                        if !selectedRecipientIDs.isEmpty {
                            Text("\(selectedRecipientIDs.count) recipient(s) selected.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            Task { await recipientsViewModel.load(orgId: orgId) }
                        } label: {
                            Label("Refresh Recipients", systemImage: "arrow.clockwise")
                        }
                        .disabled(recipientsViewModel.isLoading)
                    }
                }

                Section("ADDITIONAL DETAILS") {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(.systemGray4))
                        )
                    Text("Optional context stored with this notification. Recipients do not see this text.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("ATTACHMENTS") {
                    if attachmentDrafts.isEmpty {
                        Text("No attachments added.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachmentDrafts) { draft in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.fileName)
                                        .font(.subheadline)
                                    if let size = draft.fileSize {
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    attachmentDrafts.removeAll { $0.id == draft.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Color.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Menu {
                        PhotosPicker(
                            selection: $attachmentPhotoPickerItem,
                            matching: .any(of: [.images, .videos])
                        ) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        .disabled(!canAddMoreAttachments)

                        Button {
                            showingAttachmentDocumentPicker = true
                        } label: {
                            Label("Files app", systemImage: "folder")
                        }
                        .disabled(!canAddMoreAttachments)
                    } label: {
                        Label("Add attachment", systemImage: "paperclip.circle.fill")
                    }
                    .disabled(!canAddMoreAttachments)

                    Text(canAddMoreAttachments ? AttachmentConstraints.allowedFormatsDescription : "Maximum of \(AttachmentConstraints.maxAttachmentCount) attachments reached.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isSending)
            .overlay {
                if isSending {
                    ProgressView("Sending…")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.15), radius: 8)
                        )
                }
            }
            .navigationTitle(template.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await submitNotification() }
                    }
                    .disabled(isSending || !canSend)
                }
            }
            .task {
                await recipientsViewModel.load(orgId: orgId)
            }
            .onChange(of: recipientsViewModel.recipients.map(\.userId)) { _, newIds in
                let validIds = Set(newIds)
                selectedRecipientIDs = selectedRecipientIDs.intersection(validIds)
            }
            .alert("Notifications", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK") {
                    if dismissAfterAlert {
                        dismiss()
                    }
                    dismissAfterAlert = false
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .sheet(isPresented: $showingAttachmentDocumentPicker) {
                DocumentPicker { url in
                    if let draft = AttachmentDraftFactory.makeDraft(fromDocumentAt: url),
                       attachmentDrafts.count < AttachmentConstraints.maxAttachmentCount {
                        attachmentDrafts.append(draft)
                    }
                    showingAttachmentDocumentPicker = false
                }
            }
            .onChange(of: attachmentPhotoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let draft = await makeAttachmentDraft(from: newItem) {
                        await MainActor.run {
                            if attachmentDrafts.count < AttachmentConstraints.maxAttachmentCount {
                                attachmentDrafts.append(draft)
                            }
                        }
                    }
                    await MainActor.run {
                        attachmentPhotoPickerItem = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recipientsSelector: some View {
        if recipientsViewModel.isLoading {
            ProgressView("Loading recipients…")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let message = recipientsViewModel.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if filteredRecipients.isEmpty {
            Text("No roster members match your search yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(filteredRecipients) { recipient in
                NotificationRecipientRow(
                    recipient: recipient,
                    isSelected: selectedRecipientIDs.contains(recipient.userId)
                )
                .contentShape(Rectangle())
                .onTapGesture { toggleRecipient(recipient.userId) }
            }
        }
    }

    private func toggleRecipient(_ id: String) {
        if selectedRecipientIDs.contains(id) {
            selectedRecipientIDs.remove(id)
        } else {
            selectedRecipientIDs.insert(id)
        }
    }

    @MainActor
    private func submitNotification() async {
        guard canSend else { return }
        isSending = true
        defer { isSending = false }

        do {
            var metadata = makeBaseMetadata()
            if !attachmentDrafts.isEmpty {
                let references = try await AttachmentUploader.upload(attachmentDrafts)
                if !references.isEmpty {
                    metadata["attachments"] = references.map { $0.metadataDictionary }
                }
            }

            let request = NotificationDispatchRequest(
                orgId: orgId,
                recipients: preparedRecipients,
                title: trimmedTitle,
                body: trimmedBody,
                category: selectedCategory.graphQLValue,
                postingId: nil,
                metadata: metadata.isEmpty ? nil : metadata
            )

            let success = await ShiftlinkAPI.sendNotification(request: request)
            if success {
                alertMessage = "Notification sent successfully."
                dismissAfterAlert = true
            } else {
                alertMessage = "We couldn't reach DutyWire services. Try again in a moment."
                dismissAfterAlert = false
            }
        } catch {
            alertMessage = error.userFacingMessage
            dismissAfterAlert = false
        }
    }
}

private struct NotificationRecipientRow: View {
    let recipient: NotificationRecipientSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipient.displayName)
                    .font(.subheadline.weight(.semibold))
                if let detail = recipient.detailLine {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let lastUsed = recipient.lastUsedDescription {
                    Text("Active \(lastUsed)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color(.systemGray4))
                .imageScale(.large)
        }
        .padding(.vertical, 4)
    }
}

private enum NotificationAudienceScope: String, CaseIterable, Identifiable {
    case entireOrg
    case specificMembers

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .entireOrg: return "All Sworn"
        case .specificMembers: return "Select Members"
        }
    }
}

private struct NotificationComposerTemplate {
    let id: NotificationComposerCategory
    let navigationTitle: String
    let defaultAudience: NotificationAudienceScope

    static let general = NotificationComposerTemplate(
        id: .generalBulletin,
        navigationTitle: "Send Notification",
        defaultAudience: .entireOrg
    )

    static let task = NotificationComposerTemplate(
        id: .taskAlert,
        navigationTitle: "Task Alert",
        defaultAudience: .specificMembers
    )

    static let other = NotificationComposerTemplate(
        id: .other,
        navigationTitle: "Send Notification",
        defaultAudience: .entireOrg
    )
}

private enum NotificationComposerCategory: String, CaseIterable, Identifiable {
    case generalBulletin
    case taskAlert
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalBulletin: return "General Bulletin"
        case .taskAlert: return "Task Alert"
        case .other: return "Other"
        }
    }

    var helpText: String {
        switch self {
        case .generalBulletin:
            return "Share agency-wide updates or reminders."
        case .taskAlert:
            return "Quickly notify specific members about an assignment."
        case .other:
            return "Compose a custom message."
        }
    }

    var graphQLValue: String {
        switch self {
        case .generalBulletin, .other:
            return "BULLETIN"
        case .taskAlert:
            return "TASK_ALERT"
        }
    }
}

private struct NotificationRecipientSummary: Identifiable {
    let userId: String
    let displayName: String
    let detailLine: String?
    let lastUsedAt: Date?

    var id: String { userId }

    var lastUsedDescription: String? {
        guard let lastUsedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastUsedAt, relativeTo: Date())
    }
}

@MainActor
private final class NotificationRecipientsViewModel: ObservableObject {
    @Published private(set) var recipients: [NotificationRecipientSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(orgId: String) async {
        guard !orgId.isEmpty else {
            recipients = []
            errorMessage = "Missing organization identifier."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let endpointsTask = NotificationEndpointService.listEndpointsForOrg(orgId: orgId, limit: 1000)
            async let rosterTask = ShiftlinkAPI.listAssignments(orgId: orgId)
            let (endpoints, roster) = try await (endpointsTask, rosterTask)
            let rosterIndex = Dictionary(uniqueKeysWithValues: roster.compactMap { assignment -> (String, OfficerAssignmentDTO)? in
                guard let userId = assignment.profile.userId?.nilIfEmpty else { return nil }
                return (userId, assignment)
            })
            recipients = Self.makeSummaries(from: endpoints, roster: rosterIndex)
        } catch {
            errorMessage = error.localizedDescription
            recipients = []
        }
    }

    private static func makeSummaries(
        from endpoints: [NotificationEndpointRecord],
        roster: [String: OfficerAssignmentDTO]
    ) -> [NotificationRecipientSummary] {
        let grouped = Dictionary(grouping: endpoints, by: { $0.userId })
        let summaries = grouped.map { userId, records -> NotificationRecipientSummary in
            let lastUsed = records.compactMap { parse(dateString: $0.lastUsedAt) }.max()
            let assignment = roster[userId]
            let displayName = assignment?.displayName ?? assignment?.profile.fullName ?? "User \(userId.prefix(8))…"
            let detail = assignment?.rankDisplay ?? assignment?.assignmentDisplay
            return NotificationRecipientSummary(
                userId: userId,
                displayName: displayName,
                detailLine: detail,
                lastUsedAt: lastUsed
            )
        }
        return summaries.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func parse(dateString: String?) -> Date? {
        guard let value = dateString else { return nil }
        return isoFormatter.date(from: value) ?? fallbackFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
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

@available(iOS 15.0, *)
private struct ManageSquadMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rosterViewModel = DepartmentRosterAssignmentsViewModel()
    let orgId: String?
    private let selectionStore = SquadSelectionStore.shared

    @State private var searchText = ""
    @State private var selectedAssignmentIds: Set<String> = []

    private var filteredAssignments: [OfficerAssignmentDTO] {
        let assignments = rosterViewModel.assignments
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return assignments
        }
        return assignments.filter { assignmentMatchesSearch($0, query: searchText) }
    }

    private var currentSquad: [OfficerAssignmentDTO] {
        rosterViewModel.assignments.filter { selectedAssignmentIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Current Squad") {
                    if currentSquad.isEmpty {
                        Text("No officers selected yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(currentSquad) { assignment in
                            SquadMemberCard(assignment: assignment) {
                                selectedAssignmentIds.remove(assignment.id)
                            }
                        }
                    }
                }

                Section("DutyWire Roster") {
                    if rosterViewModel.isLoading && rosterViewModel.assignments.isEmpty {
                        ProgressView("Loading roster…")
                    } else if let message = rosterViewModel.errorMessage, !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if filteredAssignments.isEmpty {
                        Text("No matches. Try a different search term.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredAssignments) { assignment in
                            DepartmentRosterSelectableRow(
                                assignment: assignment,
                                isSelected: selectedAssignmentIds.contains(assignment.id),
                                onToggle: { toggleSelection(for: assignment) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Manage Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectionStore.save(selection: selectedAssignmentIds, orgId: orgId)
                        dismiss()
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .task {
                await rosterViewModel.load(orgId: orgId)
                selectedAssignmentIds = selectionStore.selection(for: orgId)
            }
        }
    }

    private func toggleSelection(for assignment: OfficerAssignmentDTO) {
        if selectedAssignmentIds.contains(assignment.id) {
            selectedAssignmentIds.remove(assignment.id)
        } else {
            selectedAssignmentIds.insert(assignment.id)
        }
    }
}

private final class SquadSelectionStore {
    static let shared = SquadSelectionStore()
    private let defaults = UserDefaults.standard
    private let prefix = "shiftlink.squadSelection"

    func selection(for orgId: String?) -> Set<String> {
        guard let orgId, !orgId.isEmpty else { return [] }
        if let array = defaults.array(forKey: key(for: orgId)) as? [String] {
            return Set(array)
        }
        return []
    }

    func save(selection: Set<String>, orgId: String?) {
        guard let orgId, !orgId.isEmpty else { return }
        defaults.set(Array(selection), forKey: key(for: orgId))
    }

    private func key(for orgId: String) -> String {
        "\(prefix).\(orgId.lowercased())"
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

    func ensureRosterLoaded(orgId: String?) async {
        guard entries.isEmpty else { return }
        await load(orgId: orgId, badgeNumber: nil)
    }

    func entry(withId id: String) -> RosterEntryDTO? {
        entries.first { $0.id == id }
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

private struct RosterEntrySummaryView: View {
    let entry: RosterEntryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.shiftLabel)
                .font(.subheadline.weight(.semibold))
            Text("Badge / Computer #: \(entry.badgeNumber)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(entry.durationDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 15.0, *)
private struct RosterSinglePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RosterEntriesViewModel
    let title: String
    let onSelect: (RosterEntryDTO) -> Void
    var orgId: String?
    @State private var searchText = ""

    private var filteredEntries: [RosterEntryDTO] {
        viewModel.entries.filter { entryMatchesSearch($0, query: searchText) }
    }

    var body: some View {
        NavigationStack {
            rosterList
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading roster…")
                } else if let message = viewModel.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if viewModel.entries.isEmpty {
                    Text("No roster entries have been added for this department yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if filteredEntries.isEmpty {
                    Text("No matches. Try another badge number or shift name.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .searchable(text: $searchText, placement: .automatic)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.ensureRosterLoaded(orgId: orgId)
            }
        }
    }

    private var rosterList: some View {
        List(filteredEntries, id: \.id) { entry in
            HStack(alignment: .top, spacing: 12) {
                RosterEntrySummaryView(entry: entry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Add") {
                    onSelect(entry)
                    dismiss()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
        }
    }
}

@available(iOS 15.0, *)
private struct RosterMultiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RosterEntriesViewModel
    let title: String
    @Binding var selectedIDs: Set<String>
    var orgId: String?
    @State private var searchText = ""

    private var filteredEntries: [RosterEntryDTO] {
        viewModel.entries.filter { entryMatchesSearch($0, query: searchText) }
    }

    var body: some View {
        NavigationStack {
            rosterList
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading roster…")
                } else if let message = viewModel.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if viewModel.entries.isEmpty {
                    Text("No roster entries have been added for this department yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if filteredEntries.isEmpty {
                    Text("No matches. Try another badge number or shift name.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .searchable(text: $searchText, placement: .automatic)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.ensureRosterLoaded(orgId: orgId)
            }
        }
    }

    private var rosterList: some View {
        List(filteredEntries, id: \.id) { entry in
            let isSelected = selectedIDs.contains(entry.id)
            HStack(alignment: .top, spacing: 12) {
                RosterEntrySummaryView(entry: entry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(isSelected ? "Remove" : "Add") {
                    toggleSelection(for: entry)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.primary : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color(.systemGray5) : Color.accentColor)
                )
            }
        }
    }

    private func toggleSelection(for entry: RosterEntryDTO) {
        if selectedIDs.contains(entry.id) {
            selectedIDs.remove(entry.id)
        } else {
            selectedIDs.insert(entry.id)
        }
    }
}

@available(iOS 15.0, *)
private struct DepartmentRosterSelectableRow: View {
    let assignment: OfficerAssignmentDTO
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rosterAvatar
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.displayName)
                    .font(.headline)
                Text(assignment.assignmentDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("#\(assignment.badgeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let special = assignment.specialAssignment {
                    Text(special)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onToggle) {
                Text(isSelected ? "Added" : "Add")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(.systemGray5) : Color.accentColor)
                    )
                    .foregroundStyle(isSelected ? Color.primary : Color.white)
            }
            .disabled(isSelected)
        }
        .padding(.vertical, 6)
    }

    private var rosterAvatar: some View {
        Circle()
            .fill(Color(.secondarySystemBackground))
            .frame(width: 42, height: 42)
            .overlay(
                Text(assignment.initials)
                    .font(.headline)
                    .foregroundStyle(.primary)
            )
    }
}

@available(iOS 15.0, *)
private struct SquadMemberCard: View {
    let assignment: OfficerAssignmentDTO
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            memberAvatar
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.displayName)
                    .font(.headline)
                Text(assignment.assignmentDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("#\(assignment.badgeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let phone = assignment.departmentPhone {
                    Text("Desk: \(phone)\(assignment.departmentExtension.map { " ext. \($0)" } ?? "")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    private var memberAvatar: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .frame(width: 42, height: 42)
            .overlay(
                Text(assignment.initials)
                    .font(.headline)
                    .foregroundStyle(.primary)
            )
    }
}

private func entryMatchesSearch(_ entry: RosterEntryDTO, query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }
    let needle = trimmed.lowercased()
    let badge = entry.badgeNumber.lowercased()
    let shift = entry.shift?.lowercased() ?? ""
    return badge.contains(needle) || shift.contains(needle)
}

private func assignmentMatchesSearch(_ assignment: OfficerAssignmentDTO, query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }
    let needle = trimmed.lowercased()
    return assignment.displayName.lowercased().contains(needle) ||
    assignment.badgeNumber.lowercased().contains(needle) ||
    assignment.assignmentDisplay.lowercased().contains(needle) ||
    (assignment.specialAssignment?.lowercased().contains(needle) ?? false)
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
            VStack(alignment: .leading, spacing: 28) {
                notesSection
                certificationsSection
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Private Notes")
                    .font(.headline)
                Text("Capture reminders, observations, or follow-ups. Everything you store here stays on your device and isn't shared with anyone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: MyLogDestination.notes) {
                MyLogMenuButton(
                    title: MyLogDestination.notes.title,
                    systemImage: MyLogDestination.notes.systemImage
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var certificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Certifications & Credentials")
                    .font(.headline)
                Text("Upload photos or PDFs of your cards and keep renewal dates handy so you're always ready for inspections.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: MyLogDestination.certifications) {
                MyLogMenuButton(
                    title: MyLogDestination.certifications.title,
                    systemImage: MyLogDestination.certifications.systemImage
                )
            }
            .buttonStyle(.plain)
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
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = MyCalendarViewModel()
    @State private var focusDate = Date()
    @State private var showingAddEvent = false
    @State private var editingEntry: ShiftScheduleEntry?
    @State private var selectedDayForDetails: Date?
    private var calendar: Calendar { Calendar.current }
    private var entries: [ShiftScheduleEntry] { viewModel.entries }
    private var ownerIdentifiers: [String] { auth.calendarOwnerIdentifiers }

    private var selectedDetailEntries: [ShiftScheduleEntry] {
        guard let selectedDayForDetails else { return [] }
        return entries(for: selectedDayForDetails)
    }

    private var eventHighlights: [Date: [ShiftScheduleEntry.Kind]] {
        var map: [Date: [ShiftScheduleEntry.Kind]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.start)
            map[day, default: []].append(entry.kind)
        }
        return map
    }

    private func entries(for date: Date) -> [ShiftScheduleEntry] {
        let target = calendar.startOfDay(for: date)
        let matches = entries
            .filter { calendar.isDate($0.start, inSameDayAs: target) }
            .sorted { $0.start < $1.start }
        return matches
    }

    private func handleDaySelection(_ date: Date) {
        focusDate = date
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedDayForDetails = date
        }
    }

    private func handleEntrySelection(_ entry: ShiftScheduleEntry) {
        guard entry.calendarEventId != nil else { return }
        editingEntry = entry
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CalendarCard(
                    focusDate: $focusDate,
                    eventHighlights: eventHighlights,
                    onDaySelected: handleDaySelection
                )
                Text("Use this space as your personal schedule. Events you add here are private and only visible to you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let selectedDayForDetails {
                    SelectedDayEventsCard(
                        date: selectedDayForDetails,
                        entries: selectedDetailEntries,
                        onEdit: handleEntrySelection
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(auth.currentUser == nil)
            }
        }
        .task { await reloadCalendarEntries() }
        .refreshable { await reloadCalendarEntries() }
        .sheet(isPresented: $showingAddEvent) {
            AddCalendarEventSheet(
                focusDate: focusDate,
                onSave: { input in
                    guard let ownerId = auth.primaryCalendarOwnerIdentifier else {
                        auth.alertMessage = "Unable to determine your DutyWire identifier. Try signing out and back in."
                        return
                    }
                    try await viewModel.addEvent(ownerId: ownerId, orgId: auth.userProfile.orgID, input: input)
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            if let eventId = entry.calendarEventId {
                EditCalendarEventSheet(
                    entry: entry,
                    onSave: { input in
                        guard let ownerId = entry.ownerId ?? auth.primaryCalendarOwnerIdentifier else {
                            auth.alertMessage = "Unable to determine the event owner. Try refreshing your calendar."
                            return
                        }
                        try await viewModel.updateEvent(ownerId: ownerId, eventId: eventId, input: input)
                    },
                    onDelete: {
                        try await viewModel.deleteEvent(eventId: eventId)
                    }
                )
            }
        }
    }

    private func reloadCalendarEntries() async {
        await viewModel.load(ownerIds: ownerIdentifiers)
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
                if !entry.location.isEmpty {
                    Text(entry.location)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

private struct SelectedDayEventsCard: View {
    let date: Date
    let entries: [ShiftScheduleEntry]
    var onEdit: (ShiftScheduleEntry) -> Void = { _ in }

    private var headerSubtitle: String {
        date.formatted(.dateTime.weekday(.wide).day().month())
    }

    private var eventCountLabel: String? {
        guard !entries.isEmpty else { return nil }
        return entries.count == 1 ? "1 event" : "\(entries.count) events"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(headerSubtitle)
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                if let label = eventCountLabel {
                    Text(label.uppercased())
                        .font(.caption2.weight(.bold))
                        .kerning(1)
                        .foregroundStyle(.secondary)
                }
            }

            if entries.isEmpty {
                Text("No events scheduled for this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(entries) { entry in
                        DayEventRow(entry: entry) {
                            if entry.calendarEventId != nil {
                                onEdit(entry)
                            }
                        }
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 20, y: 12)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct DayEventRow: View {
    let entry: ShiftScheduleEntry
    var onEdit: () -> Void

    private var isEditable: Bool { entry.calendarEventId != nil }

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                CalendarShiftRow(entry: entry)
                Spacer(minLength: 12)
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isEditable ? Color.white : Color.gray.opacity(0.5))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isEditable ? Color.accentColor : Color(.systemGray5))
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
        .accessibilityLabel(isEditable ? "Edit \(entry.assignment)" : "\(entry.assignment) details")
    }
}

private struct CalendarCard: View {
    @Binding var focusDate: Date
    var eventHighlights: [Date: [ShiftScheduleEntry.Kind]]
    var onDaySelected: (Date) -> Void = { _ in }

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: focusDate)) ?? focusDate
    }

    private var monthTitle: String {
        monthFormatter.string(from: monthStart)
    }

    private var weekdaySymbols: [String] {
        var symbols = calendar.shortWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        if firstIndex > 0 {
            let prefix = symbols[..<firstIndex]
            symbols.removeFirst(firstIndex)
            symbols.append(contentsOf: prefix)
        }
        return symbols
    }

    private var days: [CalendarDayValue] {
        var items: [CalendarDayValue] = []
        let firstOfMonth = monthStart
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        if leading > 0 {
            for offset in stride(from: leading, to: 0, by: -1) {
                if let date = calendar.date(byAdding: .day, value: -offset, to: firstOfMonth) {
                    items.append(CalendarDayValue(date: date, isCurrentMonth: false))
                }
            }
        }

        if let range = calendar.range(of: .day, in: .month, for: firstOfMonth) {
            for day in range {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                    items.append(CalendarDayValue(date: date, isCurrentMonth: true))
                }
            }
        }

        var lastDate = items.last?.date ?? firstOfMonth
        while items.count % 7 != 0 {
            lastDate = calendar.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
            items.append(CalendarDayValue(date: lastDate, isCurrentMonth: false))
        }

        return items
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    private func changeMonth(by value: Int) {
        focusDate = calendar.date(byAdding: .month, value: value, to: focusDate) ?? focusDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days) { day in
                    let isSelected = calendar.isDate(day.date, inSameDayAs: focusDate)
                    let dayKey = calendar.startOfDay(for: day.date)
                    let highlights = eventHighlights[dayKey] ?? []
                    Button {
                        focusDate = day.date
                        onDaySelected(day.date)
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.body.weight(isSelected ? .semibold : .regular))
                                .frame(maxWidth: .infinity)
                            CalendarDayDotsRow(kinds: highlights)
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(day.isCurrentMonth ? .primary : .secondary)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.18))
                                .padding(2)
                                .opacity(isSelected ? 1 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
}

private struct CalendarDayValue: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
}

private struct CalendarDayDotsRow: View {
    var kinds: [ShiftScheduleEntry.Kind]

    private var indicatorKinds: [ShiftScheduleEntry.Kind] {
        var seen: Set<ShiftScheduleEntry.Kind> = []
        var ordered: [ShiftScheduleEntry.Kind] = []
        for kind in kinds {
            if seen.insert(kind).inserted {
                ordered.append(kind)
            }
        }
        return Array(ordered.prefix(3))
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(indicatorKinds, id: \.self) { kind in
                Circle()
                    .fill(kind.tint.opacity(0.85))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
    }
}

@MainActor
private final class MyCalendarViewModel: ObservableObject {
    @Published private(set) var entries: [ShiftScheduleEntry] = []
    @Published var isLoading = false

    func load(ownerIds: [String]) async {
        let sanitized = ownerIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !sanitized.isEmpty else {
            entries = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let events = try await ShiftlinkAPI.listCalendarEvents(ownerIds: sanitized)
            entries = events.map { ShiftScheduleEntry(calendarEvent: $0) }
                .sorted { $0.start < $1.start }
        } catch {
            print("Failed to load calendar events", error)
        }
    }

    func addEvent(ownerId: String, orgId: String?, input: NewCalendarEventInput) async throws {
        let created = try await performCalendarMutation {
            try await ShiftlinkAPI.createCalendarEvent(ownerId: ownerId, orgId: orgId, input: input)
        }
        entries.append(ShiftScheduleEntry(calendarEvent: created))
        entries.sort { $0.start < $1.start }
    }

    func updateEvent(ownerId: String, eventId: String, input: NewCalendarEventInput) async throws {
        let updated = try await performCalendarMutation {
            try await ShiftlinkAPI.updateCalendarEvent(id: eventId, ownerId: ownerId, input: input)
        }
        if let index = entries.firstIndex(where: { $0.calendarEventId == eventId }) {
            entries[index] = ShiftScheduleEntry(calendarEvent: updated)
        } else {
            entries.append(ShiftScheduleEntry(calendarEvent: updated))
        }
        entries.sort { $0.start < $1.start }
    }

    func deleteEvent(eventId: String) async throws {
        try await performCalendarMutation {
            try await ShiftlinkAPI.deleteCalendarEvent(id: eventId)
        }
        entries.removeAll { $0.calendarEventId == eventId }
    }

    private func performCalendarMutation<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            if shouldRetryCalendarMutation(for: error) {
                try await ensureFreshAuthSession(forceRefresh: true)
                return try await operation()
            }
            throw error
        }
    }

    private func ensureFreshAuthSession(forceRefresh: Bool) async throws {
        _ = try await Amplify.Auth.fetchAuthSession(options: .init(forceRefresh: forceRefresh))
    }

    private func shouldRetryCalendarMutation(for error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        if message.contains("not authorized") || message.contains("expired") {
            return true
        }
        let typeDescription = String(describing: type(of: error)).lowercased()
        if typeDescription.contains("graphqlerro") || message.contains("graphqlresponseerror") {
            return true
        }
        return false
    }
}

private struct AddCalendarEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let focusDate: Date
    let onSave: (NewCalendarEventInput) async throws -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var category: CalendarEventCategory = .personal
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(focusDate: Date, onSave: @escaping (NewCalendarEventInput) async throws -> Void) {
        self.focusDate = focusDate
        self.onSave = onSave
        let defaultStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: focusDate) ?? focusDate
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultStart.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $category) {
                        ForEach(CalendarEventCategory.allCases) { option in
                            Text(option.typeLabel).tag(option)
                        }
                    }
                }

                Section("Timing") {
                    DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Details") {
                    TextField("Notes / Location", text: $details, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await saveEvent() } }
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    private func saveEvent() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil
        let input = NewCalendarEventInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startsAt: startDate,
            endsAt: endDate,
            category: category.rawValue,
            colorHex: category.hexColor,
            notes: details.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try await onSave(input)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

private struct EditCalendarEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: ShiftScheduleEntry
    let onSave: (NewCalendarEventInput) async throws -> Void
    let onDelete: () async throws -> Void

    @State private var title: String
    @State private var details: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var category: CalendarEventCategory
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    init(entry: ShiftScheduleEntry, onSave: @escaping (NewCalendarEventInput) async throws -> Void, onDelete: @escaping () async throws -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: entry.assignment)
        _details = State(initialValue: entry.detail)
        _startDate = State(initialValue: entry.start)
        _endDate = State(initialValue: entry.end)
        _category = State(initialValue: entry.kind.calendarCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $category) {
                        ForEach(CalendarEventCategory.allCases) { option in
                            Text(option.typeLabel).tag(option)
                        }
                    }
                }

                Section("Timing") {
                    DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Details") {
                    TextField("Notes / Location", text: $details, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Button("Delete Event", role: .destructive) {
                            Task { await deleteEvent() }
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await saveEvent() } }
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    private func saveEvent() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil
        let input = NewCalendarEventInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startsAt: startDate,
            endsAt: endDate,
            category: category.rawValue,
            colorHex: category.hexColor,
            notes: details.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try await onSave(input)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func deleteEvent() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await onDelete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

private enum CalendarEventCategory: String, CaseIterable, Identifiable {
    case shift = "SHIFT"
    case personal = "PERSONAL"
    case training = "TRAINING"
    case overtime = "OVERTIME"
    case task = "TASK"
    case court = "COURT"

    var id: String { rawValue }

    init(apiValue: String) {
        switch apiValue.uppercased() {
        case "DUTY":
            self = .shift
        default:
            self = CalendarEventCategory(rawValue: apiValue.uppercased()) ?? .personal
        }
    }

    var typeLabel: String {
        switch self {
        case .shift: return "Shift"
        case .personal: return "Personal"
        case .training: return "Training"
        case .overtime: return "Overtime"
        case .task: return "Task"
        case .court: return "Court"
        }
    }

    var hexColor: String {
        switch self {
        case .shift: return "#1C6EF2"
        case .personal: return "#7D7AF8"
        case .training: return "#8F7A5D"
        case .overtime: return "#F2994A"
        case .task: return "#10B981"
        case .court: return "#F97070"
        }
    }
}

private struct ShiftScheduleEntry: Identifiable {
    enum Kind: Hashable {
        case patrol, overtime, training, court, task, personal

        var label: String {
            switch self {
            case .patrol: return "Patrol"
            case .overtime: return "Overtime"
            case .training: return "Training"
            case .court: return "Court"
            case .task: return "Task"
            case .personal: return "Personal"
            }
        }

        var tint: Color {
            switch self {
            case .patrol: return .blue
            case .overtime: return .orange
            case .training: return .purple
            case .court: return .red
            case .task: return .green
            case .personal: return Color(red: 0.49, green: 0.46, blue: 0.97)
            }
        }

        var icon: String {
            switch self {
            case .patrol: return "shield"
            case .overtime: return "clock.arrow.circlepath"
            case .training: return "graduationcap.fill"
            case .court: return "building.columns.fill"
            case .task: return "checkmark.circle"
            case .personal: return "person.fill"
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
    let calendarEventId: String?
    let ownerId: String?

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
                start: day(4, hour: 10),
                end: day(4, hour: 11),
                assignment: "Squad stand-up",
                location: "Briefing Room",
                detail: "Bring weekly updates.",
                kind: .task
            ),
            ShiftScheduleEntry(
                start: day(5, hour: 18),
                end: day(5, hour: 20),
                assignment: "Family dinner",
                location: "Personal",
                detail: "Mom's birthday.",
                kind: .personal
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

    init(
        start: Date,
        end: Date,
        assignment: String,
        location: String,
        detail: String,
        kind: Kind,
        calendarEventId: String? = nil,
        ownerId: String? = nil
    ) {
        self.start = start
        self.end = end
        self.assignment = assignment
        self.location = location
        self.detail = detail
        self.kind = kind
        self.calendarEventId = calendarEventId
        self.ownerId = ownerId
    }
}

extension ShiftScheduleEntry {
    init(calendarEvent: CalendarEventDTO) {
        let category = CalendarEventCategory(apiValue: calendarEvent.category)
        self.init(
            start: calendarEvent.startsAt,
            end: calendarEvent.endsAt,
            assignment: calendarEvent.title,
            location: "",
            detail: calendarEvent.notes ?? "",
            kind: ShiftScheduleEntry.Kind(category: category),
            calendarEventId: calendarEvent.id,
            ownerId: calendarEvent.ownerId
        )
    }
}

extension ShiftScheduleEntry.Kind {
    fileprivate init(category: CalendarEventCategory) {
        switch category {
        case .overtime: self = .overtime
        case .training: self = .training
        case .court: self = .court
        case .task: self = .task
        case .personal: self = .personal
        case .shift: self = .patrol
        }
    }

    fileprivate var calendarCategory: CalendarEventCategory {
        switch self {
        case .patrol: return .shift
        case .overtime: return .overtime
        case .training: return .training
        case .court: return .court
        case .task: return .task
        case .personal: return .personal
        }
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
                                onSave: { updated in viewModel.update(note: updated) },
                                onDelete: { removed in viewModel.delete(noteIDs: [removed.id]) }
                            )
                        } label: {
                            ShiftNoteRow(note: note)
                        }
                    }
                    .onDelete(perform: deleteNotes)
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

    private func deleteNotes(at offsets: IndexSet) {
        let current = visibleNotes
        let ids = offsets.compactMap { index -> UUID? in
            guard index < current.count else { return nil }
            return current[index].id
        }
        viewModel.delete(noteIDs: ids)
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

    func delete(noteIDs: [ShiftNote.ID]) {
        guard !noteIDs.isEmpty else { return }
        notes.removeAll { noteIDs.contains($0.id) }
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
    var attachmentURL: URL? = nil

    var attachmentName: String? {
        attachmentURL?.lastPathComponent
    }
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

            if let attachmentName = note.attachmentName {
                Label(attachmentName, systemImage: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct NewShiftNoteSheet: View {
    @ObservedObject var viewModel: MyNotesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var attachmentURL: URL?
    @State private var showingDocumentPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

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

            Section("Attachment") {
                if let attachmentURL {
                    Label(attachmentURL.lastPathComponent, systemImage: "paperclip")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No attachment yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Menu {
                    PhotosPicker(
                        selection: $photoPickerItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Files app", systemImage: "folder")
                    }
                } label: {
                    Label(attachmentURL == nil ? "Add attachment" : "Replace attachment", systemImage: "paperclip.circle.fill")
                }

                if attachmentURL != nil {
                    Button(role: .destructive) {
                        attachmentURL = nil
                    } label: {
                        Label("Remove attachment", systemImage: "trash")
                    }
                } else {
                    Text("Attach supporting photos or documents.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                attachmentURL = url
                showingDocumentPicker = false
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let url = await persistAttachment(from: newItem) {
                    await MainActor.run {
                        attachmentURL = url
                    }
                }
                await MainActor.run {
                    photoPickerItem = nil
                }
            }
        }
    }

    private func saveNote() {
        let note = ShiftNote(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Note" : title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            attachmentURL: attachmentURL
        )

        viewModel.add(note: note)
        dismiss()
    }
}

private struct ShiftNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ShiftNote
    let onSave: (ShiftNote) -> Void
    let onDelete: (ShiftNote) -> Void
    @State private var showingDeleteDialog = false
    @State private var showingDocumentPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    init(
        note: ShiftNote,
        onSave: @escaping (ShiftNote) -> Void,
        onDelete: @escaping (ShiftNote) -> Void
    ) {
        _draft = State(initialValue: note)
        self.onSave = onSave
        self.onDelete = onDelete
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

            Section("Attachment") {
                if let attachmentURL = draft.attachmentURL {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(attachmentURL.lastPathComponent, systemImage: "paperclip")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ShareLink(item: attachmentURL) {
                            Label("Open attachment", systemImage: "arrow.up.right.square")
                        }
                    }
                } else {
                    Text("No attachment yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Menu {
                    PhotosPicker(
                        selection: $photoPickerItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Files app", systemImage: "folder")
                    }
                } label: {
                    Label(draft.attachmentURL == nil ? "Add attachment" : "Replace attachment", systemImage: "paperclip.circle.fill")
                }

                if draft.attachmentURL != nil {
                    Button(role: .destructive) {
                        draft.attachmentURL = nil
                    } label: {
                        Label("Remove attachment", systemImage: "trash")
                    }
                } else {
                    Text("Attach supporting photos or documents.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    showingDeleteDialog = true
                } label: {
                    Label("Delete Note", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete Note", role: .destructive) {
                onDelete(draft)
                dismiss()
            }
            Button("Cancel", role: .cancel) { showingDeleteDialog = false }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                draft.attachmentURL = url
                showingDocumentPicker = false
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let url = await persistAttachment(from: newItem) {
                    await MainActor.run {
                        draft.attachmentURL = url
                    }
                }
                await MainActor.run {
                    photoPickerItem = nil
                }
            }
        }
    }
}

private struct MyCertificationsView: View {
    @StateObject private var viewModel = MyCertificationsViewModel()
    @State private var showingAddSheet = false
    @State private var editingCertification: CertificationUpload?

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
                        Text("Tap \"Add Certification\" to attach a file and keep it handy in DutyWire.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(viewModel.certifications) { certification in
                        CertificationUploadRow(certification: certification)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCertification = certification
                            }
                            .swipeActions(allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.delete(id: certification.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingCertification = certification
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
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
        .sheet(item: $editingCertification) { item in
            NavigationStack {
                EditCertificationSheet(viewModel: viewModel, certification: item)
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
    @State private var photoPickerItem: PhotosPickerItem?

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
                if let attachmentURL {
                    Label(attachmentURL.lastPathComponent, systemImage: "paperclip")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No attachment yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Menu {
                    PhotosPicker(
                        selection: $photoPickerItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Files app", systemImage: "folder")
                    }
                } label: {
                    Label(attachmentURL == nil ? "Add attachment" : "Replace attachment", systemImage: "paperclip.circle.fill")
                }

                if attachmentURL != nil {
                    Button(role: .destructive) {
                        attachmentURL = nil
                    } label: {
                        Label("Remove attachment", systemImage: "trash")
                    }
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
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let url = await persistAttachment(from: newItem) {
                    await MainActor.run {
                        attachmentURL = url
                    }
                }
                await MainActor.run {
                    photoPickerItem = nil
                }
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

private struct EditCertificationSheet: View {
    @ObservedObject var viewModel: MyCertificationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CertificationUpload
    @State private var includeIssueDate: Bool
    @State private var showingDocumentPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    init(viewModel: MyCertificationsViewModel, certification: CertificationUpload) {
        self.viewModel = viewModel
        _draft = State(initialValue: certification)
        _includeIssueDate = State(initialValue: certification.issuedOn != nil)
    }

    private var isSaveDisabled: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Certification name", text: $draft.title)
                    .textInputAutocapitalization(.words)

                TextField("Issuing agency (optional)", text: Binding(
                    get: { draft.issuingAgency ?? "" },
                    set: { draft.issuingAgency = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.words)

                Toggle("Include issue date", isOn: $includeIssueDate.animation())
                if includeIssueDate {
                    DatePicker("Issued on", selection: Binding(
                        get: { draft.issuedOn ?? Date() },
                        set: { draft.issuedOn = $0 }
                    ), displayedComponents: .date)
                }
            }

            Section("Attachment") {
                if let attachmentName = draft.attachmentName {
                    Label(attachmentName, systemImage: "paperclip")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No attachment yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Menu {
                    PhotosPicker(
                        selection: $photoPickerItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Files app", systemImage: "folder")
                    }
                } label: {
                    Label(draft.attachmentURL == nil ? "Add attachment" : "Replace attachment", systemImage: "paperclip.circle.fill")
                }

                if draft.attachmentURL != nil {
                    Button(role: .destructive) {
                        draft.attachmentURL = nil
                    } label: {
                        Label("Remove attachment", systemImage: "trash")
                    }
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
                    Label("Save Changes", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isSaveDisabled)
            }
        }
        .navigationTitle("Edit Certification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                draft.attachmentURL = url
                showingDocumentPicker = false
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let url = await persistAttachment(from: newItem) {
                    await MainActor.run {
                        draft.attachmentURL = url
                    }
                }
                await MainActor.run {
                    photoPickerItem = nil
                }
            }
        }
    }

    private func save() {
        if !includeIssueDate {
            draft.issuedOn = nil
        } else if draft.issuedOn == nil {
            draft.issuedOn = Date()
        }

        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.title = trimmedTitle.isEmpty ? "Untitled Certification" : trimmedTitle
        viewModel.update(upload: draft)
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

    func update(upload: CertificationUpload) {
        guard let index = certifications.firstIndex(where: { $0.id == upload.id }) else { return }
        certifications[index] = upload
    }

    func delete(id: CertificationUpload.ID) {
        certifications.removeAll { $0.id == id }
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

// MARK: - Attachment Helpers

private func persistAttachment(from item: PhotosPickerItem) async -> URL? {
    do {
        if let data = try await item.loadTransferable(type: Data.self) {
            let preferredExtension = item.supportedContentTypes.first?.preferredFilenameExtension
            return persistAttachmentData(data, preferredExtension: preferredExtension)
        }
    } catch {
        print("Failed to load attachment from Photos picker: \(error.localizedDescription)")
    }
    return nil
}

private func persistAttachmentData(_ data: Data, preferredExtension: String?) -> URL? {
    let sanitizedExtension = preferredExtension?.trimmingCharacters(in: .whitespacesAndNewlines)
    var url = FileManager.default.temporaryDirectory
        .appendingPathComponent("Attachment-\(UUID().uuidString)")
    if let sanitizedExtension, !sanitizedExtension.isEmpty {
        url = url.appendingPathExtension(sanitizedExtension)
    }

    do {
        try data.write(to: url, options: [.atomic])
        return url
    } catch {
        print("Failed to persist attachment data: \(error.localizedDescription)")
        return nil
    }
}

@available(iOS 16.0, *)
private func makeAttachmentDraft(from item: PhotosPickerItem) async -> AttachmentDraft? {
    guard let url = await persistAttachment(from: item) else { return nil }
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let fileSize = (attributes?[.size] as? NSNumber)?.intValue
    let contentType = UTType(filenameExtension: url.pathExtension.lowercased())?.preferredMIMEType
    return AttachmentDraft(
        fileURL: url,
        fileName: url.lastPathComponent,
        contentType: contentType,
        fileSize: fileSize
    )
}
