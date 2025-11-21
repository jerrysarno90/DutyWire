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

private struct AttachmentLinkView: View {
    let attachment: FeedAttachment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachment")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let url = attachment.url {
                Link(destination: url) {
                    Label(attachment.title, systemImage: attachment.type == .file ? "paperclip" : "link")
                        .font(.body.weight(.semibold))
                }
            } else {
                Label(attachment.title, systemImage: "paperclip")
                    .font(.body.weight(.semibold))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        ZStack {
            CalendarBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(message ?? "Loading your DutyWire workspace…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Tabs

enum AppTab: Hashable { case dashboard, department, inbox, profile }
enum QuickActionDestination: Hashable {
    case myLocker
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
        case "agencymanager", "agency_manager":
            return "Agency Manager"
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

enum UserRole: String, CaseIterable {
    case agencyManager
    case admin
    case supervisor
    case nonSupervisor

    var priority: Int {
        switch self {
        case .agencyManager: return 4
        case .admin: return 3
        case .supervisor: return 2
        case .nonSupervisor: return 1
        }
    }

    var displayName: String {
        switch self {
        case .agencyManager: return "Agency Manager"
        case .admin: return "Administrator"
        case .supervisor: return "Supervisor"
        case .nonSupervisor: return RoleLabels.defaultRole
        }
    }
}

struct Permissions {
    var canAccessDepartmentHub: Bool
    var canSendDeptNotifications: Bool
    var canSendSquadMessages: Bool
    var canPostEventAssignments: Bool
    var canCreateDirectedPatrols: Bool
    var canCompleteDirectedPatrols: Bool

    var canManageSquads: Bool
    var canManageRoster: Bool
    var canManageVehicleRoster: Bool

    var canViewAudits: Bool
    var canManageTenantSecurity: Bool
    var canManagePushDevices: Bool

    static func configuration(for role: UserRole) -> Permissions {
        switch role {
        case .agencyManager:
            return Permissions(
                canAccessDepartmentHub: true,
                canSendDeptNotifications: true,
                canSendSquadMessages: true,
                canPostEventAssignments: true,
                canCreateDirectedPatrols: true,
                canCompleteDirectedPatrols: true,
                canManageSquads: true,
                canManageRoster: true,
                canManageVehicleRoster: true,
                canViewAudits: true,
                canManageTenantSecurity: true,
                canManagePushDevices: true
            )
        case .admin:
            return Permissions(
                canAccessDepartmentHub: true,
                canSendDeptNotifications: true,
                canSendSquadMessages: true,
                canPostEventAssignments: true,
                canCreateDirectedPatrols: true,
                canCompleteDirectedPatrols: true,
                canManageSquads: true,
                canManageRoster: true,
                canManageVehicleRoster: true,
                canViewAudits: true,
                canManageTenantSecurity: false,
                canManagePushDevices: false
            )
        case .supervisor:
            return Permissions(
                canAccessDepartmentHub: true,
                canSendDeptNotifications: false,
                canSendSquadMessages: true,
                canPostEventAssignments: true,
                canCreateDirectedPatrols: true,
                canCompleteDirectedPatrols: true,
                canManageSquads: false,
                canManageRoster: false,
                canManageVehicleRoster: false,
                canViewAudits: false,
                canManageTenantSecurity: false,
                canManagePushDevices: false
            )
        case .nonSupervisor:
            return Permissions(
                canAccessDepartmentHub: true,
                canSendDeptNotifications: false,
                canSendSquadMessages: false,
                canPostEventAssignments: false,
                canCreateDirectedPatrols: false,
                canCompleteDirectedPatrols: true,
                canManageSquads: false,
                canManageRoster: false,
                canManageVehicleRoster: false,
                canViewAudits: false,
                canManageTenantSecurity: false,
                canManagePushDevices: false
            )
        }
    }
}

extension UserRole {
    static func highestRole(from groups: [String]) -> UserRole {
        let sanitized = groups.map {
            $0.replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
        }
        if sanitized.contains(where: { $0 == "agencymanager" }) {
            return .agencyManager
        }
        if sanitized.contains(where: { $0 == "admin" }) {
            return .admin
        }
        if sanitized.contains(where: { $0 == "supervisor" }) {
            return .supervisor
        }
        return .nonSupervisor
    }
}

private enum DepartmentDestination: Hashable {
    case manageSquads
    case vehicleRoster
    case roster
    case audits
    case tenantSecurity
    case pushDevices
    case directedPatrols
    case eventAssignments
    case mySquad
    case squadActivity
}

struct RootTabsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var notificationPermissionController: NotificationPermissionController
    @State private var selection: AppTab = .dashboard

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.89, green: 0.94, blue: 1.0, alpha: 1.0)
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().clipsToBounds = true
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selection) {
                DashboardView()
                    .tabItem { tabItemLabel(title: "Dashboard", systemImage: "house.fill") }
                    .tag(AppTab.dashboard)

                if auth.permissions.canAccessDepartmentHub {
                    DepartmentHubContainerView()
                        .tabItem { tabItemLabel(title: "Department", systemImage: "building.2.fill") }
                        .tag(AppTab.department)
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
                    lexicon: auth.tenantLexicon,
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
        .onChange(of: auth.userRole) { _, _ in
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
        .toolbarBackground(Color(red: 0.89, green: 0.94, blue: 1.0), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
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
            if auth.permissions.canAccessDepartmentHub {
                tabs.append(.department)
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
    @State private var selectedActionItem: ActionItem?
    @State private var selectedLearningItem: LearningDeckItem?
    @State private var showAllActionItems = false
    @State private var showAllLearningItems = false
    @StateObject private var departmentFeed = DepartmentFeedViewModel()
    @State private var showingDepartmentBroadcastSheet = false
    @State private var departmentNotificationDestination: DepartmentNotificationDestination?

    private var squadLabel: String { auth.tenantLexicon.squadSingular }

    private var officerHubActions: [QuickAction] {
        [
            QuickAction(title: "My Locker", systemImage: "lock.rectangle.on.rectangle", destination: .myLocker),
            QuickAction(title: "My Personal Calendar", systemImage: "calendar", destination: .calendar)
        ]
    }

    private var departmentHubActions: [QuickAction] {
        var actions: [QuickAction] = []
        if auth.permissions.canSendSquadMessages || auth.permissions.canManageSquads {
            actions.append(
                QuickAction(title: "My \(squadLabel)", systemImage: "person.3.fill", destination: .squad, badgeCount: unreadSquadBadgeCount)
            )
        }
        actions.append(
            QuickAction(title: "Events & Sign Ups", systemImage: "calendar.badge.clock", destination: .overtime)
        )
        if auth.permissions.canCreateDirectedPatrols || auth.permissions.canCompleteDirectedPatrols {
            actions.append(
                QuickAction(title: "Directed Patrols", systemImage: "scope", destination: .patrols)
            )
        }
        if auth.permissions.canManageVehicleRoster {
            actions.append(
                QuickAction(title: "Vehicle Roster", systemImage: "car.fill", destination: .vehicles)
            )
        }
        return actions
    }

    private var unreadSquadBadgeCount: Int {
        auth.notifications.filter {
            !$0.isRead && ($0.feedType == .squadNotification || $0.feedType == .squadTask)
        }.count
    }

    private var currentOrgId: String? {
        auth.resolvedOrgId
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
            ZStack {
                dashboardBackground
                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            logoHeader
                            WelcomeHeroCard(
                                rank: heroRank,
                                name: heroName,
                                assignment: heroAssignment
                            )
                            ActionHubCard(
                                title: "Officer Hub",
                                actions: officerHubActions
                            )
                            .padding(.top, 12)
                            ActionHubCard(
                                title: "Department Hub",
                                actions: departmentHubActions,
                                canSendNotifications: auth.permissions.canSendDeptNotifications,
                                onSendNotification: presentDepartmentNotificationPicker,
                                notificationLabel: "Send Dept Notification"
                            )
                            .padding(.top, 12)
                            ActionItemsSection(
                                items: departmentFeed.actionItems,
                                hasUnread: departmentFeed.actionItems.contains { $0.isUnread },
                                onSelect: handleSelectActionItem,
                                onSeeAll: {
                                    showAllActionItems = true
                                }
                            )
                                .padding(.top, 12)
                            LearningDeckSection(
                                items: departmentFeed.learningDeckItems,
                                hasUnread: departmentFeed.learningDeckItems.contains { $0.isUnread },
                                onSelect: handleSelectLearningItem,
                                onSeeAll: {
                                    showAllLearningItems = true
                                }
                            )
                                .padding(.top, 12)
                        }
                        .frame(maxWidth: max(min(proxy.size.width - 40, 420), 280))
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { Task { await auth.signOut() } }
                }
            }
            .navigationDestination(for: QuickActionDestination.self) { destination in
                switch destination {
                case .myLocker:
                    MyLockerView()
                case .squad:
                    MySquadView()
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
        .task(id: currentOrgId ?? "org-none") {
            await departmentFeed.refresh(
                orgId: currentOrgId,
                userId: auth.currentUser?.userId
            )
        }
        .sheet(isPresented: $showingDepartmentBroadcastSheet) {
            DepartmentNotificationPickerView(
                onSelectActionItem: { launchDepartmentNotification(.actionItem) },
                onSelectLearningDeck: { launchDepartmentNotification(.learningDeck) },
                onClose: { showingDepartmentBroadcastSheet = false }
            )
        }
        .sheet(item: $departmentNotificationDestination) { destination in
            switch destination {
            case .actionItem:
                ActionItemComposerView(onSubmit: { data in
                    handleActionItemSubmission(data)
                })
            case .learningDeck:
                LearningDeckComposerView(onSubmit: { data in
                    handleLearningDeckSubmission(data)
                })
            }
        }
        .sheet(item: $selectedActionItem) { item in
            NavigationStack {
                ActionItemDetailView(
                    item: item,
                    onAppear: {
                        Task {
                            await departmentFeed.markActionItemRead(
                                itemId: item.id,
                                orgId: currentOrgId,
                                userId: auth.currentUser?.userId
                            )
                        }
                    }
                )
            }
        }
        .sheet(item: $selectedLearningItem) { item in
            NavigationStack {
                LearningDeckDetailView(
                    item: item,
                    onAppear: {
                        Task {
                            await departmentFeed.markLearningItemRead(
                                itemId: item.id,
                                orgId: currentOrgId,
                                userId: auth.currentUser?.userId
                            )
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAllActionItems) {
            NavigationStack {
                ActionItemsListView(
                    items: departmentFeed.actionItems,
                    onSelect: { item in
                        Task {
                            await departmentFeed.markActionItemRead(
                                itemId: item.id,
                                orgId: currentOrgId,
                                userId: auth.currentUser?.userId
                            )
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAllLearningItems) {
            NavigationStack {
                LearningDeckListView(
                    items: departmentFeed.learningDeckItems,
                    onSelect: { item in
                        Task {
                            await departmentFeed.markLearningItemRead(
                                itemId: item.id,
                                orgId: currentOrgId,
                                userId: auth.currentUser?.userId
                            )
                        }
                    }
                )
            }
        }
        .alert("DutyWire Notifications", isPresented: Binding(
            get: { departmentFeed.errorMessage != nil },
            set: { if !$0 { departmentFeed.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                departmentFeed.errorMessage = nil
            }
        } message: {
            Text(departmentFeed.errorMessage ?? "")
        }
    }

    private var dashboardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.09, blue: 0.23),
                    Color(red: 0.11, green: 0.17, blue: 0.33)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Image("dashboardBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.4)
        }
    }

    private var logoHeader: some View {
        VStack(spacing: 4) {
            Image("dutywirelogo")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .padding(.top, 4)
                .accessibilityLabel("DutyWire")
            Text("Built for the way cops actually work and live.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroRank: String {
        auth.userProfile.rank?.nilIfEmpty
            ?? auth.primaryRoleDisplayName
            ?? auth.userRole.displayName
    }

    private var heroName: String {
        auth.userProfile.fullName?.nilIfEmpty
            ?? auth.userProfile.usernameForDisplay
            ?? auth.userProfile.email
            ?? "DutyWire Officer"
    }

    private var heroAssignment: String {
        if let assignment = auth.currentAssignment {
            if let title = assignment.title.nilIfEmpty {
                return title
            }
            if let detail = assignment.detail?.nilIfEmpty {
                return detail
            }
        }
        return auth.userProfile.siteKey?.nilIfEmpty ?? "Field Operations"
    }

    private func presentDepartmentNotificationPicker() {
        showingDepartmentBroadcastSheet = true
    }

    private func launchDepartmentNotification(_ destination: DepartmentNotificationDestination) {
        showingDepartmentBroadcastSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            departmentNotificationDestination = destination
        }
    }

    private func handleActionItemSubmission(_ data: ActionItemComposerData) {
        guard let orgId = currentOrgId else {
            departmentFeed.errorMessage = "Add your agency's Org ID before sending notifications."
            return
        }
        guard let senderId = currentSenderId else {
            departmentFeed.errorMessage = "Missing sender identifier."
            return
        }
        Task {
            await departmentFeed.createActionItem(
                payload: data,
                orgId: orgId,
                senderId: senderId,
                senderDisplayName: creatorDisplayName,
                currentUserId: auth.currentUser?.userId
            )
        }
    }

    private func handleLearningDeckSubmission(_ data: LearningDeckComposerData) {
        guard let orgId = currentOrgId else {
            departmentFeed.errorMessage = "Add your agency's Org ID before sending notifications."
            return
        }
        guard let senderId = currentCreatorId else {
            departmentFeed.errorMessage = "Missing sender identifier."
            return
        }
        Task {
            await departmentFeed.createLearningDrop(
                payload: data,
                orgId: orgId,
                senderId: senderId,
                senderDisplayName: creatorDisplayName,
                currentUserId: auth.currentUser?.userId
            )
        }
    }

    private func handleSelectActionItem(_ item: ActionItem) {
        selectedActionItem = item
        Task {
            await departmentFeed.markActionItemRead(
                itemId: item.id,
                orgId: currentOrgId,
                userId: auth.currentUser?.userId
            )
        }
    }

    private func handleSelectLearningItem(_ item: LearningDeckItem) {
        selectedLearningItem = item
        Task {
            await departmentFeed.markLearningItemRead(
                itemId: item.id,
                orgId: currentOrgId,
                userId: auth.currentUser?.userId
            )
        }
    }
}

@MainActor
private final class DepartmentFeedViewModel: ObservableObject {
    @Published private(set) var actionItems: [ActionItem] = []
    @Published private(set) var learningDeckItems: [LearningDeckItem] = []
    @Published var errorMessage: String?

    private let actionFeedKey = FeedPayloadType.action
    private let learningFeedKey = FeedPayloadType.learning
    private static let deadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func refresh(orgId: String?, userId: String?) async {
        guard let orgId = orgId?.nilIfEmpty else {
            actionItems = []
            learningDeckItems = []
            return
        }
        do {
            let receipts = try await fetchReceipts(userId: userId)
            let readSet = Set(receipts.filter { $0.isRead }.map { $0.notificationId })
            async let actionRecordsTask = ShiftlinkAPI.listNotificationMessages(
                orgId: orgId,
                category: .taskAlert,
                limit: 40
            )
            async let learningRecordsTask = ShiftlinkAPI.listNotificationMessages(
                orgId: orgId,
                category: .bulletin,
                limit: 40
            )
            let actionRecords = try await actionRecordsTask
            let learningRecords = try await learningRecordsTask
            actionItems = actionRecords
                .compactMap { makeActionItem(from: $0, readSet: readSet) }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            learningDeckItems = learningRecords
                .compactMap { makeLearningItem(from: $0, readSet: readSet) }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createActionItem(
        payload: ActionItemComposerData,
        orgId: String,
        senderId: String,
        senderDisplayName: String?,
        currentUserId: String?
    ) async {
        let trimmedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let summary = payload.summary.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "No additional notes."
        var metadata: [String: Any] = [
            "feedType": actionFeedKey.rawValue,
            "summary": summary,
            "category": payload.category.rawValue
        ]
        if let dueText = payload.dueText?.nilIfEmpty {
            metadata["dueText"] = dueText
        }
        if let deadline = payload.deadline {
            metadata["deadline"] = ShiftlinkAPI.encode(date: deadline)
        }
        metadata["automaticReminder"] = payload.sendReminder
        if let attachment = metadataAttachmentPayload(for: payload.attachment) {
            metadata["attachment"] = attachment
        }
        do {
            let creator = senderDisplayName?.nilIfEmpty ?? senderId
            _ = try await ShiftlinkAPI.createNotificationMessage(
                orgId: orgId,
                title: trimmedTitle,
                body: summary,
                category: .taskAlert,
                recipients: ["*"],
                metadata: metadata,
                createdBy: creator
            )
            _ = try? await ShiftlinkAPI.sendNotification(
                orgId: orgId,
                recipients: ["*"],
                title: trimmedTitle,
                body: summary,
                category: .taskAlert,
                metadata: metadata
            )
            await refresh(orgId: orgId, userId: currentUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createLearningDrop(
        payload: LearningDeckComposerData,
        orgId: String,
        senderId: String,
        senderDisplayName: String?,
        currentUserId: String?
    ) async {
        let trimmedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let subtitle = payload.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "No summary provided."
        let tag = payload.topic.defaultTag
        var metadata: [String: Any] = [
            "feedType": learningFeedKey.rawValue,
            "subtitle": subtitle,
            "tag": tag,
            "topic": payload.topic.rawValue
        ]
        if let attachment = metadataAttachmentPayload(for: payload.attachment) {
            metadata["attachment"] = attachment
        }
        do {
            let creator = senderDisplayName?.nilIfEmpty ?? senderId
            _ = try await ShiftlinkAPI.createNotificationMessage(
                orgId: orgId,
                title: trimmedTitle,
                body: subtitle,
                category: .bulletin,
                recipients: ["*"],
                metadata: metadata,
                createdBy: creator
            )
            _ = try? await ShiftlinkAPI.sendNotification(
                orgId: orgId,
                recipients: ["*"],
                title: trimmedTitle,
                body: subtitle,
                category: .bulletin,
                metadata: metadata
            )
            await refresh(orgId: orgId, userId: currentUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markActionItemRead(itemId: String, orgId: String?, userId: String?) async {
        guard updateLocalActionItem(id: itemId) else { return }
        guard let orgId = orgId?.nilIfEmpty,
              let userId = userId?.nilIfEmpty else { return }
        do {
            try await ShiftlinkAPI.markNotificationRead(notificationId: itemId, orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markLearningItemRead(itemId: String, orgId: String?, userId: String?) async {
        guard updateLocalLearningItem(id: itemId) else { return }
        guard let orgId = orgId?.nilIfEmpty,
              let userId = userId?.nilIfEmpty else { return }
        do {
            try await ShiftlinkAPI.markNotificationRead(notificationId: itemId, orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLocalActionItem(id: String) -> Bool {
        guard let index = actionItems.firstIndex(where: { $0.id == id }) else { return false }
        actionItems[index].isUnread = false
        return true
    }

    private func updateLocalLearningItem(id: String) -> Bool {
        guard let index = learningDeckItems.firstIndex(where: { $0.id == id }) else { return false }
        learningDeckItems[index].isUnread = false
        return true
    }

    private func fetchReceipts(userId: String?) async throws -> [NotificationReceiptRecord] {
        guard let userId = userId?.nilIfEmpty else { return [] }
        return try await ShiftlinkAPI.fetchNotificationReceiptsForUser(userId: userId, limit: 200)
    }

    private func metadataAttachmentPayload(for attachment: AttachmentComposerData?) -> [String: Any]? {
        attachment?.metadataPayload
    }

    private func makeActionItem(from record: NotificationMessageRecord, readSet: Set<String>) -> ActionItem? {
        guard
            let metadata: ActionFeedMetadata = decodeFeedMetadata(from: record.metadata),
            metadata.feedType?.lowercased() == actionFeedKey.rawValue
        else { return nil }
        let category = ActionItemCategory(rawValue: metadata.category?.lowercased() ?? "") ?? .directive
        let subtitle = metadata.summary?.nilIfEmpty ?? record.body
        let deadlineDate = metadata.deadline.flatMap { ShiftlinkAPI.parse(dateString: $0) }
        let dueText: String
        if let deadlineDate {
            let formatted = DepartmentFeedViewModel.deadlineFormatter.string(from: deadlineDate)
            dueText = "Due \(formatted)"
        } else if let text = metadata.dueText?.nilIfEmpty {
            dueText = text
        } else {
            dueText = "No deadline set."
        }
        let attachment = feedAttachment(from: metadata.attachment)
        return ActionItem(
            id: record.id,
            title: record.title,
            subtitle: subtitle,
            dueText: dueText,
            iconName: category.iconName,
            tint: category.tint,
            isUnread: !readSet.contains(record.id),
            createdAt: record.createdAt.flatMap { ShiftlinkAPI.parse(dateString: $0) },
            deadline: deadlineDate,
            automaticReminder: metadata.automaticReminder ?? false,
            attachment: attachment
        )
    }

    private func makeLearningItem(from record: NotificationMessageRecord, readSet: Set<String>) -> LearningDeckItem? {
        guard
            let metadata: LearningFeedMetadata = decodeFeedMetadata(from: record.metadata),
            metadata.feedType?.lowercased() == learningFeedKey.rawValue
        else { return nil }
        let topic = LearningDeckTopic(rawValue: metadata.topic ?? "") ?? .caseLaw
        let subtitle = metadata.subtitle?.nilIfEmpty ?? record.body
        let tag = metadata.tag?.nilIfEmpty ?? topic.defaultTag
        let attachment = feedAttachment(from: metadata.attachment)
        return LearningDeckItem(
            id: record.id,
            title: record.title,
            subtitle: subtitle,
            tag: tag,
            imageName: topic.imageName,
            isUnread: !readSet.contains(record.id),
            createdAt: record.createdAt.flatMap { ShiftlinkAPI.parse(dateString: $0) },
            attachment: attachment
        )
    }
}

enum FeedPayloadType: String {
    case action
    case learning
    case squadNotification
    case squadTask
}

fileprivate struct ActionFeedMetadata: Decodable {
    let feedType: String?
    let summary: String?
    let dueText: String?
    let category: String?
    let deadline: String?
    let automaticReminder: Bool?
    let attachment: AttachmentMetadata?
}

fileprivate struct LearningFeedMetadata: Decodable {
    let feedType: String?
    let subtitle: String?
    let tag: String?
    let topic: String?
    let attachment: AttachmentMetadata?
}

fileprivate struct AttachmentMetadata: Decodable {
    let type: String?
    let title: String?
    let url: String?
}

fileprivate struct SquadRecipientMetadata: Decodable {
    let id: String?
    let name: String?
    let detail: String?
    let userId: String?
}

fileprivate struct SquadFeedMetadata: Decodable {
    let feedType: String?
    let recipients: [SquadRecipientMetadata]?
    let dueDate: String?
    let isCompleted: Bool?
    let createdByUserId: String?
    let attachment: AttachmentMetadata?
}

fileprivate struct BaseFeedMetadata: Decodable {
    let feedType: String?
}

fileprivate func feedType(from metadata: String?) -> FeedPayloadType? {
    guard
        let base: BaseFeedMetadata = decodeFeedMetadata(from: metadata),
        let raw = base.feedType?.lowercased()
    else { return nil }
    return FeedPayloadType(rawValue: raw)
}

fileprivate func decodeFeedMetadata<T: Decodable>(from source: String?) -> T? {
    guard let source,
          let data = source.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}

fileprivate func feedAttachment(from metadata: AttachmentMetadata?) -> FeedAttachment? {
    guard
        let metadata,
        let rawType = metadata.type?.lowercased(),
        rawType != AttachmentKind.none.rawValue,
        let attachmentType = FeedAttachment.AttachmentType(rawValue: rawType)
    else { return nil }
    let title = metadata.title?.nilIfEmpty ?? (attachmentType == .file ? "View File" : "View Link")
    let url = metadata.url?.nilIfEmpty.flatMap { URL(string: $0) }
    return FeedAttachment(type: attachmentType, title: title, url: url)
}

fileprivate func squadRecordTargetsUser(_ record: NotificationMessageRecord, userId: String?) -> Bool {
    guard let userId = userId?.nilIfEmpty else { return true }
    let normalizedUserId = userId.lowercased()
    if let recipients = record.recipients {
        if recipients.contains("*") { return true }
        if recipients.contains(where: { $0.lowercased() == normalizedUserId }) {
            return true
        }
    }
    if let metadata: SquadFeedMetadata = decodeFeedMetadata(from: record.metadata),
       let creatorId = metadata.createdByUserId?.lowercased() {
        return creatorId == normalizedUserId
    }
    return false
}

private struct NotificationPermissionBanner: View {
    let status: UNAuthorizationStatus
    let lexicon: TenantLexicon
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
                         "Enable notifications in Settings so you don’t miss special detail or \(lexicon.squadSingular.lowercased()) alerts." :
                         "Stay informed about special details, \(lexicon.squadSingular.lowercased()) \(lexicon.taskPlural.lowercased()), and alerts.")
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

private enum DepartmentNotificationDestination: String, Identifiable {
    case actionItem
    case learningDeck

    var id: String { rawValue }
}

private struct DepartmentNotificationPickerView: View {
    let onSelectActionItem: () -> Void
    let onSelectLearningDeck: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.blue)
                        Text("Choose what to send")
                            .font(.title3.weight(.semibold))
                        Text("Keep your department looped in with quick Action Items or Learning drops.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        DepartmentNotificationOptionCard(
                            title: "Action Item",
                            subtitle: "Deliver a task, reminder, or follow-up.",
                            icon: "exclamationmark.circle.fill",
                            tint: .orange,
                            action: onSelectActionItem
                        )

                        DepartmentNotificationOptionCard(
                            title: "Learning Drop",
                            subtitle: "Share training, case law, or quick reads.",
                            icon: "book.fill",
                            tint: .blue,
                            action: onSelectLearningDeck
                        )
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Send Dept Notification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct DepartmentNotificationOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .shadow(color: tint.opacity(0.2), radius: 6, y: 4)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ActionItemComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var summary = ""
    @State private var dueText = ""
    @State private var category: ActionItemCategory = .directive
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var sendReminder = false
    @State private var attachmentKind: AttachmentKind = .none
    @State private var attachmentTitle = ""
    @State private var attachmentURL = ""
    let onSubmit: (ActionItemComposerData) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Delivery") {
                    Picker("Style", selection: $category) {
                        ForEach(ActionItemCategory.allCases) { cat in
                            Text(cat.label).tag(cat)
                        }
                    }

                    Toggle("Set a deadline?", isOn: $hasDeadline.animation())

                    if hasDeadline {
                        DatePicker("Deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                        Toggle("Send Automatic Reminder?", isOn: $sendReminder)
                    } else {
                        TextField("Due / Reminder", text: $dueText)
                    }
                }

                Section("Attachment") {
                    Picker("Attachment Type", selection: $attachmentKind) {
                        ForEach(AttachmentKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    if attachmentKind != .none {
                        TextField("Attachment Title", text: $attachmentTitle)
                        TextField("File or Website Link", text: $attachmentURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.none)
                    }
                }
            }
            .navigationTitle("New Action Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: submit)
                        .disabled(!canSubmit)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentValid: Bool
        if attachmentKind == .none {
            attachmentValid = true
        } else {
            let trimmedURL = attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines)
            attachmentValid = !trimmedURL.isEmpty
        }
        return !trimmedTitle.isEmpty && attachmentValid
    }

    private var attachmentData: AttachmentComposerData? {
        guard attachmentKind != .none else { return nil }
        let trimmedURL = attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        let trimmedTitle = attachmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return AttachmentComposerData(
            type: attachmentKind,
            title: trimmedTitle.isEmpty ? attachmentKind.defaultTitle : trimmedTitle,
            link: trimmedURL
        )
    }

    private func submit() {
        guard canSubmit else { return }
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDue = dueText.trimmingCharacters(in: .whitespacesAndNewlines)
        onSubmit(ActionItemComposerData(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: trimmedSummary,
            dueText: trimmedDue.isEmpty ? nil : trimmedDue,
            category: category,
            deadline: hasDeadline ? deadline : nil,
            sendReminder: hasDeadline ? sendReminder : false,
            attachment: attachmentData
        ))
        dismiss()
    }
}

private struct ActionItemComposerData {
    let title: String
    let summary: String
    let dueText: String?
    let category: ActionItemCategory
    let deadline: Date?
    let sendReminder: Bool
    let attachment: AttachmentComposerData?
}

private enum ActionItemCategory: String, CaseIterable, Identifiable {
    case directive
    case training
    case urgent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .directive: return "Directive"
        case .training: return "Training"
        case .urgent: return "Urgent"
        }
    }

    var iconName: String {
        switch self {
        case .directive: return "doc.text.magnifyingglass"
        case .training: return "checkmark.seal.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .directive: return .blue
        case .training: return .green
        case .urgent: return .orange
        }
    }
}

private enum AttachmentKind: String, CaseIterable, Identifiable {
    case none
    case file
    case link

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .file: return "File Attachment"
        case .link: return "Website Link"
        }
    }

    var defaultTitle: String {
        switch self {
        case .none: return ""
        case .file: return "View File"
        case .link: return "View Link"
        }
    }
}

private struct AttachmentComposerData {
    let type: AttachmentKind
    let title: String
    let link: String

    var metadataPayload: [String: Any] {
        [
            "type": type.rawValue,
            "title": title,
            "url": link
        ]
    }
}

private extension AttachmentComposerData {
    func makeFeedAttachment() -> FeedAttachment? {
        let url = URL(string: link)
        let attachmentType: FeedAttachment.AttachmentType = type == .file ? .file : .link
        return FeedAttachment(type: attachmentType, title: title, url: url)
    }
}

private struct LearningDeckComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var subtitle = ""
    @State private var topic: LearningDeckTopic = .caseLaw
    @State private var attachmentKind: AttachmentKind = .none
    @State private var attachmentTitle = ""
    @State private var attachmentURL = ""
    let onSubmit: (LearningDeckComposerData) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Summary", text: $subtitle, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Presentation") {
                    Picker("Topic", selection: $topic) {
                        ForEach(LearningDeckTopic.allCases) { topic in
                            Text(topic.title).tag(topic)
                        }
                    }
                    Text(topic.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }

                Section("Attachment") {
                    Picker("Attachment Type", selection: $attachmentKind) {
                        ForEach(AttachmentKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    if attachmentKind != .none {
                        TextField("Attachment Title", text: $attachmentTitle)
                        TextField("File or Website Link", text: $attachmentURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.none)
                    }
                }

            }
            .navigationTitle("New Learning Drop")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: submit)
                        .disabled(!canSubmit)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentValid: Bool
        if attachmentKind == .none {
            attachmentValid = true
        } else {
            attachmentValid = !attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !trimmedTitle.isEmpty && attachmentValid
    }

    private var attachmentData: AttachmentComposerData? {
        guard attachmentKind != .none else { return nil }
        let trimmedURL = attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        let trimmedTitle = attachmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return AttachmentComposerData(
            type: attachmentKind,
            title: trimmedTitle.isEmpty ? attachmentKind.defaultTitle : trimmedTitle,
            link: trimmedURL
        )
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit(
            LearningDeckComposerData(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                topic: topic,
                attachment: attachmentData
            )
        )
        dismiss()
    }
}

private struct LearningDeckComposerData {
    let title: String
    let subtitle: String
    let topic: LearningDeckTopic
    let attachment: AttachmentComposerData?
}

private enum LearningDeckTopic: String, CaseIterable, Identifiable {
    case caseLaw
    case tactics
    case wellness
    case leadership

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caseLaw: return "Case Law"
        case .tactics: return "Tactics"
        case .wellness: return "Wellness"
        case .leadership: return "Leadership"
        }
    }

    var description: String {
        switch self {
        case .caseLaw:
            return "Share recent rulings, legal shifts, or courtroom lessons."
        case .tactics:
            return "Push quick refreshers on officer safety or tactics."
        case .wellness:
            return "Highlight wellness content for sleep, stress, or mindset."
        case .leadership:
            return "Focus on evaluations, promotions, and mentorship."
        }
    }

    var defaultTag: String {
        switch self {
        case .caseLaw: return "Case Law"
        case .tactics: return "Tactics"
        case .wellness: return "Wellness"
        case .leadership: return "Leadership"
        }
    }

    var imageName: String {
        switch self {
        case .caseLaw: return "learningdeck1"
        case .tactics: return "learningdeck2"
        case .wellness: return "learningdeck3"
        case .leadership: return "learningdeck4"
        }
    }
}

private struct QuickAction: Identifiable {
    let title: String
    let systemImage: String
    let destination: QuickActionDestination
    var badgeCount: Int = 0

    var id: String { title }
}

private struct WelcomeHeroCard: View {
    let rank: String
    let name: String
    let assignment: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Welcome Back")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            Text(rank)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Text(name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(assignment)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.17, blue: 0.45),
                    Color(red: 0.19, green: 0.42, blue: 0.78)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

private struct ActionHubCard: View {
    let title: String
    let actions: [QuickAction]
    var canSendNotifications: Bool = false
    var onSendNotification: () -> Void = {}
    var notificationLabel: String = "+ Send New Notification"

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            if actions.isEmpty {
                Text("No quick actions available for your role.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(actions) { action in
                        NavigationLink(value: action.destination) {
                            HubButton(action: action)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if canSendNotifications {
                Button(action: onSendNotification) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(notificationLabel)
                            .fontWeight(.semibold)
                    }
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

private struct HubButton: View {
    let action: QuickAction

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(white: 0.96))

                    Image(systemName: action.systemImage)
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(width: 30, height: 30)

                Text(action.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.025), radius: 4, x: 0, y: 2)

            if action.badgeCount > 0 {
                UnreadBadge()
                    .padding(6)
            }
        }
    }
}

private struct FeedAttachment: Identifiable {
    enum AttachmentType: String {
        case file
        case link
    }

    let id = UUID()
    let type: AttachmentType
    let title: String
    let url: URL?
}

private struct ActionItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let dueText: String
    let iconName: String
    let tint: Color
    var isUnread: Bool
    let createdAt: Date?
    let deadline: Date?
    let automaticReminder: Bool
    let attachment: FeedAttachment?
}

private struct ActionItemsSection: View {
    let items: [ActionItem]
    var hasUnread: Bool
    var onSelect: (ActionItem) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("Action Items")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    if hasUnread {
                        UnreadBadge()
                    }
                }
                Spacer()
                if !items.isEmpty {
                    Button("See All") {
                        onSeeAll()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }

            Text("Tasks and directives that need your attention.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            ActionItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActionItemCard: View {
    let item: ActionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(item.tint.opacity(0.12))

                Image(systemName: item.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 34, height: 34)

            Text(item.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(item.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(item.dueText)
                .font(.caption.weight(.medium))
                .foregroundStyle(item.tint)
        }
        .padding(10)
        .frame(width: 170, height: 108, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 4, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            if item.isUnread {
                UnreadBadge()
                    .offset(x: -6, y: 6)
            }
        }
    }
}

private struct UnreadBadge: View {
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .shadow(color: Color.red.opacity(0.3), radius: 2, y: 1)
    }
}

private struct LearningDeckItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tag: String
    let imageName: String
    var isUnread: Bool
    let createdAt: Date?
    let attachment: FeedAttachment?
}

private struct LearningDeckSection: View {
    let items: [LearningDeckItem]
    var hasUnread: Bool
    var onSelect: (LearningDeckItem) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("Learning Deck")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    if hasUnread {
                        UnreadBadge()
                    }
                }
                Spacer()
                if !items.isEmpty {
                    Button("See All") { onSeeAll() }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Text("Quick reads, case law, and studies picked by your admins.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            LearningDeckCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LearningDeckCard: View {
    let item: LearningDeckItem
    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 118

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.tag.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .overlay(alignment: .topTrailing) {
            if item.isUnread {
                UnreadBadge()
                    .padding(10)
            }
        }
    }
}

private struct ActionItemDetailView: View {
    let item: ActionItem
    var onAppear: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(item.title, systemImage: item.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.tint)

                Text(item.subtitle)
                    .font(.body)
                    .foregroundStyle(.primary)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Due / Reminder")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.dueText)
                        .font(.body)
                }

                if item.automaticReminder {
                    Label("Automatic reminder scheduled", systemImage: "bell.badge.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let attachment = item.attachment {
                    AttachmentLinkView(attachment: attachment)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Action Item")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            onAppear?()
        }
    }
}

private struct ActionItemsListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [ActionItem]
    var onSelect: (ActionItem) -> Void

    var body: some View {
        List(items) { item in
            NavigationLink {
                ActionItemDetailView(item: item, onAppear: { onSelect(item) })
            } label: {
                ActionItemRow(item: item)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Action Items")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

private struct ActionItemRow: View {
    let item: ActionItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.headline)
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34)
                .background(item.tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.dueText)
                .font(.caption)
                .foregroundStyle(item.tint)
        }
        .padding(.vertical, 6)
    }
}

private struct LearningDeckDetailView: View {
    let item: LearningDeckItem
    var onAppear: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)

                Text(item.tag.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(item.title)
                    .font(.title3.weight(.semibold))

                Text(item.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let attachment = item.attachment {
                    AttachmentLinkView(attachment: attachment)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Learning Deck")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            onAppear?()
        }
    }
}

private struct SquadUpdateDetailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let update: SquadUpdate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(update.title)
                    .font(.title3.weight(.semibold))
                Text("Sent \(update.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(update.message)
                    .font(.body)
                if let attachment = update.attachment {
                    AttachmentLinkView(attachment: attachment)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(auth.tenantLexicon.squadSingular) Notification")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SquadTaskDetailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let task: SquadTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(task.title)
                    .font(.title3.weight(.semibold))
                Text("Created \(task.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let dueDate = task.dueDate {
                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(task.details)
                    .font(.body)
                if let attachment = task.attachment {
                    AttachmentLinkView(attachment: attachment)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(auth.tenantLexicon.squadSingular) \(auth.tenantLexicon.taskSingular)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LearningDeckListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [LearningDeckItem]
    var onSelect: (LearningDeckItem) -> Void

    var body: some View {
        List(items) { item in
            NavigationLink {
                LearningDeckDetailView(item: item, onAppear: { onSelect(item) })
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                    Text(item.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Learning Deck")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

private struct DepartmentHubContainerView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        switch auth.userRole {
        case .agencyManager:
            AgencyManagerPortalView()
        case .admin:
            AdministratorPortalView()
        case .supervisor:
            SupervisorPortalView()
        case .nonSupervisor:
            OfficerDepartmentView()
        }
    }
}

private struct AgencyManagerPortalView: View {
    @EnvironmentObject private var auth: AuthViewModel

    private var permissions: Permissions { auth.permissions }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PortalHeaderView(
                        title: "Agency Manager",
                        subtitle: "Manage your agency’s DutyWire setup"
                    )
                }

                Section("Operations") {
                    NavigationLink(value: DepartmentDestination.vehicleRoster) {
                        ManagementActionRow(
                            title: "Manage Vehicle Roster",
                            detail: "Track assignments and maintenance.",
                            systemImage: "car.fill"
                        )
                    }
                    NavigationLink(value: DepartmentDestination.roster) {
                        ManagementActionRow(
                            title: "Manage Roster",
                            detail: "Review roster, edit profiles & assignments.",
                            systemImage: "person.crop.rectangle.stack.fill"
                        )
                    }
                }

                Section("Tools") {
                    NavigationLink(value: DepartmentDestination.audits) {
                        ManagementActionRow(
                            title: "Audits",
                            detail: "Audit past directed patrols and event signups.",
                            systemImage: "chart.bar.doc.horizontal"
                        )
                    }
                }

                if permissions.canManageTenantSecurity || permissions.canManagePushDevices {
                    Section("Security") {
                        if permissions.canManageTenantSecurity {
                            NavigationLink(value: DepartmentDestination.tenantSecurity) {
                                ManagementActionRow(
                                    title: "Tenant Security",
                                    detail: "View site keys, manage invites, review activity logs.",
                                    systemImage: "lock.shield.fill"
                                )
                            }
                        }
                        if permissions.canManagePushDevices {
                            NavigationLink(value: DepartmentDestination.pushDevices) {
                                ManagementActionRow(
                                    title: "Push Devices",
                                    detail: "Disable users’ registered phones and devices.",
                                    systemImage: "antenna.radiowaves.left.and.right"
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Agency Manager")
        }
        .navigationDestination(for: DepartmentDestination.self) { destination in
            departmentDestinationView(for: destination)
        }
    }
}

private struct AdministratorPortalView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PortalHeaderView(
                        title: "Admin Portal",
                        subtitle: "Run your agency’s operations"
                    )
                }

                Section("Operations") {
                    NavigationLink(value: DepartmentDestination.vehicleRoster) {
                        ManagementActionRow(
                            title: "Manage Vehicle Roster",
                            detail: "Track assignments and maintenance.",
                            systemImage: "car.fill"
                        )
                    }
                    NavigationLink(value: DepartmentDestination.roster) {
                        ManagementActionRow(
                            title: "Manage Roster",
                            detail: "Review roster, edit profiles & assignments.",
                            systemImage: "person.crop.rectangle.stack.fill"
                        )
                    }
                }

                Section("Tools") {
                    NavigationLink(value: DepartmentDestination.audits) {
                        ManagementActionRow(
                            title: "Audits",
                            detail: "Audit past directed patrols and event signups.",
                            systemImage: "chart.bar.doc.horizontal"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Admin Portal")
        }
        .navigationDestination(for: DepartmentDestination.self) { destination in
            departmentDestinationView(for: destination)
        }
    }
}

private struct SupervisorPortalView: View {
    @EnvironmentObject private var auth: AuthViewModel
    private var permissions: Permissions { auth.permissions }
    private var lexicon: TenantLexicon { auth.tenantLexicon }
    private var squadSingular: String { lexicon.squadSingular }
    private var squadLower: String { squadSingular.lowercased() }
    private var squadPluralLower: String { lexicon.squadPlural.lowercased() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PortalHeaderView(
                        title: "Supervisor Portal",
                        subtitle: "Lead your \(squadLower) and assignments"
                    )
                }

                Section("Team Ops") {
                    NavigationLink(value: DepartmentDestination.mySquad) {
                        ManagementActionRow(
                            title: "My \(squadSingular)",
                            detail: "Send updates and manage assignments.",
                            systemImage: "person.3.fill"
                        )
                    }
                }

                Section("Assignments") {
                    if permissions.canCreateDirectedPatrols {
                        NavigationLink(value: DepartmentDestination.directedPatrols) {
                            ManagementActionRow(
                                title: "Directed Patrols",
                                detail: "Create and track directed patrols.",
                                systemImage: "scope"
                            )
                        }
                    }
                    NavigationLink(value: DepartmentDestination.eventAssignments) {
                        ManagementActionRow(
                            title: "Event Assignments",
                            detail: "Manage event signups for your \(squadLower).",
                            systemImage: "calendar.badge.clock"
                        )
                    }
                }

                Section("Activity") {
                    NavigationLink(value: DepartmentDestination.squadActivity) {
                        ManagementActionRow(
                            title: "\(squadSingular) Activity",
                            detail: "Review patrols and event participation across your \(squadPluralLower).",
                            systemImage: "chart.bar.fill"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Supervisor Portal")
        }
        .navigationDestination(for: DepartmentDestination.self) { destination in
            departmentDestinationView(for: destination)
        }
    }
}

private struct OfficerDepartmentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    PortalHeaderView(
                        title: "Department Hub",
                        subtitle: "Stay informed on assignments and resources"
                    )
                }

                Section("Assignments") {
                    NavigationLink(value: DepartmentDestination.eventAssignments) {
                        ManagementActionRow(
                            title: "Event Sign Ups",
                            detail: "View available details and review your status.",
                            systemImage: "calendar"
                        )
                    }
                    NavigationLink(value: DepartmentDestination.directedPatrols) {
                        ManagementActionRow(
                            title: "Directed Patrols",
                            detail: "Complete patrols assigned to you.",
                            systemImage: "scope"
                        )
                    }
                }

                Section("Resources") {
                    NavigationLink(value: DepartmentDestination.vehicleRoster) {
                        ManagementActionRow(
                            title: "Vehicle Roster",
                            detail: "Check availability and status.",
                            systemImage: "car.2.fill"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Department Hub")
        }
        .navigationDestination(for: DepartmentDestination.self) { destination in
            departmentDestinationView(for: destination)
        }
    }
}

@ViewBuilder
private func departmentDestinationView(for destination: DepartmentDestination) -> some View {
    switch destination {
    case .manageSquads:
        SquadManagementListView()
    case .mySquad:
        MySquadView()
    case .vehicleRoster:
        VehicleRosterView()
    case .roster:
        DepartmentRosterAssignmentsView()
    case .audits:
        OvertimeAuditView()
    case .tenantSecurity:
        TenantSecurityCenterView()
    case .pushDevices:
        AdminPushDevicesView()
    case .directedPatrols:
        PatrolAssignmentsView()
    case .eventAssignments:
        OvertimeBoardView()
    case .squadActivity:
        SquadActivityArchiveView()
    }
}

private struct PortalHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        guard auth.permissions.canManagePushDevices else { return }
        await viewModel.load(orgId: auth.resolvedOrgId)
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

    private var orgId: String? { auth.resolvedOrgId }

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

    private var canEditRoster: Bool { auth.permissions.canManageRoster }

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(filteredAssignments) { assignment in
                let primarySquadName = viewModel.primarySquadName(for: assignment.profile.userId)
                if canEditRoster {
                    Button {
                        editingDraft = OfficerAssignmentDraft(from: assignment)
                    } label: {
                        OfficerRosterCardView(
                            assignment: assignment,
                            primarySquadName: primarySquadName,
                            lexicon: auth.tenantLexicon
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await deleteAssignment(assignment) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else {
                    OfficerRosterCardView(
                        assignment: assignment,
                        primarySquadName: primarySquadName,
                        lexicon: auth.tenantLexicon
                    )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
                .disabled(orgId == nil || !canEditRoster)
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
                    await deleteAssignment(id: draft.assignmentId!, userId: draft.userId)
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

    private func deleteAssignment(_ assignment: OfficerAssignmentDTO) async {
        await deleteAssignment(id: assignment.id, userId: assignment.profile.userId)
    }

    private func deleteAssignment(id: String, userId: String?) async {
        do {
            try await viewModel.delete(id: id)
            if let userId = userId?.nilIfEmpty {
                do {
                    try await deactivateMemberships(for: userId)
                    viewModel.clearPrimarySquad(for: userId)
                } catch {
                    alertMessage = "Officer removed, but squad memberships could not be updated: \(error.localizedDescription)"
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deactivateMemberships(for userId: String) async throws {
        let memberships = try await ShiftlinkAPI.listSquadMembershipsByUser(userId: userId, includeInactive: true)
        for membership in memberships where membership.isActive {
            _ = try await ShiftlinkAPI.updateSquadMembership(id: membership.id, isPrimary: false, isActive: false)
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
    let primarySquadName: String?
    let lexicon: TenantLexicon

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
                if let primarySquadName {
                    Text("Primary \(lexicon.squadSingular): \(primarySquadName)")
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
final class DepartmentRosterAssignmentsViewModel: ObservableObject {
    @Published var assignments: [OfficerAssignmentDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var primarySquadByUserId: [String: String] = [:]
    @Published var squads: [SquadDTO] = []
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
            async let assignmentsTask = ShiftlinkAPI.listAssignments(orgId: orgId)
            async let squadsTask = ShiftlinkAPI.listSquads(orgId: orgId, includeInactive: false)
            let assignmentRecords = try await assignmentsTask
            let squads = (try? await squadsTask) ?? []
            assignments = assignmentRecords
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            primarySquadByUserId = Self.makePrimarySquadIndex(from: squads)
            self.squads = squads
        } catch {
            errorMessage = error.localizedDescription
            assignments = []
            primarySquadByUserId = [:]
            squads = []
        }
    }

    fileprivate func save(draft: OfficerAssignmentDraft) async throws {
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

    func refreshSquadDetails(for squadId: String) async throws {
        guard let updated = try await ShiftlinkAPI.getSquad(id: squadId) else { return }
        replaceSquad(updated)
    }

    func addMembership(to squadId: String, userId: String, role: SquadRoleKind, makePrimary: Bool = false) async throws {
        let input = SquadMembershipInput(
            squadId: squadId,
            userId: userId,
            role: role,
            isPrimary: makePrimary,
            isActive: true
        )
        _ = try await ShiftlinkAPI.createSquadMembership(input: input)
        try await refreshSquadDetails(for: squadId)
    }

    func updateMembership(
        _ membership: SquadMembershipDTO,
        isPrimary: Bool? = nil,
        isActive: Bool? = nil,
        role: SquadRoleKind? = nil
    ) async throws {
        guard [isPrimary, isActive, role].contains(where: { $0 != nil }) else { return }
        _ = try await ShiftlinkAPI.updateSquadMembership(
            id: membership.id,
            role: role,
            isPrimary: isPrimary,
            isActive: isActive
        )
        try await refreshSquadDetails(for: membership.squadId)
    }

    func deleteMembership(_ membership: SquadMembershipDTO) async throws {
        try await ShiftlinkAPI.deleteSquadMembership(id: membership.id)
        try await refreshSquadDetails(for: membership.squadId)
    }

    func primarySquadName(for userId: String?) -> String? {
        guard let key = userId?.lowercased() else { return nil }
        return primarySquadByUserId[key]
    }

    func clearPrimarySquad(for userId: String) {
        primarySquadByUserId[userId.lowercased()] = nil
    }

    func squadAssignments(for userId: String?) -> [OfficerAssignmentDTO] {
        let memberIds = squadMemberUserIds(for: userId)
        guard !memberIds.isEmpty else { return [] }
        return assignments
            .filter { assignment in
                guard let normalized = assignment.profile.userId?.lowercased() else { return false }
                return memberIds.contains(normalized)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func makePrimarySquadIndex(from squads: [SquadDTO]) -> [String: String] {
        var mapping: [String: String] = [:]
        for squad in squads where squad.isActive {
            let memberships = squad.supervisorMemberships + squad.officerMemberships
            for membership in memberships where membership.isActive && membership.isPrimary {
                mapping[membership.userId.lowercased()] = squad.name
            }
        }
        return mapping
    }

    private func squadMemberUserIds(for userId: String?) -> Set<String> {
        guard let normalizedUserId = userId?.lowercased(), !normalizedUserId.isEmpty else { return [] }
        let squadsForUser = squads.filter { squad in
            squad.supervisorMemberships.contains(where: { $0.isActive && $0.userId.caseInsensitiveEquals(normalizedUserId) }) ||
            squad.officerMemberships.contains(where: { $0.isActive && $0.userId.caseInsensitiveEquals(normalizedUserId) })
        }

        var ids: Set<String> = []
        for squad in squadsForUser {
            let activeMemberships = (squad.supervisorMemberships + squad.officerMemberships).filter { $0.isActive }
            for membership in activeMemberships {
                ids.insert(membership.userId.lowercased())
            }
        }
        return ids
    }

    private func replaceSquad(_ squad: SquadDTO) {
        if let index = squads.firstIndex(where: { $0.id == squad.id }) {
            squads[index] = squad
        } else {
            squads.append(squad)
        }
        primarySquadByUserId = Self.makePrimarySquadIndex(from: squads)
    }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        localizedCaseInsensitiveCompare(other) == .orderedSame
    }
}

private struct SquadMembershipEditorView: View {
    @ObservedObject var viewModel: DepartmentRosterAssignmentsViewModel
    @Environment(\.dismiss) private var dismiss
    let onClose: () -> Void

    @State private var selectedSquadId: String?
    @State private var membershipRoleToAdd: SquadRoleKind?
    @State private var isPerformingAction = false
    @State private var showingAssignmentPicker = false
    @State private var membershipPendingDeletion: SquadMembershipDTO?
    @State private var alertMessage: String?
    let lexicon: TenantLexicon
    let orgId: String?

    init(
        viewModel: DepartmentRosterAssignmentsViewModel,
        lexicon: TenantLexicon,
        orgId: String?,
        onClose: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.lexicon = lexicon
        self.orgId = orgId
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading && viewModel.squads.isEmpty {
                VStack(spacing: 12) {
                    ProgressView("Loading \(lexicon.squadPlural)…")
                        .progressViewStyle(.circular)
                    Text("Fetching \(lexicon.squadPlural.lowercased()) for your agency.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if viewModel.squads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No \(lexicon.squadPlural)")
                        .font(.headline)
                    Text("Create a \(lexicon.squadSingular.lowercased()) in Amplify Studio to manage its memberships.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                Picker(lexicon.squadSingular, selection: $selectedSquadId) {
                    ForEach(viewModel.squads) { squad in
                        Text("\(squad.name) – \(squad.shift ?? "No shift")")
                            .tag(squad.id as String?)
                    }
                }
                .pickerStyle(.menu)

                if let squad = selectedSquad {
                    membershipSection(
                        title: "Supervisors",
                        memberships: squad.supervisorMemberships,
                        role: .supervisor
                    )

                    membershipSection(
                        title: "Officers",
                        memberships: squad.officerMemberships,
                        role: .officer
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.sequence")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Select a \(lexicon.squadSingular)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Manage \(lexicon.squadSingular)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                    onClose()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isPerformingAction {
                    ProgressView()
                }
            }
        }
        .onAppear {
            if selectedSquadId == nil {
                selectedSquadId = viewModel.squads.first?.id
            }
            if viewModel.squads.isEmpty && !viewModel.isLoading {
                Task {
                    await viewModel.load(orgId: orgId)
                }
            }
        }
        .onChange(of: viewModel.squads) { _, squads in
            if let currentId = selectedSquadId,
               squads.contains(where: { $0.id == currentId }) {
                return
            }
            selectedSquadId = squads.first?.id
        }
        .sheet(isPresented: $showingAssignmentPicker) {
            NavigationStack {
                List {
                    if selectableAssignments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.exclam")
                                .font(.title)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                            Text("No linked officers are available to add right now.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(selectableAssignments) { assignment in
                            Button {
                                addAssignmentToSquad(assignment)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(assignment.displayName)
                                        .font(.headline)
                                    Text(assignment.assignmentDisplay)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                    if let existing = viewModel.primarySquadName(for: assignment.profile.userId) {
                        Text("Current \(lexicon.squadSingular): \(existing)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle(addMemberSheetTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showingAssignmentPicker = false
                            membershipRoleToAdd = nil
                        }
                    }
                }
            }
        }
        .alert("Manage \(lexicon.squadSingular)", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog(
            "Remove this member from the \(lexicon.squadSingular.lowercased())?",
            isPresented: Binding(
                get: { membershipPendingDeletion != nil },
                set: { if !$0 { membershipPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Member", role: .destructive) {
                guard let membership = membershipPendingDeletion else { return }
                runMembershipMutation {
                    try await viewModel.deleteMembership(membership)
                }
                membershipPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { membershipPendingDeletion = nil }
        }
    }

    private var selectedSquad: SquadDTO? {
        guard let selectedSquadId else { return viewModel.squads.first }
        return viewModel.squads.first { $0.id == selectedSquadId }
    }

    @ViewBuilder
    private func membershipSection(title: String, memberships: [SquadMembershipDTO], role: SquadRoleKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    membershipRoleToAdd = role
                    showingAssignmentPicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .disabled(!canAddMembers)
                .opacity(canAddMembers ? 1 : 0.35)
            }

            if memberships.isEmpty {
                Text("No \(title.lowercased()) yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(memberships, id: \.id) { membership in
                        membershipRow(for: membership)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func membershipRow(for membership: SquadMembershipDTO) -> some View {
        let info = memberInfo(for: membership)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(info.name)
                    .font(.headline)
                Spacer()
            }
            if !info.detail.isEmpty {
                Text(info.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("User ID: \(membership.userId)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                statusBadges(for: membership)
                Spacer()
                Menu {
                    if !membership.isPrimary {
                        Button("Mark as Primary") {
                            handlePrimaryChange(for: membership, isPrimary: true)
                        }
                    } else {
                        Button("Clear Primary") {
                            handlePrimaryChange(for: membership, isPrimary: false)
                        }
                    }
                    Button(membership.isActive ? "Deactivate" : "Activate") {
                        handleToggleActive(membership)
                    }
                    Divider()
                        Button("Remove from \(lexicon.squadSingular)", role: .destructive) {
                            membershipPendingDeletion = membership
                        }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                        .padding(.leading, 4)
                }
                .disabled(isPerformingAction)
                .tint(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func memberInfo(for membership: SquadMembershipDTO) -> (name: String, detail: String) {
        if let assignment = viewModel.assignments.first(where: {
            $0.profile.userId?.caseInsensitiveEquals(membership.userId) ?? false
        }) {
            return (assignment.displayName, assignment.assignmentDisplay)
        }
        return ("Unknown member", "")
    }

    private var selectableAssignments: [OfficerAssignmentDTO] {
        guard let squad = selectedSquad else { return [] }
        let existingIds = Set((squad.supervisorMemberships + squad.officerMemberships).map { $0.userId.lowercased() })
        return viewModel.assignments
            .filter { assignment in
                guard let normalized = assignment.profile.userId?.lowercased(), !normalized.isEmpty else { return false }
                return !existingIds.contains(normalized)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var addMemberSheetTitle: String {
        let roleName = membershipRoleToAdd?.displayName ?? "Member"
        return "Add \(roleName)"
    }

    private var canAddMembers: Bool {
        selectedSquad != nil && !selectableAssignments.isEmpty && !isPerformingAction
    }

    private func addAssignmentToSquad(_ assignment: OfficerAssignmentDTO) {
        guard let squad = selectedSquad else {
            alertMessage = "Select a \(lexicon.squadSingular.lowercased()) before adding members."
            return
        }
        guard let role = membershipRoleToAdd else {
            alertMessage = "Choose a role before adding members."
            return
        }
        guard let userId = assignment.profile.userId?.nilIfEmpty else {
            alertMessage = "This assignment is not linked to a DutyWire user."
            return
        }
        runMembershipMutation {
            try await viewModel.addMembership(to: squad.id, userId: userId, role: role, makePrimary: false)
        } onSuccess: {
            showingAssignmentPicker = false
            membershipRoleToAdd = nil
        }
    }

    private func handlePrimaryChange(for membership: SquadMembershipDTO, isPrimary: Bool) {
        runMembershipMutation {
            try await viewModel.updateMembership(membership, isPrimary: isPrimary)
        }
    }

    private func handleToggleActive(_ membership: SquadMembershipDTO) {
        runMembershipMutation {
            try await viewModel.updateMembership(membership, isActive: !membership.isActive)
        }
    }

    @ViewBuilder
    private func statusBadges(for membership: SquadMembershipDTO) -> some View {
        HStack(spacing: 6) {
            if !membership.isActive {
                Text("Inactive")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2), in: Capsule())
            }
            if membership.isPrimary {
                Text("Primary")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15), in: Capsule())
            }
        }
    }

    private func runMembershipMutation(
        _ work: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        Task {
            do {
                try await work()
                if let onSuccess {
                    await MainActor.run {
                        onSuccess()
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.userFacingMessage
                }
            }
            await MainActor.run {
                isPerformingAction = false
            }
        }
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
                    Button("Refresh") { Task { await auth.refreshInbox() } }
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
                    LabeledContent("Rank", value: auth.userProfile.rank ?? auth.primaryRoleDisplayName ?? auth.userRole.displayName)
                    LabeledContent("Org ID", value: auth.resolvedOrgId ?? "—")
                    LabeledContent("Site Key", value: auth.userProfile.siteKey ?? "—")
                    LabeledContent("Status", value: auth.isAuthenticated ? "Signed In" : "Signed Out")
                    LabeledContent("Department Role", value: auth.userRole.displayName)
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
            Toggle("New Special Detail Posts", isOn: $draft.overtime)
            Toggle("\(auth.tenantLexicon.squadSingular) Messages", isOn: $draft.squadMessages)
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
            Image("dutywirelogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(.bottom, 4)

            Text("Built for the way cops actually work and live.")
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
    @Published var userRole: UserRole = .nonSupervisor
    @Published var permissions = Permissions.configuration(for: .nonSupervisor)
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

    var tenantLexicon: TenantLexicon {
        activeTenant?.lexicon ?? .standard
    }

    var resolvedOrgId: String? {
        if let orgId = userProfile.orgID?.nilIfEmpty {
            return normalizedOrgId(orgId)
        }
        if let tenantOrgId = activeTenant?.orgId.nilIfEmpty {
            return normalizedOrgId(tenantOrgId)
        }
        return nil
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
                await refreshInbox()
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
        guard item.isRemote,
              let orgId = resolvedOrgId,
              let rawUserId = currentUser?.userId,
              let userId = rawUserId.nilIfEmpty else { return }
        Task {
            _ = try? await ShiftlinkAPI.markNotificationRead(notificationId: item.id, orgId: orgId, userId: userId)
        }
    }

    @discardableResult
    func enqueueInboxMessage(
        id overrideId: String? = nil,
        title: String,
        body: String,
        feedType: FeedPayloadType?
    ) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedBody.isEmpty else { return overrideId ?? UUID().uuidString }
        let identifier = overrideId ?? UUID().uuidString
        let message = NotificationItem(
            id: identifier,
            title: trimmedTitle.isEmpty ? "New Message" : trimmedTitle,
            body: trimmedBody.isEmpty ? "No description provided." : trimmedBody,
            sentAt: Date(),
            isRead: false,
            feedType: feedType,
            isRemote: false
        )
        notifications.insert(message, at: 0)
        return identifier
    }

    func markNotificationRead(withId id: String) {
        guard let item = notifications.first(where: { $0.id == id }) else { return }
        markNotificationRead(item)
    }

    func deleteNotification(_ item: NotificationItem) {
        notifications.removeAll { $0.id == item.id }
    }

    func refreshInbox() async {
        guard let orgId = resolvedOrgId else {
            notifications = []
            return
        }
        let currentUserId = (currentUser?.userId)?.nilIfEmpty
        do {
            let receipts = try await fetchNotificationReceipts()
            let readSet = Set(receipts.filter { $0.isRead }.map { $0.notificationId })
            async let actionRecordsTask = ShiftlinkAPI.listNotificationMessages(
                orgId: orgId,
                category: .taskAlert,
                limit: 50
            )
            async let learningRecordsTask = ShiftlinkAPI.listNotificationMessages(
                orgId: orgId,
                category: .bulletin,
                limit: 50
            )
            async let squadRecordsTask = ShiftlinkAPI.listNotificationMessages(
                orgId: orgId,
                category: .squadAlert,
                limit: 80
            )
            let actionRecords = try await actionRecordsTask
            let learningRecords = try await learningRecordsTask
            let squadRecordsRaw = try await squadRecordsTask
            let squadRecords = squadRecordsRaw.filter { squadRecordTargetsUser($0, userId: currentUserId) }
            let combined = (actionRecords + learningRecords + squadRecords)
                .filter { feedType(from: $0.metadata) != nil }
                .sorted { lhs, rhs in
                    let left = lhs.createdAt.flatMap { ShiftlinkAPI.parse(dateString: $0) } ?? .distantPast
                    let right = rhs.createdAt.flatMap { ShiftlinkAPI.parse(dateString: $0) } ?? .distantPast
                    return left > right
                }
            notifications = combined.compactMap { record -> NotificationItem? in
                guard let payloadType = feedType(from: record.metadata) else { return nil }
                return NotificationItem(
                    id: record.id,
                    title: record.title,
                    body: record.body,
                    sentAt: record.createdAt.flatMap { ShiftlinkAPI.parse(dateString: $0) } ?? Date(),
                    isRead: readSet.contains(record.id),
                    feedType: payloadType,
                    isRemote: true
                )
            }
        } catch {
            notifications = []
            print("[DutyWire] Inbox refresh failed:", error)
        }
    }

    private func fetchNotificationReceipts() async throws -> [NotificationReceiptRecord] {
        guard
            let rawUserId = currentUser?.userId,
            let userId = rawUserId.nilIfEmpty
        else { return [] }
        return try await ShiftlinkAPI.fetchNotificationReceiptsForUser(userId: userId, limit: 200)
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
                    profile.orgID = normalizedOrgId(attribute.value)
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

            let storedSiteKey = storedSiteKeyValue()
            let storedOrgID = storedOrgIDValue()

            if (profile.siteKey?.isEmpty ?? true), let storedSiteKey {
                profile.siteKey = storedSiteKey
                await persistSiteKeyAttributeIfMissing(storedSiteKey)
            } else if let siteKey = profile.siteKey, !siteKey.isEmpty {
                cacheSiteKey(siteKey)
            }

            if profile.orgID?.isEmpty ?? true {
                if let storedOrgID {
                    let normalized = normalizedOrgId(storedOrgID)
                    profile.orgID = normalized
                    await persistOrgIDAttributeIfMissing(normalized)
                } else if let tenant = TenantRegistry.shared.resolveTenant(
                    siteKey: profile.siteKey ?? storedSiteKey,
                    orgId: nil,
                    email: profile.email
                ) {
                    let resolvedOrgId = tenant.orgId
                    profile.orgID = resolvedOrgId
                    cacheOrgID(resolvedOrgId)
                    await persistOrgIDAttributeIfMissing(resolvedOrgId)
                }
            } else if let orgID = profile.orgID, !orgID.isEmpty {
                let normalized = normalizedOrgId(orgID)
                profile.orgID = normalized
                cacheOrgID(normalized)
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
            let orgId = resolvedOrgId,
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
        guard let raw = UserDefaults.standard.string(forKey: "shiftlink.orgID")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return normalizedOrgId(raw)
    }

    private func cacheOrgID(_ value: String) {
        let normalized = normalizedOrgId(value)
        UserDefaults.standard.set(normalized, forKey: "shiftlink.orgID")
    }

    private func persistOrgIDAttributeIfMissing(_ orgID: String) async {
        let normalized = normalizedOrgId(orgID)
        guard !normalized.isEmpty else { return }
        do {
            let attribute = AuthUserAttribute(.custom("orgID"), value: normalized)
            _ = try await Amplify.Auth.update(userAttributes: [attribute])
        } catch {
            print("Failed to persist orgID attribute:", error)
        }
    }

    private func normalizedOrgId(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
            let orgId = resolvedOrgId,
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
            let resolvedRole = UserRole.highestRole(from: normalizedGroups)
            applyRole(resolvedRole)
            if let primary = groups.first {
                primaryRole = RoleLabels.displayName(for: primary)
            } else {
                primaryRole = resolvedRole.displayName
            }
        case .failure:
            clearPrivileges()
        }
    }

    private func clearPrivileges() {
        applyRole(.nonSupervisor)
        primaryRole = nil
    }

    private func applyRole(_ role: UserRole) {
        userRole = role
        permissions = Permissions.configuration(for: role)
        isAdmin = role == .agencyManager || role == .admin
        isSupervisor = role == .agencyManager || role == .admin || role == .supervisor
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
            let orgId = resolvedOrgId
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
    var badgeNumber: String?
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
    let id: String
    var title: String
    var body: String
    var sentAt: Date
    var isRead: Bool
    var feedType: FeedPayloadType?
    var isRemote: Bool
}

extension Date {
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Placeholder Destination Views

struct PlaceholderPane: View {
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
        .background(CalendarBackgroundView().ignoresSafeArea())
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

private enum DirectedPatrolScope: String, CaseIterable, Identifiable {
    case shift
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shift: return "My Shift"
        case .week: return "My Week"
        }
    }
}

private enum DirectedPatrolCategory {
    case directed
    case traffic
    case beat

    var label: String {
        switch self {
        case .directed: return "Directed Patrol"
        case .traffic: return "Traffic Detail"
        case .beat: return "Beat Patrol"
        }
    }

    var tint: Color {
        switch self {
        case .directed: return Color.blue
        case .traffic: return Color.orange
        case .beat: return Color.purple
        }
    }
}

private enum DirectedPatrolStatus {
    case active
    case upcoming
    case completed

    var label: String {
        switch self {
        case .active: return "Active"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        }
    }

    var background: Color {
        switch self {
        case .active: return Color.green.opacity(0.15)
        case .upcoming: return Color.gray.opacity(0.15)
        case .completed: return Color.blue.opacity(0.15)
        }
    }

    var foreground: Color {
        switch self {
        case .active: return Color.green
        case .upcoming: return Color.gray
        case .completed: return Color.blue
        }
    }
}

private enum DirectedPatrolAction: String {
    case startShift
    case logActivity
    case completeShift

    var label: String {
        switch self {
        case .startShift: return "Start Shift"
        case .logActivity: return "Log Activity"
        case .completeShift: return "Complete"
        }
    }

    var background: Color {
        switch self {
        case .logActivity:
            return Color(.systemBackground)
        default:
            return Color.blue
        }
    }

    var foreground: Color {
        switch self {
        case .logActivity:
            return Color.primary
        default:
            return .white
        }
    }

    var borderColor: Color? {
        switch self {
        case .logActivity:
            return Color(.systemGray4)
        default:
            return nil
        }
    }
}

private struct DirectedPatrolAssignment: Identifiable {
    let entry: ShiftScheduleEntry

    var id: String {
        entry.calendarEventId ?? entry.id.uuidString
    }

    var category: DirectedPatrolCategory {
        DirectedPatrolCategory(entry: entry)
    }

    var title: String { entry.assignment }

    var timeWindow: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let day = dateFormatter.string(from: entry.start)
        let range = "\(timeFormatter.string(from: entry.start))–\(timeFormatter.string(from: entry.end)) hrs"
        if Calendar.current.isDate(entry.start, inSameDayAs: Date()) {
            return "\(entry.start.formatted(date: .omitted, time: .shortened))–\(entry.end.formatted(date: .omitted, time: .shortened)) hrs"
        }
        return "\(day) • \(range)"
    }

    var assignmentLine: String {
        if !entry.location.isEmpty && !entry.detail.isEmpty {
            return "\(entry.location) • \(entry.detail)"
        } else if !entry.location.isEmpty {
            return entry.location
        } else if !entry.detail.isEmpty {
            return entry.detail
        } else {
            return "Personal schedule entry"
        }
    }

    var note: String? {
        entry.detail.isEmpty ? nil : entry.detail
    }
}

private extension DirectedPatrolCategory {
    init(entry: ShiftScheduleEntry) {
        let normalized = entry.assignment.lowercased()
        if normalized.contains("traffic") || normalized.contains("detail") {
            self = .traffic
        } else if normalized.contains("sector") || normalized.contains("beat") {
            self = .beat
        } else {
            self = .directed
        }
    }
}


private struct PatrolAssignmentsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var calendarViewModel = MyCalendarViewModel()
    @State private var scope: DirectedPatrolScope = .shift
    @State private var actionMessage: String?
    @State private var showingCreateSheet = false
    @State private var editingEntry: ShiftScheduleEntry?
    @State private var workflowStates: [String: PatrolWorkflowState] = [:]

    private enum PatrolWorkflowState {
        case idle
        case onDuty(Date)
        case logged(Date)
        case completed(Date)
    }

    private var ownerIdentifiers: [String] {
        auth.calendarOwnerIdentifiers
    }

    private var patrolEntries: [ShiftScheduleEntry] {
        calendarViewModel.entries.filter { $0.kind == .patrol }
    }

    private var assignments: [DirectedPatrolAssignment] {
        guard !ownerIdentifiers.isEmpty else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        let limitDate = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        return patrolEntries
            .filter { entry in
                switch scope {
                case .shift:
                    return Calendar.current.isDate(entry.start, inSameDayAs: Date())
                case .week:
                    return entry.start >= today && entry.start <= limitDate
                }
            }
            .sorted { $0.start < $1.start }
            .map { DirectedPatrolAssignment(entry: $0) }
    }

    private var canCreateAssignments: Bool {
        auth.primaryCalendarOwnerIdentifier != nil
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.36, blue: 0.59),
                    Color(red: 0.11, green: 0.25, blue: 0.47)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    assignmentsSection
                    if calendarViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 12)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Directed Patrols")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Directed Patrols",
            isPresented: Binding(
                get: { actionMessage != nil },
                set: { if !$0 { actionMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
        .task { await loadAssignments() }
        .refreshable { await loadAssignments() }
        .sheet(isPresented: $showingCreateSheet) {
            AddCalendarEventSheet(
                focusDate: Date(),
                defaultCategory: .shift
            ) { input in
                guard let ownerId = auth.primaryCalendarOwnerIdentifier else {
                    actionMessage = "Unable to determine your DutyWire calendar ID."
                    return
                }
                try await calendarViewModel.addEvent(ownerId: ownerId, orgId: auth.resolvedOrgId, input: input)
                await loadAssignments()
            }
        }
        .sheet(item: $editingEntry) { entry in
            if let eventId = entry.calendarEventId {
                EditCalendarEventSheet(
                    entry: entry,
                    onSave: { input in
                        let owner = entry.ownerId ?? auth.primaryCalendarOwnerIdentifier
                        guard let ownerId = owner else {
                            actionMessage = "Unable to resolve the event owner. Refresh and try again."
                            return
                        }
                        try await calendarViewModel.updateEvent(ownerId: ownerId, eventId: eventId, input: input)
                        await loadAssignments()
                    },
                    onDelete: {
                        try await calendarViewModel.deleteEvent(eventId: eventId)
                        workflowStates.removeValue(forKey: entry.calendarEventId ?? entry.id.uuidString)
                        await loadAssignments()
                    }
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Picker("Scope", selection: $scope) {
                ForEach(DirectedPatrolScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Button {
                showingCreateSheet = true
            } label: {
                Text("+ New")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!canCreateAssignments)
            .opacity(canCreateAssignments ? 1 : 0.5)
        }
    }

    @ViewBuilder
    private var assignmentsSection: some View {
        if assignments.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))
                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            )
        } else {
            VStack(spacing: 14) {
                ForEach(assignments) { assignment in
                    DirectedPatrolCard(
                        assignment: assignment,
                        status: status(for: assignment),
                        action: primaryAction(for: assignment),
                        onAction: {
                            if let action = primaryAction(for: assignment) {
                                handleAction(action, for: assignment)
                            }
                        },
                        onOpenDetails: {
                            editingEntry = assignment.entry
                        }
                    )
                }
            }
        }
    }

    private var emptyStateTitle: String {
        if ownerIdentifiers.isEmpty {
            return "Calendar profile required"
        }
        return "No patrol assignments scheduled."
    }

    private var emptyStateSubtitle: String {
        if ownerIdentifiers.isEmpty {
            return "Ask an administrator to link your badge number to your DutyWire calendar so patrols can sync automatically."
        }
        return "Add patrol entries to your private calendar or ask a supervisor to share the upcoming detail schedule."
    }

    @MainActor
    private func loadAssignments() async {
        guard !ownerIdentifiers.isEmpty else {
            workflowStates.removeAll()
            return
        }
        await calendarViewModel.load(ownerIds: ownerIdentifiers)
    }

    private func status(for assignment: DirectedPatrolAssignment) -> DirectedPatrolStatus {
        if let state = workflowStates[assignment.id], case .completed = state {
            return .completed
        }
        let now = Date()
        if now < assignment.entry.start {
            return .upcoming
        }
        if now > assignment.entry.end {
            return .completed
        }
        return .active
    }

    private func primaryAction(for assignment: DirectedPatrolAssignment) -> DirectedPatrolAction? {
        let state = workflowStates[assignment.id] ?? .idle
        let runtime = status(for: assignment)
        switch state {
        case .completed:
            return nil
        case .logged:
            return .completeShift
        case .onDuty:
            return runtime == .completed ? .completeShift : .logActivity
        case .idle:
            return runtime == .completed ? nil : .startShift
        }
    }

    private func handleAction(_ action: DirectedPatrolAction, for assignment: DirectedPatrolAssignment) {
        let id = assignment.id
        switch action {
        case .startShift:
            workflowStates[id] = .onDuty(Date())
            actionMessage = "\(assignment.title) marked as started."
        case .logActivity:
            workflowStates[id] = .logged(Date())
            actionMessage = "Logged activity for \(assignment.title)."
        case .completeShift:
            workflowStates[id] = .completed(Date())
            actionMessage = "\(assignment.title) marked complete."
        }
    }
}
private struct DirectedPatrolCard: View {
    let assignment: DirectedPatrolAssignment
    let status: DirectedPatrolStatus
    let action: DirectedPatrolAction?
    let onAction: () -> Void
    let onOpenDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(assignment.category.label.uppercased())
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(assignment.category.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(assignment.category.tint)
                Spacer()
                Text(status.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status.background, in: Capsule())
                    .foregroundStyle(status.foreground)
            }

            Text(assignment.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.timeWindow)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(assignment.assignmentLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let note = assignment.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                if let action {
                    DirectedPatrolActionButton(action: action, perform: onAction)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .onTapGesture { onOpenDetails() }
    }
}

private struct DirectedPatrolActionButton: View {
    let action: DirectedPatrolAction
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            Text(action.label)
                .font(.headline)
                .foregroundColor(action.foreground)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(action.background)
                )
                .overlay {
                    if let border = action.borderColor {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct VehicleRosterView: View {
    var body: some View {
        PlaceholderPane(
            title: "Vehicle Roster",
            systemImage: "car.fill",
            message: "Vehicle management is coming soon for DutyWire agencies."
        )
    }
}

private struct SendDepartmentAlertView: View {
    var body: some View {
        PlaceholderPane(
            title: "Department Alerts",
            systemImage: "megaphone.fill",
            message: "Broadcast messaging is being updated for the new special detail workflow."
        )
    }
}

private struct ShiftTemplateLibraryView: View {
    var body: some View {
        PlaceholderPane(
            title: "Shift Templates",
            systemImage: "calendar.badge.plus",
            message: "Reusable shift templates will be re-enabled after the ongoing revamp."
        )
    }
}

private struct SquadActionButtonStyle: ButtonStyle {
    var tint: Color = Color.blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? tint.opacity(0.85) : tint)
            )
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct MyLockerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                lockerHeader

                // WELLBEING & MONEY
                lockerSection("WELLBEING & MONEY") {
                    HStack(spacing: 14) {
                        lockerCard(
                            icon: "heart.fill",
                            title: "Health & Wellness",
                            subtitle: "Create workouts, track moods, sleep, and more.",
                            destination: .wellness
                        )
                        lockerCard(
                            icon: "dollarsign.circle.fill",
                            title: "Savings & Budget",
                            subtitle: "Create a budget, set a goal.",
                            destination: .savings
                        )
                    }
                }

                // NOTES & JOURNAL
                lockerSection("NOTES & JOURNAL") {
                    lockerCard(
                        icon: "pencil.and.list.clipboard",
                        title: "Make a note or set a reminder",
                        subtitle: nil,
                        destination: .notes,
                        expands: true
                    )
                }

                // CAREER & GROWTH
                lockerSection("CAREER & GROWTH") {
                    HStack(spacing: 14) {
                        lockerCard(
                            icon: "checkmark.seal.fill",
                            title: "Certifications",
                            subtitle: "Dont rely on paper, keep track here",
                            destination: .certifications
                        )
                        lockerCard(
                            icon: "briefcase.fill",
                            title: "Evaluations",
                            subtitle: "Keep records of your performance and career",
                            destination: .evaluations
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 16)
        }

        .background(CalendarBackgroundView().ignoresSafeArea())
        .navigationTitle("My Locker")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func lockerSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
        }
    }

    private var lockerHeader: some View {
        // Match the simple lock + text line from your mockup
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundColor(.yellow)
            Text("Private - Only visible to you")
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 4)
    }

    private func lockerCard(
        icon: String,
        title: String,
        subtitle: String?,
        destination: LockerDestination,
        expands: Bool = false
    ) -> some View {
        NavigationLink {
            destinationView(for: destination)
        } label: {
            LockerNavigationCard(
                icon: icon,
                title: title,
                subtitle: subtitle,
                expands: expands
            )
        }
        .buttonStyle(.plain)
    }

    private func destinationView(for destination: LockerDestination) -> some View {
        switch destination {
        case .notes:
            return AnyView(LockerNotesHomeView())
        case .certifications:
            return AnyView(LockerCertificationsHomeView())
        case .evaluations:
            return AnyView(LockerEvaluationsHomeView())
        case .savings:
            return AnyView(MoneyGoalsDashboardView())
        case .wellness:
            return AnyView(LockerWellnessHomeView())
        }
    }
}


private enum LockerDestination {
    case notes, certifications, evaluations, savings, wellness
}

private struct LockerNavigationCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    var expands: Bool = false

    var body: some View {
        Group {
            if expands {
                // Full-width Notes card from your mock (icon left, big text)
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.blue)

                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            } else {
                // Two-column cards: icon on top, centered title + subtitle
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.blue)

                    Text(title)
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, minHeight: expands ? 68 : 130)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.6), lineWidth: 1)
        )
        // remove or keep this – your mock has almost no shadow
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}


private struct LockerPlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                Text("Coming soon")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(CalendarBackgroundView().ignoresSafeArea())
    }
}

// MARK: - Locker Notes Workflow

private struct LockerNotesHomeView: View {
    @StateObject private var viewModel = LockerNotesViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: LockerNotesFilter = .all
    @State private var editorMode: LockerNoteEditorMode?
    @State private var selectionMode = false
    @State private var selectedIDs: Set<LockerNote.ID> = []
    @State private var showDeleteDialog = false
    @State private var showTagPicker = false
    @State private var toastMessage: String?

    private var filteredNotes: [LockerNote] {
        let base = viewModel.notes.filter { selectedFilter.matches($0) }
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return base }
        return base.filter { note in
            note.trimmedTitle.lowercased().contains(term) ||
            note.body.lowercased().contains(term) ||
            (note.caseReference?.lowercased().contains(term) ?? false)
        }
    }

    private var pinnedNotes: [LockerNote] {
        filteredNotes.filter { $0.isPinned }
    }

    private var regularNotes: [LockerNote] {
        filteredNotes.filter { !$0.isPinned }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                notesHeader
                searchField
                filterChips
                notesList
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            ZStack {
                Image("mynotesbackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color(.systemGroupedBackground)
                    .opacity(0.8)
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create(.quick)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("New note")
            }
            ToolbarItem(placement: .topBarLeading) {
                if selectionMode {
                    Button("Cancel") {
                        selectionMode = false
                        selectedIDs.removeAll()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selectionMode {
                LockerSelectionToolbar(
                    count: selectedIDs.count,
                    onArchive: { viewModel.archive(ids: selectedIDs); exitSelectionMode() },
                    onDelete: { showDeleteDialog = true },
                    onTag: { showTagPicker = true },
                    onPin: { viewModel.togglePin(ids: selectedIDs); exitSelectionMode() }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(item: $editorMode) { mode in
            LockerNoteEditorView(mode: mode, viewModel: viewModel) { message in
                toastMessage = message
            }
        }
        .sheet(isPresented: $showTagPicker) {
            LockerTagSelectionView(initialSelection: [], onSave: { tags in
                viewModel.add(tags: tags, to: selectedIDs)
                exitSelectionMode()
            })
        }
        .confirmationDialog(
            "Delete selected notes?",
            isPresented: $showDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.delete(ids: selectedIDs)
                exitSelectionMode()
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { self.toastMessage = nil }
                        }
                    }
            }
        }
    }

    private var notesHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Private to you. Not visible to your agency.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search notes…", text: $searchText)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.8)
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LockerNotesFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.callout.weight(.semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(filter == selectedFilter ? Color.blue.opacity(0.2) : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var notesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if pinnedNotes.isEmpty && regularNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No notes yet.")
                        .font(.headline)
                    Text("Tap the plus icon to start a private note. Pinned notes will appear here first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if !pinnedNotes.isEmpty {
                    Text("Pinned")
                        .font(.headline)
                    ForEach(pinnedNotes) { note in
                        noteRow(for: note)
                    }
                }
                if !regularNotes.isEmpty {
                    if !pinnedNotes.isEmpty {
                        Text("All Notes")
                            .font(.headline)
                    }
                    ForEach(regularNotes) { note in
                        noteRow(for: note)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func noteRow(for note: LockerNote) -> some View {
        NavigationLink {
            LockerNoteDetailView(noteID: note.id, viewModel: viewModel) { message in
                toastMessage = message
            }
        } label: {
            LockerNoteRow(
                note: note,
                isSelected: selectedIDs.contains(note.id),
                selectionMode: selectionMode
            )
        }
        .disabled(selectionMode)
        .simultaneousGesture(LongPressGesture().onEnded { _ in
            guard !selectionMode else { return }
            selectionMode = true
            selectedIDs = [note.id]
        })
        .simultaneousGesture(TapGesture().onEnded {
            if selectionMode {
                if selectedIDs.contains(note.id) {
                    selectedIDs.remove(note.id)
                    if selectedIDs.isEmpty {
                        selectionMode = false
                    }
                } else {
                    selectedIDs.insert(note.id)
                }
            }
        })
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin") {
                viewModel.togglePin(ids: [note.id])
            }
            Button(note.isArchived ? "Restore from Archive" : "Archive") {
                viewModel.archive(ids: [note.id], archived: !note.isArchived)
            }
            Button("Duplicate Note") {
                viewModel.duplicate(note: note)
            }
            Button("Delete", role: .destructive) {
                selectedIDs = [note.id]
                showDeleteDialog = true
                selectionMode = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                viewModel.delete(ids: [note.id])
            }
            if !selectionMode {
                Button("Edit") {
                    editorMode = .edit(note)
                }
                .tint(.blue)
            }
        }
    }

    private func exitSelectionMode() {
        selectionMode = false
        selectedIDs.removeAll()
    }
}

private struct LockerNoteRow: View {
    let note: LockerNote
    let isSelected: Bool
    let selectionMode: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if selectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : Color(.systemGray4))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.trimmedTitle)
                        .font(.headline)
                    Spacer()
                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(note.previewText)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    ForEach(note.tags.prefix(2), id: \.id) { tag in
                        Text(tag.displayName)
                            .font(.caption)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(tag.tint.opacity(0.15), in: Capsule())
                    }
                    if note.tags.count > 2 {
                        Text("+\(note.tags.count - 2)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if note.reminderDate != nil {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .padding(.horizontal, 2)
    }
}

private struct LockerNoteDetailView: View {
    let noteID: LockerNote.ID
    @ObservedObject var viewModel: LockerNotesViewModel
    let onAction: (String) -> Void
    @State private var editorMode: LockerNoteEditorMode?
    @State private var showTagPicker = false
    @State private var showDeleteDialog = false

    private var note: LockerNote? {
        viewModel.note(with: noteID)
    }

    var body: some View {
        Group {
            if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(note.trimmedTitle)
                            .font(.title.bold())
                        if let caseReference = note.caseReference, !caseReference.isEmpty {
                            Label("Case / Ref: \(caseReference)", systemImage: "number")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if !note.tags.isEmpty {
                            AdaptiveTagGrid(data: note.tags) { tag in
                                Text(tag.displayName)
                                    .font(.caption.weight(.semibold))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(tag.tint.opacity(0.2), in: Capsule())
                            }
                        }
                        Text(note.body.isEmpty ? "No text in this note yet." : note.body)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Created: \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Last updated: \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let reminder = note.reminderDate {
                                Label("Reminder: \(reminder.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            editorMode = .edit(note)
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        Button {
                            viewModel.togglePin(ids: [note.id])
                            onAction(note.isPinned ? "Note unpinned" : "Note pinned")
                        } label: {
                            Image(systemName: note.isPinned ? "pin.slash" : "pin")
                        }
                        Menu {
                            Button("Add / Change Reminder") {
                                editorMode = .edit(note)
                            }
                            Button("Duplicate Note") {
                                viewModel.duplicate(note: note)
                                onAction("Note duplicated")
                            }
                            Button(note.isArchived ? "Restore from Archive" : "Move to Archive") {
                                viewModel.archive(ids: [note.id], archived: !note.isArchived)
                                onAction(note.isArchived ? "Note restored" : "Note archived")
                            }
                            Button("Add Tags") {
                                showTagPicker = true
                            }
                            ShareLink(item: note.exportText) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            Button("Delete", role: .destructive) {
                                showDeleteDialog = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(item: $editorMode) { mode in
                    LockerNoteEditorView(mode: mode, viewModel: viewModel) { message in
                        onAction(message)
                    }
                }
                .sheet(isPresented: $showTagPicker) {
                    LockerTagSelectionView(initialSelection: note.tags) { tags in
                        viewModel.add(tags: tags, to: [note.id])
                        onAction("Tags updated")
                    }
                }
                .confirmationDialog(
                    "Delete this note?",
                    isPresented: $showDeleteDialog,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        viewModel.delete(ids: [note.id])
                        onAction("Note deleted")
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                Text("Note not found.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum LockerNoteEditorMode: Identifiable {
    case create(LockerNoteType)
    case edit(LockerNote)

    var id: String {
        switch self {
        case .create(let type):
            return "new-\(type.rawValue)"
        case .edit(let note):
            return note.id.uuidString
        }
    }
}

private struct LockerNoteEditorView: View {
    let mode: LockerNoteEditorMode
    @ObservedObject var viewModel: LockerNotesViewModel
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var selectedTags: Set<LockerNoteTag> = []
    @State private var noteType: LockerNoteType = .quick
    @State private var caseReference: String = ""
    @State private var reminderEnabled = false
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var isPinned = false

    init(mode: LockerNoteEditorMode, viewModel: LockerNotesViewModel, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.viewModel = viewModel
        self.onSave = onSave
        switch mode {
        case .create(let type):
            _noteType = State(initialValue: type)
            _selectedTags = State(initialValue: Set(type.suggestedTags))
        case .edit(let note):
            _title = State(initialValue: note.title)
            _bodyText = State(initialValue: note.body)
            _selectedTags = State(initialValue: Set(note.tags))
            _noteType = State(initialValue: note.noteType)
            _caseReference = State(initialValue: note.caseReference ?? "")
            _reminderEnabled = State(initialValue: note.reminderDate != nil)
            _reminderDate = State(initialValue: note.reminderDate ?? Date().addingTimeInterval(3600))
            _isPinned = State(initialValue: note.isPinned)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Form {
                titleSection
                noteBodySection
                tagsSection
                caseReferenceSection
                reminderSection
                saveSection
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var headerTitle: String {
        mode.isNew ? "Add New Note" : "Edit Note"
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveNote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = caseReference.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .create:
            let note = LockerNote(
                id: UUID(),
                title: trimmedTitle,
                body: trimmedBody,
                tags: Array(selectedTags),
                noteType: noteType,
                caseReference: reference.isEmpty ? nil : reference,
                reminderDate: reminderEnabled ? reminderDate : nil,
                isPinned: isPinned,
                isArchived: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            viewModel.create(note: note)
            onSave("Note saved")
        case .edit(let existing):
            var updated = existing
            updated.title = trimmedTitle
            updated.body = trimmedBody
            updated.tags = Array(selectedTags)
            updated.noteType = noteType
            updated.caseReference = reference.isEmpty ? nil : reference
            updated.reminderDate = reminderEnabled ? reminderDate : nil
            updated.isPinned = isPinned
            updated.updatedAt = Date()
            viewModel.update(updated)
            onSave("Changes saved")
        }
        dismiss()
    }

    private var editorHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("< Cancel")
            }
            .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Save") { saveNote() }
                .font(.subheadline.weight(.semibold))
                .disabled(isSaveDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private var titleSection: some View {
        Section("Title") {
            Text(headerTitle)
                .font(.title3.weight(.semibold))
                .opacity(mode.isNew ? 1 : 0.7)
            TextField("Add a title (e.g., “Case 23-109 follow-ups”)", text: $title)
                .textInputAutocapitalization(.sentences)
        }
    }

    private var noteBodySection: some View {
        Section("Note") {
            TextEditor(text: $bodyText)
                .frame(minHeight: 220)
                .overlay(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("Type your note…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.horizontal, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var tagsSection: some View {
        Section("Tags / Category") {
            AdaptiveTagGrid(data: LockerNoteTag.selectableCases) { tag in
                Button {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    Text(tag.displayName)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(selectedTags.contains(tag) ? .white : tag.tint)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedTags.contains(tag) ? tag.tint : tag.tint.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var caseReferenceSection: some View {
        Section("Case / Reference #") {
            TextField("Incident / case / reference #", text: $caseReference)
                .textInputAutocapitalization(.characters)
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Add reminder", isOn: $reminderEnabled.animation())
            if reminderEnabled {
                DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
            }
            Toggle("Pin to top of My Notes", isOn: $isPinned)
        } footer: {
            Text("🔒 Only you can see this note.")
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                saveNote()
            } label: {
                Text(mode.isNew ? "Save New Note" : "Save Changes")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaveDisabled)
            .opacity(isSaveDisabled ? 0.5 : 1)
        }
    }
}

private struct LockerTagSelectionView: View {
    @State private var selection: Set<LockerNoteTag>
    let onSave: ([LockerNoteTag]) -> Void
    @Environment(\.dismiss) private var dismiss

    init(initialSelection: [LockerNoteTag], onSave: @escaping ([LockerNoteTag]) -> Void) {
        _selection = State(initialValue: Set(initialSelection))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(LockerNoteTag.selectableCases) { tag in
                    Button {
                        if selection.contains(tag) {
                            selection.remove(tag)
                        } else {
                            selection.insert(tag)
                        }
                    } label: {
                        HStack {
                            Text(tag.displayName)
                            Spacer()
                            if selection.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Array(selection))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LockerSelectionToolbar: View {
    let count: Int
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onTag: () -> Void
    let onPin: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Text("\(count) selected")
                .font(.headline)
            Spacer()
            Button(action: onTag) {
                Label("Tag", systemImage: "tag")
            }
            Button(action: onPin) {
                Label("Pin", systemImage: "pin")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

private struct AdaptiveTagGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
            ForEach(Array(data), id: \.self) { element in
                content(element)
            }
        }
    }
}

private extension LockerNote {
    var exportText: String {
        var components: [String] = []
        components.append("Title: \(trimmedTitle)")
        if let caseReference {
            components.append("Case #: \(caseReference)")
        }
        if !tags.isEmpty {
            components.append("Tags: \(tags.map { $0.displayName }.joined(separator: ", "))")
        }
        components.append("Created: \(createdAt.formatted(date: .abbreviated, time: .shortened))")
        components.append("Updated: \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
        components.append("\n\(body)")
        return components.joined(separator: "\n")
    }
}

private extension LockerNoteEditorMode {
    var isNew: Bool {
        if case .create = self { return true }
        return false
    }
}

private extension Binding where Value == Date? {
    func resolved(with fallback: Date) -> Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue ?? fallback },
            set: { newValue in
                self.wrappedValue = newValue
            }
        )
    }
}

// MARK: - Locker Evaluations & Career Docs

private struct LockerCertificationsHomeView: View {
    @StateObject private var viewModel = LockerCertificationsViewModel()
    @State private var searchText = ""
    @State private var statusFilter: LockerCertificationStatusFilter = .all
    @State private var sortSelection: LockerCertificationSort = .expiration
    @State private var editorMode: LockerCertificationEditorMode?

    private var filteredCertifications: [LockerCertification] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.certifications
            .filter { certification in
                statusFilter.matches(certification)
            }
            .filter { certification in
                guard !term.isEmpty else { return true }
                let haystack = [
                    certification.name.lowercased(),
                    certification.issuer?.lowercased() ?? "",
                    certification.licenseNumber?.lowercased() ?? ""
                ]
                return haystack.contains(where: { $0.contains(term) })
            }
            .sorted(by: { lhs, rhs in
                switch sortSelection {
                case .expiration:
                    switch (lhs.expirationDate, rhs.expirationDate) {
                    case let (l?, r?):
                        return l < r
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    default:
                        return lhs.name < rhs.name
                    }
                case .name:
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                case .issuer:
                    let left = lhs.issuer ?? ""
                    let right = rhs.issuer ?? ""
                    if left == right {
                        return lhs.name < rhs.name
                    }
                    return left < right
                }
            })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                certificationsHeader
                certificationsSearchField
                statusChips
                if filteredCertifications.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredCertifications) { certification in
                            NavigationLink {
                                LockerCertificationDetailView(
                                    certificationID: certification.id,
                                    viewModel: viewModel
                                ) { updated in
                                    editorMode = .edit(updated)
                                }
                            } label: {
                                LockerCertificationCard(certification: certification)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    viewModel.delete(id: certification.id)
                                }
                                Button("Edit") {
                                    editorMode = .edit(certification)
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(CalendarBackgroundView().ignoresSafeArea())
        .navigationTitle("My Certifications")
        .searchable(text: $searchText, prompt: "Search by name, issuer, or license #…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $sortSelection) {
                        ForEach(LockerCertificationSort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add certification")
            }
        }
        .sheet(item: $editorMode) { mode in
            LockerCertificationEditorView(mode: mode, viewModel: viewModel)
        }
    }

    private var certificationsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My Certifications")
                .font(.title2.weight(.semibold))
            Text("Private to you. Track every credential and reminder in one locker.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("🔒 Stored in My Locker. Not shared with your agency.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var certificationsSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search certifications…", text: $searchText)
                .textInputAutocapitalization(.words)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.8)
        )
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LockerCertificationStatusFilter.allCases) { filter in
                    Button {
                        statusFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(statusFilter == filter ? Color.blue.opacity(0.2) : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No certifications yet.")
                .font(.title3.weight(.semibold))
            Text("Add your training, instructor quals, or medical cards so DutyWire can remind you before they expire.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct LockerEvaluationsHomeView: View {
    @StateObject private var viewModel = LockerCareerRecordsViewModel()
    @State private var searchText = ""
    @State private var filter: LockerCareerRecordFilter = .all
    @State private var sortOption: LockerCareerSortOption = .newest
    @State private var editorMode: LockerCareerEditorMode?

    private var filteredRecords: [LockerCareerRecord] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.records
            .filter { filter.matches($0) }
            .filter { record in
                guard !term.isEmpty else { return true }
                let haystack = [
                    record.title.lowercased(),
                    record.rater?.lowercased() ?? "",
                    record.notes.lowercased()
                ]
                return haystack.contains { $0.contains(term) }
            }
            .sorted(by: sorter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                evaluationsSearchField
                filterChips

                if filteredRecords.isEmpty {
                    Text("No records yet. Add evaluations, commendations, or milestones to build your career story.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredRecords) { record in
                            NavigationLink {
                                LockerCareerRecordDetailView(
                                    recordID: record.id,
                                    viewModel: viewModel
                                ) { updated in
                                    editorMode = .edit(updated)
                                }
                            } label: {
                                LockerCareerRecordCard(record: record)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    viewModel.delete(id: record.id)
                                }
                                Button("Edit") {
                                    editorMode = .edit(record)
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .searchable(text: $searchText, prompt: "Search by title, date, rater, or note…")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(LockerCareerSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create(.evaluation)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add record")
            }
        }
        .sheet(item: $editorMode) { mode in
            LockerCareerEditorView(mode: mode, viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evaluations & Career Docs")
                .font(.title2.weight(.semibold))
            Text("Track evaluations, commendations, and milestones.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("🔒 Stored in My Locker. Not shared with your agency.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var evaluationsSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search evaluations & docs…", text: $searchText)
                .textInputAutocapitalization(.words)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.8)
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LockerCareerRecordFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(filter == item ? Color.blue.opacity(0.2) : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func sorter(lhs: LockerCareerRecord, rhs: LockerCareerRecord) -> Bool {
        switch sortOption {
        case .newest:
            return lhs.primaryDate > rhs.primaryDate
        case .oldest:
            return lhs.primaryDate < rhs.primaryDate
        case .title:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        case .type:
            if lhs.type == rhs.type { return lhs.primaryDate > rhs.primaryDate }
            return lhs.type.title < rhs.type.title
        }
    }
}

private struct LockerCareerRecordCard: View {
    let record: LockerCareerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(record.type.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(record.type.tint.opacity(0.15), in: Capsule())
            }
            Text(record.primaryDate.formatted(date: .abbreviated, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let rater = record.rater {
                Label("Rated by \(rater)", systemImage: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let issuer = record.issuingAuthority {
                Label("Issued by \(issuer)", systemImage: "building.columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if record.highlight {
                    Label("Highlight", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                if !record.attachments.isEmpty {
                    Label("Attachments", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

private struct LockerCareerRecordDetailView: View {
    let recordID: LockerCareerRecord.ID
    @ObservedObject var viewModel: LockerCareerRecordsViewModel
    var onEdit: (LockerCareerRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteDialog = false

    private var record: LockerCareerRecord? {
        viewModel.record(id: recordID)
    }

    var body: some View {
        Group {
            if let record {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        detailHeader(record)
                        typeSpecificDetails(record)
                        attachmentSection(record)
                        noteSection(record)
                        Text("Created \(record.createdAt.formatted(date: .abbreviated, time: .shortened)) • Updated \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(record.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: record.exportSummary) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share record")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.toggleHighlight(id: record.id)
                        } label: {
                            Image(systemName: record.highlight ? "star.fill" : "star")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onEdit(record)
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(record.isArchived ? "Unarchive" : "Archive") {
                                viewModel.toggleArchive(id: record.id)
                            }
                            Button("Duplicate") {
                                viewModel.duplicate(record: record)
                            }
                            Button("Delete", role: .destructive) {
                                showDeleteDialog = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .confirmationDialog(
                    "Delete this record?",
                    isPresented: $showDeleteDialog,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        viewModel.delete(id: record.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                PlaceholderPane(
                    title: "Record not found",
                    systemImage: "exclamationmark.triangle.fill",
                    message: "This record may have been removed."
                )
            }
        }
    }

    private func detailHeader(_ record: LockerCareerRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(record.type.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(record.type.tint.opacity(0.15), in: Capsule())
                if record.highlight {
                    Label("Career Highlight", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            Text(record.primaryDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let period = record.performancePeriod {
                Text("Period: \(period)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func typeSpecificDetails(_ record: LockerCareerRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let rater = record.rater {
                Label("Rater: \(rater)", systemImage: "person.circle")
            }
            if let rating = record.rating {
                Label("Rating: \(rating)", systemImage: "checkmark.seal")
            }
            if let assignment = record.assignmentAtTime {
                Label("Assignment: \(assignment)", systemImage: "briefcase")
            }
            if let authority = record.issuingAuthority {
                Label("Issuing Authority: \(authority)", systemImage: "building.columns")
            }
            if let awardType = record.awardType {
                Label("Award Type: \(awardType)", systemImage: "rosette")
            }
            if let counselingType = record.counselingType {
                Label("Type: \(counselingType)", systemImage: "ellipsis.bubble")
            }
            if let followUp = record.followUpDate {
                Label("Follow-up: \(followUp.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.clock")
            }
            if let target = record.goalTargetDate {
                Label("Target Date: \(target.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
            }
            if let category = record.goalCategory {
                Label("Goal Category: \(category)", systemImage: "flag.checkered")
            }
            if let status = record.goalStatus {
                Label("Status: \(status)", systemImage: "circle.dashed")
            }
            if let prev = record.previousAssignment {
                Label("Previous: \(prev)", systemImage: "arrowturn.down.right")
            }
            if let newAssign = record.newAssignment {
                Label("New Assignment: \(newAssign)", systemImage: "arrow.up.right.circle")
            }
        }
        .font(.footnote)
        .foregroundStyle(.primary)
    }

    private func attachmentSection(_ record: LockerCareerRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Documents")
                .font(.headline)
            if record.attachments.isEmpty {
                Text("No attachments uploaded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(record.attachments) { attachment in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                        Text(attachment.fileName)
                            .lineLimit(1)
                        Spacer()
                        if let url = attachment.fileURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private func noteSection(_ record: LockerCareerRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My Notes")
                .font(.headline)
            if record.notes.isEmpty {
                Text("No notes yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text(record.notes)
                    .font(.body)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
}

private enum LockerCareerEditorMode: Identifiable {
    case create(LockerCareerRecordType)
    case edit(LockerCareerRecord)

    var id: String {
        switch self {
        case .create(let type): return "create-\(type.rawValue)"
        case .edit(let record): return record.id.uuidString
        }
    }
}

private struct LockerCareerEditorView: View {
    let mode: LockerCareerEditorMode
    @ObservedObject var viewModel: LockerCareerRecordsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var recordType: LockerCareerRecordType = .evaluation
    @State private var primaryDate = Date()
    @State private var performancePeriod = ""
    @State private var rater = ""
    @State private var rating = ""
    @State private var assignment = ""
    @State private var issuingAuthority = ""
    @State private var awardType = ""
    @State private var counselingType = ""
    @State private var followUpDate: Date?
    @State private var goalTargetDate: Date?
    @State private var goalCategory = ""
    @State private var goalStatus = ""
    @State private var previousAssignment = ""
    @State private var newAssignment = ""
    @State private var notes = ""
    @State private var highlight = false
    @State private var attachments: [LockerCareerAttachment] = []
    @State private var showingDocumentPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    init(mode: LockerCareerEditorMode, viewModel: LockerCareerRecordsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        switch mode {
        case .create(let defaultType):
            _recordType = State(initialValue: defaultType)
        case .edit(let record):
            _title = State(initialValue: record.title)
            _recordType = State(initialValue: record.type)
            _primaryDate = State(initialValue: record.primaryDate)
            _performancePeriod = State(initialValue: record.performancePeriod ?? "")
            _rater = State(initialValue: record.rater ?? "")
            _rating = State(initialValue: record.rating ?? "")
            _assignment = State(initialValue: record.assignmentAtTime ?? "")
            _issuingAuthority = State(initialValue: record.issuingAuthority ?? "")
            _awardType = State(initialValue: record.awardType ?? "")
            _counselingType = State(initialValue: record.counselingType ?? "")
            _followUpDate = State(initialValue: record.followUpDate)
            _goalTargetDate = State(initialValue: record.goalTargetDate)
            _goalCategory = State(initialValue: record.goalCategory ?? "")
            _goalStatus = State(initialValue: record.goalStatus ?? "")
            _previousAssignment = State(initialValue: record.previousAssignment ?? "")
            _newAssignment = State(initialValue: record.newAssignment ?? "")
            _notes = State(initialValue: record.notes)
            _highlight = State(initialValue: record.highlight)
            _attachments = State(initialValue: record.attachments)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                recordTypeSection
                coreFieldsSection
                typeSpecificSection
                attachmentSection
                notesSection
                highlightSection
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    defer { showingDocumentPicker = false }
                    guard let stored = storeLockerFile(from: url) else { return }
                    attachments.append(
                        LockerCareerAttachment(
                            id: UUID(),
                            fileName: stored.lastPathComponent,
                            fileURL: stored,
                            addedAt: Date()
                        )
                    )
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let tempUrl = await persistAttachment(from: newItem),
                       let stored = storeLockerFile(from: tempUrl) {
                        await MainActor.run {
                            attachments.append(
                                LockerCareerAttachment(
                                    id: UUID(),
                                    fileName: stored.lastPathComponent,
                                    fileURL: stored,
                                    addedAt: Date()
                                )
                            )
                        }
                    }
                    await MainActor.run {
                        photoPickerItem = nil
                    }
                }
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create:
            return "Add Record"
        case .edit:
            return "Edit Record"
        }
    }

    private var recordTypeSection: some View {
        Section("Record Type") {
            Picker("Record Type", selection: $recordType) {
                ForEach(LockerCareerRecordType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var coreFieldsSection: some View {
        Section("Details") {
            TextField("Title (e.g., \"Annual Evaluation – 2024\")", text: $title)
                .textInputAutocapitalization(.sentences)
            DatePicker(recordType.primaryDateLabel, selection: $primaryDate, displayedComponents: .date)
        }
    }

    @ViewBuilder
    private var typeSpecificSection: some View {
        Section("Type Info") {
            switch recordType {
            case .evaluation:
                TextField("Performance Period", text: $performancePeriod)
                TextField("Rater / Supervisor", text: $rater)
                TextField("Overall Rating", text: $rating)
                TextField("Assignment / Unit", text: $assignment)
            case .commendation:
                TextField("Issuing Authority", text: $issuingAuthority)
                TextField("Award Type", text: $awardType)
                TextField("Assignment / Unit", text: $assignment)
            case .counseling:
                TextField("Supervisor / Rater", text: $rater)
                TextField("Counseling Type", text: $counselingType)
                DatePicker(
                    "Follow-up Date",
                    selection: $followUpDate.resolved(with: Date().addingTimeInterval(86400 * 30)),
                    displayedComponents: .date
                )
            case .goal:
                DatePicker(
                    "Target Date",
                    selection: $goalTargetDate.resolved(with: Date().addingTimeInterval(86400 * 180)),
                    displayedComponents: .date
                )
                TextField("Goal Category", text: $goalCategory)
                TextField("Status", text: $goalStatus)
            case .promotion:
                TextField("Previous Rank / Assignment", text: $previousAssignment)
                TextField("New Rank / Assignment", text: $newAssignment)
            case .other:
                TextField("Details", text: $notes, axis: .vertical)
                    .lineLimit(3...)
            }
        }
    }

    private var attachmentSection: some View {
        Section("Documents") {
            if attachments.isEmpty {
                Text("No attachments yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attachments) { attachment in
                    HStack {
                        Image(systemName: "doc.text")
                        Text(attachment.fileName)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            attachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            HStack {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Label("Add File / PDF", systemImage: "folder.badge.plus")
                }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Add Photo", systemImage: "photo.badge.plus")
                }
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 120)
        } header: {
            Text("Personal Notes")
        } footer: {
            Text("What do you want to remember about this record?")
        }
    }

    private var highlightSection: some View {
        Section {
            Toggle("Highlight this record", isOn: $highlight)
            Text("🔒 Stored in My Locker. Not visible to your agency.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let now = Date()
        switch mode {
        case .create:
            let record = LockerCareerRecord(
                id: UUID(),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                type: recordType,
                primaryDate: primaryDate,
                highlight: highlight,
                attachments: attachments,
                notes: notes,
                createdAt: now,
                updatedAt: now,
                isArchived: false,
                performancePeriod: performancePeriod.nilIfEmpty,
                rater: rater.nilIfEmpty,
                rating: rating.nilIfEmpty,
                assignmentAtTime: assignment.nilIfEmpty,
                issuingAuthority: issuingAuthority.nilIfEmpty,
                awardType: awardType.nilIfEmpty,
                counselingType: counselingType.nilIfEmpty,
                followUpDate: followUpDate,
                goalTargetDate: goalTargetDate,
                goalCategory: goalCategory.nilIfEmpty,
                goalStatus: goalStatus.nilIfEmpty,
                newAssignment: newAssignment.nilIfEmpty,
                previousAssignment: previousAssignment.nilIfEmpty
            )
            viewModel.create(record)
        case .edit(let existing):
            var updated = existing
            updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.type = recordType
            updated.primaryDate = primaryDate
            updated.highlight = highlight
            updated.attachments = attachments
            updated.notes = notes
            updated.updatedAt = now
            updated.performancePeriod = performancePeriod.nilIfEmpty
            updated.rater = rater.nilIfEmpty
            updated.rating = rating.nilIfEmpty
            updated.assignmentAtTime = assignment.nilIfEmpty
            updated.issuingAuthority = issuingAuthority.nilIfEmpty
            updated.awardType = awardType.nilIfEmpty
            updated.counselingType = counselingType.nilIfEmpty
            updated.followUpDate = followUpDate
            updated.goalTargetDate = goalTargetDate
            updated.goalCategory = goalCategory.nilIfEmpty
            updated.goalStatus = goalStatus.nilIfEmpty
            updated.newAssignment = newAssignment.nilIfEmpty
            updated.previousAssignment = previousAssignment.nilIfEmpty
            viewModel.update(updated)
        }
        dismiss()
    }
}

private struct LockerCertificationCard: View {
    let certification: LockerCertification

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(certification.name)
                    .font(.headline)
                Spacer()
                statusBadge
            }
            if let category = certification.category, !category.isEmpty {
                Text(category)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
            }
            HStack(spacing: 8) {
                if let issuer = certification.issuer {
                    Label(issuer, systemImage: "building.columns")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let expirationDate = certification.expirationDate {
                Label("Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Label("No expiration", systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if certification.hasAttachments {
                    Label("Attachments", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if certification.hasReminder {
                    Label("Reminder", systemImage: "bell.badge.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
    }

    private var statusBadge: some View {
        Text(certification.statusDescription)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(certification.statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(certification.statusColor)
    }
}

private struct LockerCertificationDetailView: View {
    let certificationID: LockerCertification.ID
    @ObservedObject var viewModel: LockerCertificationsViewModel
    var onEditRequested: (LockerCertification) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteDialog = false

    private var certification: LockerCertification? {
        viewModel.certification(id: certificationID)
    }

    var body: some View {
        Group {
            if let certification {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        infoSection(certification)
                        attachmentsSection(certification)
                        reminderSection(certification)
                        notesSection(certification)
                        footerMetadata(certification)
                    }
                    .padding(24)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(certification.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: certification.exportSummary) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share certification")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            onEditRequested(certification)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(certification.isArchived ? "Unarchive" : "Archive") {
                                viewModel.toggleArchive(id: certification.id)
                                dismiss()
                            }
                            Button("Delete", role: .destructive) {
                                showDeleteDialog = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .confirmationDialog(
                    "Delete this certification?",
                    isPresented: $showDeleteDialog,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        viewModel.delete(id: certification.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                PlaceholderPane(
                    title: "Certification not found",
                    systemImage: "exclamationmark.triangle.fill",
                    message: "This certification was removed or is unavailable."
                )
            }
        }
    }

    private func infoSection(_ certification: LockerCertification) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusBadge(for: certification)
                Spacer()
                if let category = certification.category, !category.isEmpty {
                    Text(category)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }
            if let issuer = certification.issuer {
                Label(issuer, systemImage: "building.columns")
                    .foregroundStyle(.secondary)
            }
            if let license = certification.licenseNumber {
                Label("License # \(license)", systemImage: "number")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("Issued \(certification.issueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Spacer()
                Label(certification.expirationDate != nil ? "Expires \(certification.expirationDate!.formatted(date: .abbreviated, time: .omitted))" : "No expiration", systemImage: "calendar.badge.exclamationmark")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private func attachmentsSection(_ certification: LockerCertification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Documents")
                    .font(.headline)
                Spacer()
                if !certification.attachments.isEmpty {
                    Text("\(certification.attachments.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if certification.attachments.isEmpty {
                Text("No attachments uploaded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(certification.attachments) { attachment in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.blue)
                        Text(attachment.fileName)
                            .lineLimit(1)
                        Spacer()
                        if let url = attachment.fileURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private func reminderSection(_ certification: LockerCertification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminder")
                .font(.headline)
            if let reminder = certification.reminder {
                Text("Renewal reminder: \(reminder.displayText)")
            } else {
                Text("No reminder set.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private func notesSection(_ certification: LockerCertification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            if certification.notes.isEmpty {
                Text("No notes yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text(certification.notes)
                    .font(.body)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private func footerMetadata(_ certification: LockerCertification) -> some View {
        Text("Last updated \(certification.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func statusBadge(for certification: LockerCertification) -> some View {
        Text(certification.statusDescription)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(certification.statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(certification.statusColor)
    }
}

private enum LockerCertificationEditorMode: Identifiable {
    case create
    case edit(LockerCertification)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let certification): return certification.id.uuidString
        }
    }
}

private struct LockerCertificationEditorView: View {
    let mode: LockerCertificationEditorMode
    @ObservedObject var viewModel: LockerCertificationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var categoryText: String = ""
    @State private var issuer = ""
    @State private var licenseNumber = ""
    @State private var issueDate = Date()
    @State private var expirationDate: Date?
    @State private var attachments: [LockerCertificationAttachment] = []
    @State private var reminderEnabled = false
    @State private var reminderLeadTime: LockerCertificationReminderLeadTime = .days60
    @State private var customReminderDate = Date().addingTimeInterval(86400 * 30)
    @State private var notes = ""
    @State private var showingDocumentPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    init(mode: LockerCertificationEditorMode, viewModel: LockerCertificationsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        if case .edit(let certification) = mode {
            _name = State(initialValue: certification.name)
            _categoryText = State(initialValue: certification.category ?? "")
            _issuer = State(initialValue: certification.issuer ?? "")
            _licenseNumber = State(initialValue: certification.licenseNumber ?? "")
            _issueDate = State(initialValue: certification.issueDate)
            _expirationDate = State(initialValue: certification.expirationDate)
            _attachments = State(initialValue: certification.attachments)
            if let reminder = certification.reminder {
                _reminderEnabled = State(initialValue: true)
                _reminderLeadTime = State(initialValue: reminder.leadTime)
                _customReminderDate = State(initialValue: reminder.customDate ?? Date().addingTimeInterval(86400 * 30))
            }
            _notes = State(initialValue: certification.notes)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Certification Info") {
                    TextField("Certification name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Category (optional)", text: $categoryText)
                        .textInputAutocapitalization(.words)
                    TextField("Issuing agency / organization", text: $issuer)
                        .textInputAutocapitalization(.words)
                    TextField("License / cert number", text: $licenseNumber)
                        .textInputAutocapitalization(.characters)
                }

                Section("Dates") {
                    DatePicker("Issue date", selection: $issueDate, displayedComponents: .date)
                    Toggle("Has expiration date", isOn: Binding(
                        get: { expirationDate != nil },
                        set: { value in
                            if value {
                                expirationDate = Date().addingTimeInterval(86400 * 365)
                            } else {
                                expirationDate = nil
                            }
                        }
                    ))
                    if expirationDate != nil {
                        DatePicker(
                            "Expiration date",
                            selection: $expirationDate.resolved(with: Date().addingTimeInterval(86400 * 365)),
                            displayedComponents: .date
                        )
                    }
                }

                Section("Attachments") {
                    if attachments.isEmpty {
                        Text("No documents uploaded.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { attachment in
                            HStack {
                                Image(systemName: "doc.text")
                                Text(attachment.fileName)
                                    .lineLimit(1)
                                Spacer()
                                Button(role: .destructive) {
                                    attachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    HStack {
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Label("Add File / PDF", systemImage: "folder.badge.plus")
                        }
                        Spacer()
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Label("Add Photo", systemImage: "photo.badge.plus")
                        }
                    }
                }

                Section("Reminder") {
                    Toggle("Add renewal reminder", isOn: $reminderEnabled.animation())
                    if reminderEnabled {
                        Picker("Reminder timing", selection: $reminderLeadTime) {
                            ForEach(LockerCertificationReminderLeadTime.allCases) { lead in
                                Text(lead.description).tag(lead)
                            }
                        }
                        if reminderLeadTime == .custom {
                            DatePicker("Custom date", selection: $customReminderDate, displayedComponents: .date)
                        }
                    }
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("🔒 Stored in My Locker. Not visible to your agency.")
                }
            }
            .navigationTitle(editorTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    defer { showingDocumentPicker = false }
                    guard let stored = storeLockerFile(from: url) else { return }
                    attachments.append(
                        LockerCertificationAttachment(
                            id: UUID(),
                            fileName: stored.lastPathComponent,
                            fileURL: stored,
                            addedAt: Date()
                        )
                    )
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let tempURL = await persistAttachment(from: newItem),
                       let stored = storeLockerFile(from: tempURL) {
                        await MainActor.run {
                            attachments.append(
                                LockerCertificationAttachment(
                                    id: UUID(),
                                    fileName: stored.lastPathComponent,
                                    fileURL: stored,
                                    addedAt: Date()
                                )
                            )
                        }
                    }
                    await MainActor.run {
                        photoPickerItem = nil
                    }
                }
            }
        }
    }

    private var editorTitle: String {
        if case .create = mode {
            return "Add Certification"
        }
        return "Edit Certification"
    }

    private func save() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCategory = categoryText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let now = Date()
        let reminder: LockerCertificationReminder? = reminderEnabled ? LockerCertificationReminder(
            leadTime: reminderLeadTime,
            customDate: reminderLeadTime == .custom ? customReminderDate : nil
        ) : nil

        switch mode {
        case .create:
            let certification = LockerCertification(
                name: cleanedName,
                category: cleanedCategory,
                issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                licenseNumber: licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                issueDate: issueDate,
                expirationDate: expirationDate,
                attachments: attachments,
                reminder: reminder,
                notes: notes,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
            viewModel.create(certification)
        case .edit(let existing):
            var updated = existing
            updated.name = cleanedName
            updated.category = cleanedCategory
            updated.issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            updated.licenseNumber = licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            updated.issueDate = issueDate
            updated.expirationDate = expirationDate
            updated.attachments = attachments
            updated.reminder = reminder
            updated.notes = notes
            updated.updatedAt = now
            viewModel.update(updated)
        }
        dismiss()
    }
}

private extension Error {
    var userFacingMessage: String {
        if let localized = (self as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }
        return (self as NSError).localizedDescription
    }
}

// MARK: - Temporary Destination Stubs

private struct SquadUser {
    let fullName: String
    let rank: String
    let agencyName: String
}

private struct SquadStats {
    var officersCount: Int
    var activeTasksCount: Int
    var unreadNoticesCount: Int
}

private struct SquadRecipient: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let userId: String?

    init(assignment: OfficerAssignmentDTO) {
        id = assignment.id
        name = assignment.displayName
        detail = assignment.assignmentDisplay
        userId = assignment.profile.userId
    }

    init(id: String, name: String, detail: String, userId: String?) {
        self.id = id
        self.name = name
        self.detail = detail
        self.userId = userId
    }

    init(metadata: SquadRecipientMetadata) {
        self.id = metadata.id ?? UUID().uuidString
        self.name = metadata.name ?? "DutyWire Member"
        self.detail = metadata.detail ?? ""
        self.userId = metadata.userId
    }

    var metadataPayload: [String: Any] {
        var payload: [String: Any] = [
            "id": id,
            "name": name
        ]
        if !detail.isEmpty {
            payload["detail"] = detail
        }
        if let userId = userId?.nilIfEmpty {
            payload["userId"] = userId
        }
        return payload
    }
}

private struct SquadUpdate: Identifiable, Equatable {
    let id: String
    var title: String
    var message: String
    var recipients: [SquadRecipient]
    var createdAt: Date
    var isRead: Bool
    var attachment: FeedAttachment?
    var createdByUserId: String?

    static func == (lhs: SquadUpdate, rhs: SquadUpdate) -> Bool {
        lhs.id == rhs.id
    }
}

private struct SquadTask: Identifiable, Equatable {
    let id: String
    var title: String
    var details: String
    var recipients: [SquadRecipient]
    var dueDate: Date?
    var createdAt: Date
    var isCompleted: Bool
    var isAcknowledged: Bool
    var attachment: FeedAttachment?
    var createdByUserId: String?

    static func == (lhs: SquadTask, rhs: SquadTask) -> Bool {
        lhs.id == rhs.id
    }
}

private extension Array where Element == SquadRecipient {
    var shortSummary: String {
        guard !isEmpty else { return "No recipients selected" }
        let names = self.prefix(2).map(\.name)
        var summary = names.joined(separator: ", ")
        if count > 2 {
            summary += " +\(count - 2)"
        }
        return summary
    }
}


private struct MySquadView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @StateObject private var rosterViewModel = DepartmentRosterAssignmentsViewModel()
    @State private var actionMessage: String?
    @State private var activeSheet: SquadSheet?
    @State private var hasLoaded = false
    @State private var rosterSegment: SquadRosterSegment = .roster
    private var lexicon: TenantLexicon { auth.tenantLexicon }
    private var squadLabel: String { lexicon.squadSingular }
    private var squadPluralLabel: String { lexicon.squadPlural }
    private var squadLabelLower: String { squadLabel.lowercased() }
    private var squadPluralLower: String { squadPluralLabel.lowercased() }
    private var taskLabel: String { lexicon.taskSingular }
    private var taskPluralLabel: String { lexicon.taskPlural }

    private enum SquadSheet: String, Identifiable {
        case actionPicker
        case composeNotification
        case composeTask
        case manageMemberships

        var id: String { rawValue }
    }

    private var canComposeSquadMessages: Bool {
        auth.permissions.canSendSquadMessages
    }

    private var currentUserId: String? {
        auth.currentUser?.userId.nilIfEmpty
    }

    private var senderDisplayName: String? {
        auth.userProfile.displayName ??
        auth.userProfile.usernameForDisplay ??
        currentUserId
    }

    private var squadUser: SquadUser {
        let baseName = auth.userProfile.displayName ??
        auth.userProfile.fullName ??
        auth.currentUser?.username ??
        "DutyWire Member"

        let rankSource = auth.userProfile.rank?.nilIfEmpty ?? auth.primaryRoleDisplayName ?? auth.userRole.displayName
        let agency = auth.userProfile.siteKey?.nilIfEmpty ?? auth.resolvedOrgId ?? "DutyWire"
        return SquadUser(fullName: baseName, rank: rankSource.uppercased(), agencyName: agency)
    }

    private var selectedAssignments: [OfficerAssignmentDTO] {
        rosterViewModel.squadAssignments(for: currentUserId)
    }

    private var composerAssignments: [OfficerAssignmentDTO] {
        selectedAssignments
    }

    private var squadStats: SquadStats {
        SquadStats(
            officersCount: selectedAssignments.count,
            activeTasksCount: 0,
            unreadNoticesCount: 0
        )
    }

    private var bureauSummary: String {
        let values = Set(selectedAssignments.compactMap { $0.detail?.nilIfEmpty ?? $0.location?.nilIfEmpty })
        if values.isEmpty { return "Not recorded" }
        return values.sorted().joined(separator: " • ")
    }

    private var squadSummary: String {
        let values = Set(selectedAssignments.compactMap { $0.squad?.nilIfEmpty ?? $0.title.nilIfEmpty })
        if values.isEmpty { return "Custom \(squadLabel)" }
        return values.sorted().joined(separator: " • ")
    }

    var body: some View {
        ScrollView {
            squadContent
                .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My \(squadLabel)")
        .toolbar {
            if auth.permissions.canManageRoster {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage") {
                        activeSheet = .manageMemberships
                    }
                }
            }
        }
        .alert(
            "\(squadLabel) Actions",
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
            case .actionPicker:
                SquadActionPickerView(
                    lexicon: lexicon,
                    onSelectNotification: { activeSheet = .composeNotification },
                    onSelectTask: { activeSheet = .composeTask },
                    onClose: { activeSheet = nil }
                )
            case .composeNotification:
                NavigationStack {
                    SquadUpdateComposer(
                        assignments: composerAssignments,
                        presetSelection: Set(composerAssignments.map { $0.id }),
                        onCancel: { activeSheet = nil },
                        onSave: { update in
                            Task { await sendSquadNotification(update) }
                        }
                    )
                }
            case .composeTask:
                NavigationStack {
                    SquadTaskComposer(
                        assignments: composerAssignments,
                        presetSelection: Set(composerAssignments.map { $0.id }),
                        onCancel: { activeSheet = nil },
                        onSave: { task in
                            Task { await sendSquadTask(task) }
                        }
                    )
                }
            case .manageMemberships:
                SquadMembershipEditorView(
                    viewModel: rosterViewModel,
                    lexicon: lexicon,
                    orgId: auth.resolvedOrgId
                ) {
                    activeSheet = nil
                    Task { await rosterViewModel.load(orgId: auth.resolvedOrgId) }
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await rosterViewModel.load(orgId: auth.resolvedOrgId)
        }
    }

    @ViewBuilder
    private var squadContent: some View {
        VStack(spacing: 20) {
            SquadOverviewCard(
                user: squadUser,
                stats: squadStats,
                bureauSummary: bureauSummary,
                squadSummary: squadSummary,
                lexicon: lexicon
            )

            Button { presentComposer() } label: {
                Label("Message My \(squadLabel)", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(SquadActionButtonStyle(tint: appTint))
            .disabled(!canComposeSquadMessages)
            .opacity(canComposeSquadMessages ? 1 : 0.5)

            rosterSection
        }
    }

    private enum SquadRosterSegment: CaseIterable, Identifiable {
        case roster
        case notifications
        case tasks

        var id: String {
            switch self {
            case .roster: return "roster"
            case .notifications: return "notifications"
            case .tasks: return "tasks"
            }
        }

        func title(using lexicon: TenantLexicon) -> String {
            switch self {
            case .roster:
                return "\(lexicon.squadSingular) Roster"
            case .notifications:
                return "Notifications"
            case .tasks:
                return lexicon.taskPlural
            }
        }

        func emptyMessage(using lexicon: TenantLexicon) -> String {
            switch self {
            case .roster:
                return ""
            case .notifications:
                return "No \(lexicon.squadSingular.lowercased()) updates yet."
            case .tasks:
                return "No \(lexicon.taskPlural.lowercased()) assigned yet."
            }
        }
    }

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $rosterSegment) {
                ForEach(SquadRosterSegment.allCases) { segment in
                    Text(segment.title(using: lexicon))
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch rosterSegment {
                case .roster:
                    rosterListContent
                case .notifications:
                    placeholderCard(for: .notifications)
                case .tasks:
                    placeholderCard(for: .tasks)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.white.opacity(0.7), radius: 10, x: -4, y: -4)
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 6, y: 10)
    }

    @ViewBuilder
    private var rosterListContent: some View {
        if rosterViewModel.isLoading && rosterViewModel.assignments.isEmpty {
            ProgressView("Loading assignments…")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = rosterViewModel.errorMessage, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if selectedAssignments.isEmpty {
            VStack(spacing: 12) {
                Text("No \(squadLabelLower) membership found")
                    .font(.headline)
                Text("Ask your supervisor or admin to add you to an active \(squadLabelLower) so this list can populate automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
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
    }

    @ViewBuilder
    private func placeholderCard(for segment: SquadRosterSegment) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Text(segment.emptyMessage(using: lexicon))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if segment == .notifications {
                Text("Send \(squadLabelLower) updates to see them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if segment == .tasks {
                Text("Assign \(taskPluralLabel.lowercased()) to populate this view.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.vertical, 12)
    }

    private func presentComposer() {
        guard canComposeSquadMessages else {
            actionMessage = "You do not have permission to send \(squadLabelLower) messages."
            return
        }
        guard !composerAssignments.isEmpty else {
            actionMessage = "We couldn’t find any officers assigned to your \(squadLabelLower). Confirm your membership with an admin."
            return
        }
        activeSheet = .actionPicker
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
        }
    }

    private func sendSquadNotification(_ update: SquadUpdate) async {
        guard canComposeSquadMessages else {
            await MainActor.run { actionMessage = "You do not have permission to send \(squadLabelLower) notifications." }
            return
        }
        var outbound = update
        outbound.createdByUserId = currentUserId
        await sendSquadMessage(
            title: outbound.title,
            body: outbound.message,
            metadata: metadataDictionary(for: outbound),
            recipients: outbound.recipients,
            confirmation: "Notification sent to \\(outbound.recipients.shortSummary)"
        )
    }

    private func sendSquadTask(_ task: SquadTask) async {
        guard canComposeSquadMessages else {
            await MainActor.run { actionMessage = "You do not have permission to assign \(squadLabelLower) \(taskPluralLabel.lowercased())." }
            return
        }
        var outbound = task
        outbound.createdByUserId = currentUserId
        await sendSquadMessage(
            title: outbound.title,
            body: outbound.details,
            metadata: metadataDictionary(for: outbound),
            recipients: outbound.recipients,
            confirmation: "Task assigned to \\(outbound.recipients.shortSummary)"
        )
    }

    private func sendSquadMessage(
        title: String,
        body: String,
        metadata: [String: Any],
        recipients: [SquadRecipient],
        confirmation: String
    ) async {
        guard let orgId = auth.resolvedOrgId else {
            await MainActor.run { actionMessage = "Missing organization ID on your profile." }
            return
        }
        let targetUserIds = deliveryUserIds(for: recipients)
        let hasDeliverableRecipient = recipients.contains { $0.userId?.nilIfEmpty != nil }
        guard hasDeliverableRecipient, !targetUserIds.isEmpty else {
            await MainActor.run { actionMessage = "None of the selected officers have active DutyWire accounts." }
            return
        }
        let creator = senderDisplayName?.nilIfEmpty ?? "DutyWire Admin"
        do {
            _ = try await ShiftlinkAPI.createNotificationMessage(
                orgId: orgId,
                title: title,
                body: body,
                category: .squadAlert,
                recipients: targetUserIds,
                metadata: metadata,
                createdBy: creator
            )
            _ = try? await ShiftlinkAPI.sendNotification(
                orgId: orgId,
                recipients: targetUserIds,
                title: title,
                body: body,
                category: .squadAlert,
                metadata: metadata
            )
            await MainActor.run {
                activeSheet = nil
                actionMessage = confirmation
            }
        } catch {
            await MainActor.run { actionMessage = "Unable to send \(squadLabelLower) message: \\(error.localizedDescription)" }
        }
    }

    private func metadataDictionary(for update: SquadUpdate) -> [String: Any] {
        baseSquadMetadata(
            feedType: .squadNotification,
            recipients: update.recipients,
            attachment: update.attachment,
            creatorId: update.createdByUserId
        )
    }

    private func metadataDictionary(for task: SquadTask) -> [String: Any] {
        var metadata = baseSquadMetadata(
            feedType: .squadTask,
            recipients: task.recipients,
            attachment: task.attachment,
            creatorId: task.createdByUserId
        )
        if let dueDate = task.dueDate {
            metadata["dueDate"] = ShiftlinkAPI.encode(date: dueDate)
        }
        metadata["isCompleted"] = task.isCompleted
        return metadata
    }

    private func baseSquadMetadata(
        feedType: FeedPayloadType,
        recipients: [SquadRecipient],
        attachment: FeedAttachment?,
        creatorId: String?
    ) -> [String: Any] {
        var metadata: [String: Any] = [
            "feedType": feedType.rawValue,
            "recipients": metadataRecipientsPayload(from: recipients)
        ]
        if let creator = creatorId?.nilIfEmpty {
            metadata["createdByUserId"] = creator
        }
        if let attachmentPayload = metadataAttachmentPayload(forExisting: attachment) {
            metadata["attachment"] = attachmentPayload
        }
        return metadata
    }

    private func metadataRecipientsPayload(from recipients: [SquadRecipient]) -> [[String: Any]] {
        recipients.map { $0.metadataPayload }
    }

    private func metadataAttachmentPayload(forExisting attachment: FeedAttachment?) -> [String: Any]? {
        guard let attachment else { return nil }
        var payload: [String: Any] = [
            "type": attachment.type.rawValue,
            "title": attachment.title
        ]
        if let urlString = attachment.url?.absoluteString {
            payload["url"] = urlString
        }
        return payload
    }

    private func deliveryUserIds(for recipients: [SquadRecipient]) -> [String] {
        var ids: [String] = []
        var seen: Set<String> = []
        for recipient in recipients {
            guard let rawId = recipient.userId?.nilIfEmpty else { continue }
            let normalized = rawId.lowercased()
            if seen.insert(normalized).inserted {
                ids.append(rawId)
            }
        }
        if let currentId = currentUserId {
            let normalized = currentId.lowercased()
            if seen.insert(normalized).inserted {
                ids.append(currentId)
            }
        }
        return ids
    }
}

private struct SquadOverviewCard: View {
    let user: SquadUser
    let stats: SquadStats
    let bureauSummary: String
    let squadSummary: String
    let lexicon: TenantLexicon

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(lexicon.squadSingular.uppercased()) OVERVIEW")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    Text(user.fullName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }

                Spacer()

                Text(user.rank)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.systemGray6))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Agency: \(user.agencyName)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text("\(lexicon.bureauSingular): \(bureauSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(lexicon.squadSingular): \(squadSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 18) {
                SquadStatItem(
                    systemImage: "person.2.fill",
                    title: "Officers",
                    value: "\(stats.officersCount)"
                )

                SquadStatItem(
                    systemImage: "checkmark.circle.fill",
                    title: "Active \(lexicon.taskPlural)",
                    value: "\(stats.activeTasksCount)"
                )

                SquadStatItem(
                    systemImage: "bubble.left.and.bubble.right.fill",
                    title: "Unread Notices",
                    value: "\(stats.unreadNoticesCount)"
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

private struct SquadStatItem: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundColor(Color.blue)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
        }
    }
}

private struct SquadQuickActionsRow: View {
    let onSendUpdate: () -> Void
    let onAssignTask: () -> Void
    let onViewHistory: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            QuickActionButton(
                title: "Send\nUpdate",
                subtitle: "Broadcast a squad update.",
                systemImage: "paperplane.fill",
                action: onSendUpdate
            )

            QuickActionButton(
                title: "Assign\nTask",
                subtitle: "Send task to one or more officers.",
                systemImage: "list.bullet.rectangle.fill",
                action: onAssignTask
            )

            QuickActionButton(
                title: "View\nHistory",
                subtitle: "See recent squad activity.",
                systemImage: "clock.fill",
                action: onViewHistory
            )
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .frame(width: 32, height: 32)

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

private struct SquadPermissionsNotice: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct SquadActionPickerView: View {
    let lexicon: TenantLexicon
    let onSelectNotification: () -> Void
    let onSelectTask: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.blue)
                        Text("Choose \(lexicon.squadSingular) Action")
                            .font(.title3.weight(.semibold))
                        Text("Reach your \(lexicon.squadSingular.lowercased()) with a quick notification or assign a \(lexicon.taskSingular.lowercased()).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        DepartmentNotificationOptionCard(
                            title: "Send \(lexicon.squadSingular) Notification",
                            subtitle: "Share updates, reminders, or alerts.",
                            icon: "paperplane.fill",
                            tint: .blue,
                            action: onSelectNotification
                        )

                        DepartmentNotificationOptionCard(
                            title: "Assign \(lexicon.squadSingular) \(lexicon.taskSingular)",
                            subtitle: "Create a follow-up or action item.",
                            icon: "checkmark.circle.fill",
                            tint: .green,
                            action: onSelectTask
                        )
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(lexicon.squadSingular) Actions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SquadUpdateComposer: View {
    @EnvironmentObject private var auth: AuthViewModel
    let assignments: [OfficerAssignmentDTO]
    let presetSelection: Set<String>
    let onCancel: () -> Void
    let onSave: (SquadUpdate) -> Void
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var selectedIds: Set<String>
    @State private var searchText: String = ""
    @State private var attachmentKind: AttachmentKind = .none
    @State private var attachmentTitle: String = ""
    @State private var attachmentURL: String = ""

    init(assignments: [OfficerAssignmentDTO], presetSelection: Set<String>, onCancel: @escaping () -> Void, onSave: @escaping (SquadUpdate) -> Void) {
        self.assignments = assignments.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        self.presetSelection = presetSelection
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedIds = State(initialValue: presetSelection.isEmpty ? Set(assignments.map(\.id)) : presetSelection)
    }

    var body: some View {
        Form {
            Section("Message") {
                TextField("Subject", text: $subject)
                    .textInputAutocapitalization(.sentences)
                TextEditor(text: $message)
                    .frame(minHeight: 140)
            }

            Section(header: Text("Recipients"), footer: Text(recipientFooter).font(.caption).foregroundStyle(.secondary)) {
                if assignments.isEmpty {
                    Text("No officers available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredAssignments) { assignment in
                        Toggle(isOn: binding(for: assignment)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(assignment.assignmentDisplay)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Attachment") {
                Picker("Type", selection: $attachmentKind) {
                    ForEach(AttachmentKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                if attachmentKind != .none {
                    TextField("Attachment Title", text: $attachmentTitle)
                    TextField("File or Website Link", text: $attachmentURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.none)
                }
            }
        }
        .navigationTitle("Send Update")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") { save() }
                    .disabled(!isValid)
            }
        }
        .searchable(text: $searchText)
    }

    private var isValid: Bool {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkValid = attachmentKind == .none || !attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !trimmedMessage.isEmpty && !selectedIds.isEmpty && linkValid
    }

    private var recipientFooter: String {
        guard !selectedIds.isEmpty else { return "Select the officers who should receive this update." }
        let names = assignments.filter { selectedIds.contains($0.id) }.map(\.displayName)
        guard !names.isEmpty else { return "\(selectedIds.count) recipients selected." }
        return names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +\(names.count - 3)" : "")
    }

    private var filteredAssignments: [OfficerAssignmentDTO] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return assignments }
        return assignments.filter { assignment in
            assignment.displayName.localizedCaseInsensitiveContains(trimmed) ||
            assignment.badgeNumber.localizedCaseInsensitiveContains(trimmed) ||
            assignment.title.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func binding(for assignment: OfficerAssignmentDTO) -> Binding<Bool> {
        Binding(
            get: { selectedIds.contains(assignment.id) },
            set: { newValue in
                if newValue { selectedIds.insert(assignment.id) }
                else { selectedIds.remove(assignment.id) }
            }
        )
    }

    private func save() {
        guard isValid else { return }
        let recipients = assignments.filter { selectedIds.contains($0.id) }.map(SquadRecipient.init)
        let update = SquadUpdate(
            id: UUID().uuidString,
            title: subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(auth.tenantLexicon.squadSingular) Update" : subject.trimmingCharacters(in: .whitespacesAndNewlines),
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            recipients: recipients,
            createdAt: Date(),
            isRead: false,
            attachment: attachmentData?.makeFeedAttachment()
        )
        onSave(update)
    }

    private var attachmentData: AttachmentComposerData? {
        guard attachmentKind != .none else { return nil }
        let trimmedURL = attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        let trimmedTitle = attachmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return AttachmentComposerData(
            type: attachmentKind,
            title: trimmedTitle.isEmpty ? attachmentKind.defaultTitle : trimmedTitle,
            link: trimmedURL
        )
    }
}

private struct SquadTaskComposer: View {
    let assignments: [OfficerAssignmentDTO]
    let presetSelection: Set<String>
    let onCancel: () -> Void
    let onSave: (SquadTask) -> Void
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var selectedIds: Set<String>
    @State private var searchText: String = ""
    @State private var includeDueDate = false
    @State private var dueDate = Date()
    @State private var attachmentKind: AttachmentKind = .none
    @State private var attachmentTitle: String = ""
    @State private var attachmentURL: String = ""

    init(assignments: [OfficerAssignmentDTO], presetSelection: Set<String>, onCancel: @escaping () -> Void, onSave: @escaping (SquadTask) -> Void) {
        self.assignments = assignments.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        self.presetSelection = presetSelection
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedIds = State(initialValue: presetSelection.isEmpty ? Set(assignments.map(\.id)) : presetSelection)
    }

    var body: some View {
        Form {
            Section("Task Details") {
                TextField("Title", text: $title)
                    .textInputAutocapitalization(.sentences)
                TextEditor(text: $details)
                    .frame(minHeight: 120)
            }

            Section("Schedule") {
                Toggle("Add due date", isOn: $includeDueDate.animation())
                if includeDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section(header: Text("Assign To"), footer: Text(recipientFooter).font(.caption).foregroundStyle(.secondary)) {
                if assignments.isEmpty {
                    Text("No officers available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredAssignments) { assignment in
                        Toggle(isOn: binding(for: assignment)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(assignment.assignmentDisplay)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Attachment") {
                Picker("Type", selection: $attachmentKind) {
                    ForEach(AttachmentKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                if attachmentKind != .none {
                    TextField("Attachment Title", text: $attachmentTitle)
                    TextField("File or Website Link", text: $attachmentURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.none)
                }
            }
        }
        .navigationTitle("Assign Task")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Assign") { save() }
                    .disabled(!isValid)
            }
        }
        .searchable(text: $searchText)
    }

    private var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkValid = attachmentKind == .none || !attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !trimmedTitle.isEmpty && !trimmedDetails.isEmpty && !selectedIds.isEmpty && linkValid
    }

    private var recipientFooter: String {
        guard !selectedIds.isEmpty else { return "Choose at least one officer for this task." }
        let names = assignments.filter { selectedIds.contains($0.id) }.map(\.displayName)
        guard !names.isEmpty else { return "\(selectedIds.count) recipients selected." }
        return names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +\(names.count - 3)" : "")
    }

    private var filteredAssignments: [OfficerAssignmentDTO] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return assignments }
        return assignments.filter { assignment in
            assignment.displayName.localizedCaseInsensitiveContains(trimmed) ||
            assignment.badgeNumber.localizedCaseInsensitiveContains(trimmed) ||
            assignment.title.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func binding(for assignment: OfficerAssignmentDTO) -> Binding<Bool> {
        Binding(
            get: { selectedIds.contains(assignment.id) },
            set: { newValue in
                if newValue { selectedIds.insert(assignment.id) }
                else { selectedIds.remove(assignment.id) }
            }
        )
    }

    private func save() {
        guard isValid else { return }
        let recipients = assignments.filter { selectedIds.contains($0.id) }.map(SquadRecipient.init)
        let task = SquadTask(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            recipients: recipients,
            dueDate: includeDueDate ? dueDate : nil,
            createdAt: Date(),
            isCompleted: false,
            isAcknowledged: false,
            attachment: attachmentData?.makeFeedAttachment()
        )
        onSave(task)
    }

    private var attachmentData: AttachmentComposerData? {
        guard attachmentKind != .none else { return nil }
        let trimmedURL = attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        let trimmedTitle = attachmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return AttachmentComposerData(
            type: attachmentKind,
            title: trimmedTitle.isEmpty ? attachmentKind.defaultTitle : trimmedTitle,
            link: trimmedURL
        )
    }
}

private struct SquadHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let badge: String
    let icon: String
    let accent: Color
    let recipients: String
}

private struct SquadHistoryView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let updates: [SquadUpdate]
    let tasks: [SquadTask]
    @Environment(\.dismiss) private var dismiss

    private var entries: [SquadHistoryEntry] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let updateEntries = updates.map { update in
            SquadHistoryEntry(
                date: update.createdAt,
                title: update.title,
                detail: update.message,
                badge: "Update",
                icon: "paperplane.fill",
                accent: .blue,
                recipients: update.recipients.shortSummary
            )
        }

        let taskEntries = tasks.map { task in
            let detail: String
            if let due = task.dueDate {
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                detail = "\(task.details.isEmpty ? "Assigned task" : task.details)\nDue \(formatter.string(from: due))"
            } else {
                detail = task.details.isEmpty ? "Assigned task" : task.details
            }
            return SquadHistoryEntry(
                date: task.createdAt,
                title: task.title,
                detail: detail,
                badge: task.isCompleted ? "Completed" : "Task",
                icon: task.isCompleted ? "checkmark.circle.fill" : "list.bullet.rectangle.fill",
                accent: task.isCompleted ? .green : .orange,
                recipients: task.recipients.shortSummary
            )
        }

        return (updateEntries + taskEntries).sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                Section {
                    Text("No \(auth.tenantLexicon.squadSingular.lowercased()) activity recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(entry.badge, systemImage: entry.icon)
                                .font(.caption)
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(entry.accent)
                            Spacer()
                            Text(entry.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.title)
                            .font(.headline)
                        Text(entry.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(entry.recipients)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(auth.tenantLexicon.squadSingular) History")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

private struct SquadActivityArchiveView: View {
    @EnvironmentObject private var auth: AuthViewModel
    var body: some View {
        PlaceholderPane(
            title: "\(auth.tenantLexicon.squadSingular) Activity",
            systemImage: "chart.bar.fill",
            message: "Detailed \(auth.tenantLexicon.squadSingular.lowercased()) activity records and patrol history will appear here once available for your agency."
        )
    }
}

private struct OvertimeBoardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @StateObject private var viewModel = OvertimeBoardViewModel()

    private var orgId: String? { auth.resolvedOrgId }

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
                ProgressView("Loading special details…")
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .navigationTitle("Special Details")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.load(orgId: orgId, userId: userId)
        }
        .alert(
            "Special Details",
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
            if auth.permissions.canPostEventAssignments {
                NavigationLink {
                    OvertimeOpportunityManagerView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Post Event Assignments")
                                .font(.headline)
                            Text("Create sign-up lists and award shifts by seniority or first-come, first-served.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.forward.circle.fill")
                            .foregroundStyle(appTint)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Event assignments and special details are published by your supervisors. When a new opportunity opens, it will appear below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        } header: {
            Text("Event & Detail Opportunities")
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("Year to Date") {
            Text("No special details or event assignments recorded yet this year.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var recentAssignmentsSection: some View {
        Section("Recent Jobs") {
            if recentAssignments.isEmpty {
                Text("Any special details or event assignments you accept will appear here along with the total hours credited to you.")
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
                Text("No special details or event assignments are open right now. Pull to refresh or check back later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.available) { posting in
                    infoCard(
                        posting,
                        badge: "Open Detail",
                        accent: .green,
                        footer: posting.details?.contact?.isEmpty == false
                            ? "Contact \(posting.details?.contact ?? "your supervisor") to volunteer."
                            : nil
                    )
                }
            }
        } header: {
            Text("Open Event Assignments")
        } footer: {
            Text("DutyWire notifies you when new event assignments or special details are posted.")
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
                Text("You haven't completed any special details or event assignments yet, but your history will show here once you do.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    OvertimeHistoryView(assignments: historyAssignments)
                } label: {
                    Label("Review past special details", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
        }
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
                Text("No special detail history recorded yet.")
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
        .navigationTitle("Special Detail History")
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

// MARK: - Overtime Opportunities

private struct OvertimeOpportunityManagerView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.appTint) private var appTint
    @StateObject private var viewModel = ManagedOvertimeViewModel()
    @State private var showingCreateForm = false
    @State private var creationForm = ManagedOvertimePostingFormState()

    private var orgId: String? { auth.resolvedOrgId }

    var body: some View {
        List {
            Section {
                Button {
                    creationForm = ManagedOvertimePostingFormState()
                    showingCreateForm = true
                } label: {
                    Label("New Event Assignment", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
                .disabled(orgId == nil)
            }

            Section("Open Assignments") {
                if viewModel.openPostings.isEmpty {
                    Text("No open event assignments yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.openPostings) { posting in
                        NavigationLink {
                            ManagedOvertimePostingDetailView(posting: posting, viewModel: viewModel)
                        } label: {
                            postingRow(posting, accent: appTint)
                        }
                    }
                }
            }

            if !viewModel.closedPostings.isEmpty {
                Section("Closed Assignments") {
                    ForEach(viewModel.closedPostings) { posting in
                        NavigationLink {
                            ManagedOvertimePostingDetailView(posting: posting, viewModel: viewModel)
                        } label: {
                            postingRow(posting, accent: .gray)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Event Assignment Manager")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(orgId == nil)
                }
            }
        }
        .task {
            guard let orgId else { return }
            await viewModel.load(orgId: orgId)
        }
        .refreshable {
            await viewModel.reload()
        }
        .alert(
            "Special Details",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingCreateForm) {
            NavigationStack {
                ManagedOvertimePostingFormView(title: "New Event Assignment", form: $creationForm) {
                    showingCreateForm = false
                } onSubmit: { form in
                    Task {
                        guard let orgId, let creatorId = auth.currentUser?.userId ?? auth.currentUser?.username else {
                            viewModel.errorMessage = "Missing identifiers for posting."
                            return
                        }
                        if let _ = await viewModel.savePosting(editing: nil, orgId: orgId, creatorId: creatorId, form: form) {
                            showingCreateForm = false
                            creationForm = ManagedOvertimePostingFormState()
                        }
                    }
                }
            }
        }
    }

    private func postingRow(_ posting: ManagedOvertimePostingDTO, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(posting.title)
                    .font(.headline)
                Spacer()
                Text(posting.policy.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(accent)
            }
            Text(dateWindow(for: posting))
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Label("\(posting.openSlots) open of \(posting.slots)", systemImage: "person.3")
                    .font(.caption)
                Spacer()
                if let location = posting.location?.nilIfEmpty {
                    Label(location, systemImage: "mappin.circle")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func dateWindow(for posting: ManagedOvertimePostingDTO) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: posting.startsAt)) – \(formatter.string(from: posting.endsAt))"
    }
}

private struct ManagedOvertimePostingDetailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTint) private var appTint
    @ObservedObject var viewModel: ManagedOvertimeViewModel

    @State private var posting: ManagedOvertimePostingDTO
    @State private var showingEdit = false
    @State private var editForm = ManagedOvertimePostingFormState()
    @State private var showingForceAssign = false
    @State private var forceDraft = ForceAssignmentDraft()
    @State private var isRefreshing = false

    init(posting: ManagedOvertimePostingDTO, viewModel: ManagedOvertimeViewModel) {
        self._posting = State(initialValue: posting)
        self.viewModel = viewModel
    }

    private var canManage: Bool { auth.permissions.canPostEventAssignments }
    private var currentOfficerId: String? {
        auth.userProfile.badgeNumber?.nilIfEmpty ?? auth.currentUser?.userId ?? auth.currentUser?.username ?? auth.userProfile.email?.nilIfEmpty
    }
    private var currentUserSignup: OvertimeSignupDTO? {
        guard let identifier = currentOfficerId?.lowercased() else { return nil }
        return posting.signups.first { $0.officerId.lowercased() == identifier }
    }

    var body: some View {
        List {
            Section("Details") {
                detailRow(label: "Window", value: dateWindow(for: posting))
                detailRow(label: "Scenario", value: posting.scenario.rawValue.replacingOccurrences(of: "_", with: " "))
                detailRow(label: "Policy", value: posting.policy.displayName)
                detailRow(label: "Slots", value: "\(posting.slots)")
                if let deadline = posting.deadline {
                    detailRow(label: "Deadline", value: formatDate(deadline))
                }
                if let notes = posting.notes?.nilIfEmpty {
                    Text(notes)
                        .font(.callout)
                        .padding(.vertical, 4)
                }
            }

            Section("Signups") {
                if posting.signups.isEmpty {
                    Text("No signups yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedSignups()) { signup in
                        signupRow(signup)
                    }
                }
            }

            Section("Actions") {
                if posting.state == .open {
                    if currentUserSignup == nil, posting.openSlots > 0, let officerId = currentOfficerId, let orgId = auth.resolvedOrgId {
                        Button {
                            Task { await signUp(officerId: officerId, orgId: orgId) }
                        } label: {
                            Label("Sign Up", systemImage: "checkmark.circle")
                        }
                    }

                    if let signup = currentUserSignup {
                        Button(role: .destructive) {
                            Task { await withdraw(signup: signup) }
                        } label: {
                            Label("Withdraw My Signup", systemImage: "arrow.uturn.left")
                        }
                    }

                    if canManage {
                        Button {
                            forceDraft = ForceAssignmentDraft()
                            forceDraft.rank = auth.userProfile.rank ?? ""
                            showingForceAssign = true
                        } label: {
                            Label("Force Assign Officer", systemImage: "person.crop.circle.badge.exclam")
                        }
                    }
                }

                if canManage {
                    Button {
                        editForm = ManagedOvertimePostingFormState(posting: posting)
                        showingEdit = true
                    } label: {
                        Label("Edit Posting", systemImage: "pencil")
                    }

                    if posting.state == .open {
                        Button {
                            Task { await closePosting() }
                        } label: {
                            Label("Close Posting", systemImage: "lock")
                        }
                    }

                    Button(role: .destructive) {
                        Task { await deletePosting() }
                    } label: {
                        Label("Delete Posting", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(posting.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isRefreshing {
                    ProgressView()
                } else {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                ManagedOvertimePostingFormView(title: "Edit Posting", form: $editForm) {
                    showingEdit = false
                } onSubmit: { form in
                    Task {
                        if let updated = await viewModel.savePosting(editing: posting, orgId: posting.orgId, creatorId: posting.createdBy, form: form) {
                            posting = updated
                            showingEdit = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingForceAssign) {
            NavigationStack {
                ForceAssignmentSheet(draft: $forceDraft) {
                    showingForceAssign = false
                } onSubmit: { draft in
                    Task {
                        guard let supervisorId = auth.currentUser?.userId ?? auth.currentUser?.username else {
                            viewModel.errorMessage = "Missing supervisor identifier."
                            return
                        }
                        if let updated = await viewModel.forceAssign(posting: posting, draft: draft, supervisorId: supervisorId) {
                            posting = updated
                            showingForceAssign = false
                        }
                    }
                }
            }
        }
        .alert(
            "Special Details",
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

    private func sortedSignups() -> [OvertimeSignupDTO] {
        switch posting.policy {
        case .firstComeFirstServed:
            return posting.signups.sorted {
                ($0.submittedAt ?? Date.distantFuture) < ($1.submittedAt ?? Date.distantFuture)
            }
        case .seniority:
            return posting.signups.sorted {
                let lhs = ($0.rankPriority ?? Int.max, $0.tieBreakerKey ?? "")
                let rhs = ($1.rankPriority ?? Int.max, $1.tieBreakerKey ?? "")
                if lhs.0 == rhs.0 {
                    return lhs.1.localizedStandardCompare(rhs.1) == .orderedAscending
                }
                return lhs.0 < rhs.0
            }
        }
    }

    private func signupRow(_ signup: OvertimeSignupDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(signup.officerId)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(signup.status.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(signup.isForced ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
            }
            if let rank = signup.rank?.nilIfEmpty {
                Text(rank)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let badge = signup.badgeNumber?.nilIfEmpty {
                Text("Badge #\(badge)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let submitted = signup.submittedAt {
                Text("Submitted \(formatDate(submitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func dateWindow(for posting: ManagedOvertimePostingDTO) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: posting.startsAt)) – \(formatter.string(from: posting.endsAt))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let refreshed = await viewModel.refreshPosting(id: posting.id) {
            posting = refreshed
        }
    }

    private func signUp(officerId: String, orgId: String) async {
        if let updated = await viewModel.signUp(posting: posting, officerId: officerId, orgId: orgId, rank: auth.userProfile.rank, badgeNumber: auth.userProfile.badgeNumber) {
            posting = updated
        }
    }

    private func withdraw(signup: OvertimeSignupDTO) async {
        if let updated = await viewModel.withdraw(signup: signup) {
            posting = updated
        }
    }

    private func closePosting() async {
        if let updated = await viewModel.close(posting: posting) {
            posting = updated
        }
    }

    private func deletePosting() async {
        await viewModel.delete(posting: posting)
        dismiss()
    }
}

private struct ManagedOvertimePostingFormView: View {
    let title: String
    @Binding var form: ManagedOvertimePostingFormState
    let onCancel: () -> Void
    let onSubmit: (ManagedOvertimePostingFormState) -> Void

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $form.title)
                Picker("Scenario", selection: $form.scenario) {
                    ForEach(OvertimeScenarioKind.allCases, id: \.self) { scenario in
                        Text(scenario.rawValue.replacingOccurrences(of: "_", with: " "))
                            .tag(scenario)
                    }
                }
                Picker("Policy", selection: $form.policy) {
                    ForEach(OvertimePolicyKind.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                Stepper(value: $form.slots, in: 1...100) {
                    Text("Slots: \(form.slots)")
                }
            }

            Section("Schedule") {
                DatePicker("Starts", selection: $form.startsAt)
                DatePicker("Ends", selection: $form.endsAt)
                if form.deadline != nil {
                    DatePicker(
                        "Deadline",
                        selection: Binding(
                            get: { form.deadline ?? form.endsAt },
                            set: { form.deadline = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Button("Remove Deadline", role: .destructive) {
                        form.deadline = nil
                    }
                    .font(.caption)
                } else {
                    Button("Add Deadline") {
                        form.deadline = form.endsAt
                    }
                    .font(.caption)
                }
            }

            Section("Additional") {
                TextField("Location", text: $form.location)
                TextEditor(text: $form.notes)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSubmit(form) }
                    .disabled(!form.isValid)
            }
        }
    }
}

private struct ForceAssignmentSheet: View {
    @Binding var draft: ForceAssignmentDraft
    let onCancel: () -> Void
    let onSubmit: (ForceAssignmentDraft) -> Void

    var body: some View {
        Form {
            Section("Officer") {
                TextField("Officer Identifier", text: $draft.officerId)
                TextField("Badge / Computer #", text: $draft.badgeNumber)
                TextField("Rank", text: $draft.rank)
            }

            Section("Notes") {
                TextField("Reason", text: $draft.note)
            }
        }
        .navigationTitle("Force Assign")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { onSubmit(draft) }
                    .disabled(!draft.isValid)
            }
        }
    }
}

@MainActor
private final class ManagedOvertimeViewModel: ObservableObject {
    @Published private(set) var postings: [ManagedOvertimePostingDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private var orgId: String?

    var openPostings: [ManagedOvertimePostingDTO] {
        postings.filter { $0.state == .open }.sorted { $0.startsAt < $1.startsAt }
    }

    var closedPostings: [ManagedOvertimePostingDTO] {
        postings.filter { $0.state != .open }.sorted { $0.startsAt > $1.startsAt }
    }

    func load(orgId: String) async {
        guard !orgId.isEmpty else {
            postings = []
            return
        }
        self.orgId = orgId
        isLoading = true
        defer { isLoading = false }
        do {
            postings = try await ShiftlinkAPI.listManagedOvertimePostings(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reload() async {
        guard let orgId else { return }
        await load(orgId: orgId)
    }

    func savePosting(editing: ManagedOvertimePostingDTO?, orgId: String, creatorId: String, form: ManagedOvertimePostingFormState) async -> ManagedOvertimePostingDTO? {
        guard form.isValid else {
            errorMessage = "Please complete the form."
            return nil
        }
        self.orgId = orgId
        isWorking = true
        defer { isWorking = false }
        do {
            let dto: ManagedOvertimePostingDTO
            if let editing {
                dto = try await ShiftlinkAPI.updateManagedOvertimePosting(id: editing.id, input: form.asInput())
            } else {
                dto = try await ShiftlinkAPI.createManagedOvertimePosting(orgId: orgId, createdBy: creatorId, input: form.asInput())
            }
            replace(dto)
            return dto
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func refreshPosting(id: String) async -> ManagedOvertimePostingDTO? {
        do {
            let dto = try await ShiftlinkAPI.getManagedOvertimePosting(id: id)
            replace(dto)
            return dto
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func close(posting: ManagedOvertimePostingDTO) async -> ManagedOvertimePostingDTO? {
        isWorking = true
        defer { isWorking = false }
        do {
            let dto = try await ShiftlinkAPI.closeManagedOvertimePosting(id: posting.id)
            replace(dto)
            return dto
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(posting: ManagedOvertimePostingDTO) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await ShiftlinkAPI.deleteManagedOvertimePosting(id: posting.id)
            postings.removeAll { $0.id == posting.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forceAssign(posting: ManagedOvertimePostingDTO, draft: ForceAssignmentDraft, supervisorId: String) async -> ManagedOvertimePostingDTO? {
        let orgId = posting.orgId
        isWorking = true
        defer { isWorking = false }
        do {
            var input = NewOvertimeSignupInput(postingId: posting.id, orgId: orgId, officerId: draft.officerId)
            input.status = .forced
            input.rank = draft.rank.nilIfEmpty
            input.badgeNumber = draft.badgeNumber.nilIfEmpty
            input.tieBreakerKey = draft.badgeNumber.nilIfEmpty ?? draft.officerId
            input.forcedBy = supervisorId
            input.forcedReason = draft.note.nilIfEmpty
            _ = try await ShiftlinkAPI.createOvertimeSignup(input: input)
            return await refreshPosting(id: posting.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func signUp(posting: ManagedOvertimePostingDTO, officerId: String, orgId: String, rank: String?, badgeNumber: String?) async -> ManagedOvertimePostingDTO? {
        isWorking = true
        defer { isWorking = false }
        do {
            var input = NewOvertimeSignupInput(postingId: posting.id, orgId: orgId, officerId: officerId)
            input.rank = rank?.nilIfEmpty
            input.badgeNumber = badgeNumber?.nilIfEmpty
            input.tieBreakerKey = badgeNumber?.nilIfEmpty ?? officerId
            _ = try await ShiftlinkAPI.createOvertimeSignup(input: input)
            return await refreshPosting(id: posting.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func withdraw(signup: OvertimeSignupDTO) async -> ManagedOvertimePostingDTO? {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await ShiftlinkAPI.withdrawOvertimeSignup(id: signup.id)
            return await refreshPosting(id: signup.postingId)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func replace(_ posting: ManagedOvertimePostingDTO) {
        if let idx = postings.firstIndex(where: { $0.id == posting.id }) {
            postings[idx] = posting
        } else {
            postings.insert(posting, at: 0)
        }
    }
}

private struct ManagedOvertimePostingFormState {
    var title: String = ""
    var location: String = ""
    var scenario: OvertimeScenarioKind = .specialEvent
    var startsAt: Date = Date()
    var endsAt: Date = Date().addingTimeInterval(3600)
    var slots: Int = 1
    var policy: OvertimePolicyKind = .firstComeFirstServed
    var notes: String = ""
    var deadline: Date?

    init() {}

    init(posting: ManagedOvertimePostingDTO) {
        title = posting.title
        location = posting.location ?? ""
        scenario = posting.scenario
        startsAt = posting.startsAt
        endsAt = posting.endsAt
        slots = posting.slots
        policy = posting.policy
        notes = posting.notes ?? ""
        deadline = posting.deadline
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startsAt < endsAt && slots > 0
    }

    func asInput() -> NewManagedOvertimePostingInput {
        NewManagedOvertimePostingInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.nilIfEmpty,
            scenario: scenario,
            startsAt: startsAt,
            endsAt: endsAt,
            slots: slots,
            policy: policy,
            notes: notes.nilIfEmpty,
            deadline: deadline
        )
    }
}

private struct ForceAssignmentDraft {
    var officerId: String = ""
    var badgeNumber: String = ""
    var rank: String = ""
    var note: String = ""

    var isValid: Bool {
        !officerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            var day = calendar.startOfDay(for: entry.start)
            let endDay = calendar.startOfDay(for: entry.end)
            while day <= endDay {
                map[day, default: []].append(entry.kind)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return map
    }

    private func entries(for date: Date) -> [ShiftScheduleEntry] {
        let target = calendar.startOfDay(for: date)
        let matches = entries
            .filter {
                let startDay = calendar.startOfDay(for: $0.start)
                let endDay = calendar.startOfDay(for: $0.end)
                return target >= startDay && target <= endDay
            }
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
                calendarHeader
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
        .background(CalendarBackgroundView().ignoresSafeArea())
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
                    try await viewModel.addEvent(ownerId: ownerId, orgId: auth.resolvedOrgId, input: input)
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

private extension MyCalendarView {
    var calendarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My Calendar")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.footnote.weight(.semibold))
                Text("Private – Only visible to you")
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 8)
    }
}

private struct CalendarBackgroundView: View {
    var body: some View {
        Image("calendarbackground")
            .resizable()
            .scaledToFill()
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
            let events = try await CalendarService.fetchEvents(forOwnerIds: sanitized)
            entries = events.map { ShiftScheduleEntry(calendarEvent: $0) }
                .sorted { $0.start < $1.start }
        } catch {
            print("Failed to load calendar events", error)
        }
    }

    func addEvent(ownerId: String, orgId: String?, input: NewCalendarEventInput) async throws {
        let created = try await performCalendarMutation {
            try await CalendarService.createEvent(ownerId: ownerId, orgId: orgId, input: input)
        }
        entries.append(ShiftScheduleEntry(calendarEvent: created))
        entries.sort { $0.start < $1.start }
    }

    func updateEvent(ownerId: String, eventId: String, input: NewCalendarEventInput) async throws {
        let updated = try await performCalendarMutation {
            try await CalendarService.updateEvent(id: eventId, ownerId: ownerId, input: input)
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
            try await CalendarService.deleteEvent(id: eventId)
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

    init(
        focusDate: Date,
        defaultCategory: CalendarEventCategory = .personal,
        onSave: @escaping (NewCalendarEventInput) async throws -> Void
    ) {
        self.focusDate = focusDate
        self.onSave = onSave
        let defaultStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: focusDate) ?? focusDate
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultStart.addingTimeInterval(3600))
        _category = State(initialValue: defaultCategory)
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
        case .overtime: return "Special Details"
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
            case .overtime: return "Special Details"
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
                assignment: "Special Detail - Special Event",
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
                    Text("No special detail records match your filters.")
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
        .navigationTitle("Special Detail Audit")
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

@discardableResult
private func storeLockerFile(from sourceURL: URL) -> URL? {
    let fileManager = FileManager.default
    let folder = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("locker-files", isDirectory: true)
    do {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(sourceURL.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    } catch {
        print("Failed to persist locker file: \(error.localizedDescription)")
        return nil
    }
}
