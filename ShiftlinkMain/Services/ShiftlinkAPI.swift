//
//  ShiftlinkAPI.swift
//  ShiftlinkMain
//
//  Created by Codex on 11/5/25.
//

import Amplify
import Foundation

// MARK: - Data Transfer Objects

struct RosterEntryDTO: Identifiable {
    let id: String
    let orgId: String
    let badgeNumber: String
    let shift: String?
    let startsAt: Date
    let endsAt: Date

    var shiftLabel: String {
        shift?.isEmpty == false ? shift! : "Assigned Shift"
    }

    var durationDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: startsAt)) – \(formatter.string(from: endsAt))"
    }
}

struct VehicleDTO: Identifiable {
    let id: String
    let orgId: String
    let callsign: String
    let make: String?
    let model: String?
    let plate: String?
    let inService: Bool?

    var title: String { callsign }
    var subtitle: String {
        let parts = [make, model].compactMap { $0 }.joined(separator: " ")
        return parts.isEmpty ? (plate ?? "No details recorded") : parts
    }
}

struct OfficerAssignmentDTO: Identifiable {
    let id: String
    let orgId: String
    let badgeNumber: String
    let title: String
    let detail: String?
    let location: String?
    let notes: String?
    let updatedAt: Date?
    let profile: OfficerAssignmentProfile

    var displayName: String {
        if let name = profile.fullName, !name.isEmpty { return name }
        return "Officer #\(badgeNumber)"
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        let letters = components.prefix(2).compactMap { $0.first }
        let joined = letters.map { String($0) }.joined()
        return joined.isEmpty ? "ID" : joined.uppercased()
    }

    var rankDisplay: String {
        if let rank = profile.rank, !rank.isEmpty { return rank }
        if let detail, !detail.isEmpty { return detail }
        return "Rank Pending"
    }

    var assignmentDisplay: String {
        if title.isEmpty { return rankDisplay }
        return "\(rankDisplay) – \(title)"
    }

    var vehicleDisplay: String? {
        profile.vehicle?.isEmpty == false ? profile.vehicle : location
    }

    var specialAssignment: String? {
        profile.specialAssignment?.isEmpty == false ? profile.specialAssignment : nil
    }

    var departmentPhone: String? {
        profile.departmentPhone?.isEmpty == false ? profile.departmentPhone : nil
    }

    var departmentExtension: String? {
        profile.departmentExtension?.isEmpty == false ? profile.departmentExtension : nil
    }

    var departmentEmail: String? {
        profile.departmentEmail?.isEmpty == false ? profile.departmentEmail : nil
    }

    var squad: String? {
        profile.squad?.isEmpty == false ? profile.squad : nil
    }
}

struct OfficerAssignmentProfile: Codable {
    var fullName: String?
    var rank: String?
    var vehicle: String?
    var specialAssignment: String?
    var departmentPhone: String?
    var departmentExtension: String?
    var departmentEmail: String?
    var squad: String?
    var mfaVerified: Bool?
    var userId: String?
}

enum SquadRoleKind: String {
    case supervisor = "SUPERVISOR"
    case officer = "OFFICER"

    var displayName: String {
        switch self {
        case .supervisor: return "Supervisor"
        case .officer: return "Officer"
        }
    }
}

struct SquadMembershipDTO: Identifiable, Equatable {
    let id: String
    let squadId: String
    let userId: String
    var role: SquadRoleKind
    var isPrimary: Bool
    var isActive: Bool
}

struct SquadDTO: Identifiable, Equatable {
    let id: String
    let orgId: String
    var name: String
    var bureau: String
    var shift: String?
    var notes: String?
    var isActive: Bool
    var supervisorMemberships: [SquadMembershipDTO]
    var officerMemberships: [SquadMembershipDTO]

    var supervisorCount: Int {
        supervisorMemberships.filter { $0.isActive }.count
    }

    var officerCount: Int {
        officerMemberships.filter { $0.isActive }.count
    }
}

struct SquadDraftInput {
    var name: String
    var bureau: String
    var shift: String?
    var notes: String?
    var isActive: Bool = true
}

struct SquadMembershipInput {
    var squadId: String
    var userId: String
    var role: SquadRoleKind
    var isPrimary: Bool = true
    var isActive: Bool = true
}

struct DepartmentAlertPayload: Codable {
    var orgId: String
    var siteKey: String?
    var title: String
    var message: String
    var priority: String
}

struct MutationResponsePayload: Codable {
    let success: Bool
    let message: String?
}

struct NewRosterEntryInput {
    var orgId: String
    var badgeNumber: String
    var shift: String?
    var startsAt: Date
    var endsAt: Date
}

struct OvertimeJobDetails: Codable {
    var description: String
    var location: String
    var rate: String
    var contact: String?
    var postedBy: String?
    var postedByName: String?
}

struct OvertimePostingDTO: Identifiable {
    let id: String
    let orgId: String
    let ownerId: String
    let title: String
    let startsAt: Date
    let endsAt: Date
    let reminderMinutesBefore: Int?
    let postedAt: Date?
    let details: OvertimeJobDetails?

    var isClaimed: Bool {
        ownerId.caseInsensitiveCompare(ShiftlinkAPI.unassignedOwnerToken) != .orderedSame
    }

    var windowDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: startsAt)) - \(formatter.string(from: endsAt))"
    }
}

struct NewOvertimePostingInput {
    var title: String
    var description: String
    var location: String
    var rate: String
    var contact: String?
    var startsAt: Date
    var endsAt: Date
    var reminderMinutesBefore: Int?
    var priorityColorHex: String
}

enum OvertimePolicyKind: String, Codable, CaseIterable {
    case firstComeFirstServed = "FIRST_COME_FIRST_SERVED"
    case seniority = "SENIORITY"

    var displayName: String {
        switch self {
        case .firstComeFirstServed:
            return "First Come, First Served"
        case .seniority:
            return "Seniority"
        }
    }
}

enum OvertimeSignupStatusKind: String, Codable, CaseIterable {
    case pending = "PENDING"
    case confirmed = "CONFIRMED"
    case withdrawn = "WITHDRAWN"
    case forced = "FORCED"
}

enum OvertimeScenarioKind: String, Codable, CaseIterable {
    case patrolShortShift = "PATROL_SHORT_SHIFT"
    case sergeantShortShift = "SERGEANT_SHORT_SHIFT"
    case specialEvent = "SPECIAL_EVENT"
    case otherOvertime = "OTHER_OVERTIME"
}

enum OvertimePostingStateKind: String, Codable, CaseIterable {
    case open = "OPEN"
    case filled = "FILLED"
    case closed = "CLOSED"
}

struct ManagedOvertimePostingDTO: Identifiable {
    let id: String
    let orgId: String
    let title: String
    let location: String?
    let scenario: OvertimeScenarioKind
    let startsAt: Date
    let endsAt: Date
    let slots: Int
    let policy: OvertimePolicyKind
    let notes: String?
    let deadline: Date?
    let state: OvertimePostingStateKind
    let createdBy: String
    let createdAt: Date?
    let updatedAt: Date?
    let signups: [OvertimeSignupDTO]

    var openSlots: Int {
        max(0, slots - signups.filter { $0.isActive }.count)
    }
}

struct OvertimeSignupDTO: Identifiable {
    let id: String
    let postingId: String
    let officerId: String
    let status: OvertimeSignupStatusKind
    let rank: String?
    let rankPriority: Int?
    let badgeNumber: String?
    let tieBreakerKey: String?
    let submittedAt: Date?
    let forcedBy: String?
    let forcedReason: String?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    var isForced: Bool { status == .forced }

    var isActive: Bool {
        switch status {
        case .forced, .pending, .confirmed:
            return true
        case .withdrawn:
            return false
        }
    }
}

struct OvertimeAuditEventDTO: Identifiable {
    let id: String
    let postingId: String
    let type: String
    let details: [String: Any]?
    let createdBy: String?
    let createdAt: Date?
}

struct NewManagedOvertimePostingInput {
    var title: String
    var location: String?
    var scenario: OvertimeScenarioKind
    var startsAt: Date
    var endsAt: Date
    var slots: Int
    var policy: OvertimePolicyKind
    var notes: String?
    var deadline: Date?
}

struct NewOvertimeSignupInput {
    var postingId: String
    var orgId: String
    var officerId: String
    var status: OvertimeSignupStatusKind = .pending
    var rank: String?
    var badgeNumber: String?
    var tieBreakerKey: String?
    var rankPriority: Int?
    var notes: String?
    var forcedBy: String?
    var forcedReason: String?
}

struct CalendarEventDTO: Identifiable, Equatable {
    let id: String
    let ownerId: String
    let orgId: String?
    let title: String
    let category: String
    let colorHex: String?
    let notes: String?
    let startsAt: Date
    let endsAt: Date
    let reminderMinutesBefore: Int?
}

struct NewCalendarEventInput {
    var title: String
    var category: String
    var colorHex: String?
    var notes: String?
    var startsAt: Date
    var endsAt: Date
    var reminderMinutesBefore: Int?

    init(
        title: String,
        startsAt: Date,
        endsAt: Date,
        category: String,
        colorHex: String? = nil,
        notes: String? = nil,
        reminderMinutesBefore: Int? = nil
    ) {
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.category = category
        self.colorHex = colorHex
        self.notes = notes
        self.reminderMinutesBefore = reminderMinutesBefore
    }

    func graphQLPayload(ownerId: String, orgId: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "ownerId": ownerId,
            "title": title,
            "category": category,
            "startsAt": ShiftlinkAPI.encode(date: startsAt),
            "endsAt": ShiftlinkAPI.encode(date: endsAt)
        ]
        if let orgId, !orgId.isEmpty {
            payload["orgId"] = orgId
        }
        if let colorHex, !colorHex.isEmpty {
            payload["color"] = colorHex
        }
        if let notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            payload["notes"] = notes
        }
        if let reminder = reminderMinutesBefore {
            payload["reminderMinutesBefore"] = reminder
        }
        return payload
    }
}

struct NotificationPreferenceDTO: Equatable {
    var id: String?
    var userId: String
    var generalBulletin: Bool = true
    var taskAlert: Bool = true
    var overtime: Bool = true
    var squadMessages: Bool = true
    var other: Bool = true
    var contactPhone: String?
    var contactEmail: String?
    var backupEmail: String?

    static func placeholder(userId: String) -> NotificationPreferenceDTO {
        NotificationPreferenceDTO(userId: userId)
    }
}

enum ShiftlinkAPIError: LocalizedError {
    case missingIdentifiers
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingIdentifiers:
            return "Missing the identifiers required to perform this action."
        case .malformedResponse:
            return "Received an unexpected response from the server."
        }
    }
}

enum ShiftlinkAPI {
    static let overtimeCategory = "OVERTIME"
    static let unassignedOwnerToken = "__UNASSIGNED_OWNER__"
}

enum NotificationCategoryKind: String {
    case overtimePosted = "OVERTIME_POSTED"
    case overtimeReminder = "OVERTIME_REMINDER"
    case overtimeForceAssign = "OVERTIME_FORCE_ASSIGN"
    case squadAlert = "SQUAD_ALERT"
    case taskAlert = "TASK_ALERT"
    case bulletin = "BULLETIN"
}

private struct ListOvertimeAuditsResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [OvertimeAuditEventRecord]
        let nextToken: String?
    }
    let auditsByPosting: ItemsContainer?
}

private struct CreateOvertimeAuditEventResponse: Decodable {
    let createOvertimeAuditEvent: OvertimeAuditEventRecord
}

private struct OvertimeAuditEventRecord: Decodable {
    let id: String
    let postingId: String
    let type: String
    let details: String?
    let createdBy: String?
    let createdAt: String?
}

private struct NotifyOvertimeEventResponse: Decodable {
    let notifyOvertimeEvent: NotificationSendResultRecord?
}

private struct SendNotificationResponse: Decodable {
    let sendNotification: NotificationSendResultRecord?
}

struct NotificationSendResultRecord: Decodable {
    let success: Bool?
    let delivered: Int?
    let recipientCount: Int?
    let message: String?
}

private struct ManagedOvertimePostingsByOrgResponse: Decodable {
    let overtimePostingsByOrg: ManagedOvertimePostingConnection?
}

private struct ManagedOvertimePostingConnection: Decodable {
    let items: [ManagedOvertimePostingRecord?]
    let nextToken: String?
}

private struct ManagedOvertimePostingRecord: Decodable {
    let id: String
    let orgId: String
    let title: String
    let location: String?
    let scenario: String
    let startsAt: String
    let endsAt: String
    let slots: Int
    let policy: String
    let notes: String?
    let deadline: String?
    let state: String
    let createdBy: String
    let createdAt: String?
    let updatedAt: String?
    let signups: OvertimeSignupConnection?
}

private struct OvertimeSignupConnection: Decodable {
    let items: [OvertimeSignupRecord?]
    let nextToken: String?
}

private struct OvertimeSignupRecord: Decodable {
    let id: String
    let postingId: String
    let orgId: String
    let officerId: String
    let status: String
    let rank: String?
    let rankPriority: Int?
    let badgeNumber: String?
    let tieBreakerKey: String?
    let submittedAt: String?
    let forcedBy: String?
    let forcedReason: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?
}

private struct GetManagedOvertimePostingResponse: Decodable {
    let getOvertimePosting: ManagedOvertimePostingRecord?
}

private struct CreateManagedOvertimePostingResponse: Decodable {
    let createOvertimePosting: ManagedOvertimePostingRecord?
}

private struct UpdateManagedOvertimePostingResponse: Decodable {
    let updateOvertimePosting: ManagedOvertimePostingRecord?
}

private struct DeleteManagedOvertimePostingResponse: Decodable {
    let deleteOvertimePosting: ManagedOvertimePostingRecord?
}

private struct CreateOvertimeSignupResponse: Decodable {
    let createOvertimeSignup: OvertimeSignupRecord?
}

private struct UpdateOvertimeSignupResponse: Decodable {
    let updateOvertimeSignup: OvertimeSignupRecord?
}

private struct CalendarEventsConnection: Decodable {
    let items: [CalendarEventRecord?]
    let nextToken: String?
}

private struct ListCalendarEventsResponse: Decodable {
    let listCalendarEvents: CalendarEventsConnection?
}

private struct CalendarEventRecord: Decodable {
    let id: String
    let orgId: String?
    let ownerId: String
    let title: String
    let category: String
    let color: String?
    let notes: String?
    let startsAt: String
    let endsAt: String
    let reminderMinutesBefore: Int?
    let createdAt: String?
    let updatedAt: String?
}

private struct CreateCalendarEventResponse: Decodable {
    let createCalendarEvent: CalendarEventRecord?
}

private struct UpdateCalendarEventResponse: Decodable {
    let updateCalendarEvent: CalendarEventRecord?
}

private struct DeleteCalendarEventResponse: Decodable {
    let deleteCalendarEvent: CalendarEventRecord?
}

private struct RosterEntriesConnection: Decodable {
    let items: [RosterEntryRecord?]
    let nextToken: String?
}

private struct ListRosterEntriesResponse: Decodable {
    let listRosterEntries: RosterEntriesConnection?
}

private struct CreateRosterEntryResponse: Decodable {
    let createRosterEntry: RosterEntryRecord?
}

private struct DeleteRosterEntryResponse: Decodable {
    let deleteRosterEntry: RosterEntryRecord?
}

private struct RosterEntryRecord: Decodable {
    let id: String
    let orgId: String
    let badgeNumber: String
    let shift: String?
    let startsAt: String
    let endsAt: String
}

private struct AssignmentsConnection: Decodable {
    let items: [OfficerAssignmentRecord?]
    let nextToken: String?
}

private struct AssignmentsByOrgResponse: Decodable {
    let assignmentsByOrg: AssignmentsConnection?
}

private struct AssignmentsByOfficerResponse: Decodable {
    let assignmentsByOfficer: AssignmentsConnection?
}

private struct CreateOfficerAssignmentResponse: Decodable {
    let createOfficerAssignment: OfficerAssignmentRecord?
}

private struct UpdateOfficerAssignmentResponse: Decodable {
    let updateOfficerAssignment: OfficerAssignmentRecord?
}

private struct DeleteOfficerAssignmentResponse: Decodable {
    let deleteOfficerAssignment: OfficerAssignmentRecord?
}

private struct OfficerAssignmentRecord: Decodable {
    let id: String
    let orgId: String
    let badgeNumber: String
    let title: String
    let detail: String?
    let location: String?
    let notes: String?
    let updatedAt: String?
}

private struct SquadRecord: Decodable {
    struct MembershipConnection: Decodable {
        let items: [SquadMembershipRecord?]?
    }

    let id: String
    let orgId: String
    let name: String
    let bureau: String
    let shift: String?
    let notes: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
    let memberships: MembershipConnection?
}

private struct SquadMembershipRecord: Decodable {
    let id: String
    let squadId: String
    let userId: String
    let roleInSquad: String
    let isPrimary: Bool?
    let isActive: Bool?
}

private struct SquadConnection: Decodable {
    let items: [SquadRecord?]?
    let nextToken: String?
}

private struct ListSquadsResponse: Decodable {
    let listSquads: SquadConnection?
}

private struct GetSquadResponse: Decodable {
    let getSquad: SquadRecord?
}

private struct CreateSquadResponse: Decodable {
    let createSquad: SquadRecord?
}

private struct UpdateSquadResponse: Decodable {
    let updateSquad: SquadRecord?
}

private struct CreateSquadMembershipResponse: Decodable {
    let createSquadMembership: SquadMembershipRecord?
}

private struct UpdateSquadMembershipResponse: Decodable {
    let updateSquadMembership: SquadMembershipRecord?
}

private struct DeleteSquadMembershipResponse: Decodable {
    let deleteSquadMembership: SquadMembershipRecord?
}

private struct SquadMembershipsByUserResponse: Decodable {
    struct Connection: Decodable {
        let items: [SquadMembershipRecord?]
        let nextToken: String?
    }
    let squadMembershipsByUser: Connection?
}

private struct SquadMembershipsBySquadResponse: Decodable {
    struct Connection: Decodable {
        let items: [SquadMembershipRecord?]
        let nextToken: String?
    }
    let squadMembershipsBySquad: Connection?
}

private struct NotificationPreferenceConnection: Decodable {
    let items: [NotificationPreferenceRecord?]
    let nextToken: String?
}

private struct UpdateNotificationMessageResponse: Decodable {
    let updateNotificationMessage: NotificationMessageRecord?
}

private struct DeleteNotificationMessageResponse: Decodable {
    let deleteNotificationMessage: NotificationMessageRecord?
}

private struct NotificationPreferencesByUserResponse: Decodable {
    let notificationPreferencesByUser: NotificationPreferenceConnection?
}

private struct CreateNotificationPreferenceResponse: Decodable {
    let createNotificationPreference: NotificationPreferenceRecord?
}

private struct UpdateNotificationPreferenceResponse: Decodable {
    let updateNotificationPreference: NotificationPreferenceRecord?
}

private struct NotificationPreferenceRecord: Decodable {
    let id: String
    let userId: String
    let generalBulletin: Bool
    let taskAlert: Bool
    let overtime: Bool
    let squadMessages: Bool
    let other: Bool
    let contactPhone: String?
    let contactEmail: String?
    let backupEmail: String?
}

struct NotificationMessageRecord: Decodable {
    let id: String
    let orgId: String
    let title: String
    let body: String
    let category: String
    let recipients: [String]?
    let metadata: String?
    let createdBy: String
    let createdAt: String?
    let updatedAt: String?
}

struct NotificationMessagesByOrgResponse: Decodable {
    struct Connection: Decodable {
        let items: [NotificationMessageRecord?]
        let nextToken: String?
    }
    let notificationMessagesByOrg: Connection?
}

struct NotificationReceiptRecord: Decodable {
    let id: String
    let notificationId: String
    let userId: String
    let orgId: String
    let isRead: Bool
    let readAt: String?
}

struct NotificationReceiptsByUserResponse: Decodable {
    struct Connection: Decodable {
        let items: [NotificationReceiptRecord?]
        let nextToken: String?
    }
    let notificationReceiptsByUser: Connection?
}

private struct CreateNotificationMessageResponse: Decodable {
    let createNotificationMessage: NotificationMessageRecord?
}

private struct CreateNotificationReceiptResponse: Decodable {
    let createNotificationReceipt: NotificationReceiptRecord?
}

private struct UpdateNotificationReceiptResponse: Decodable {
    let updateNotificationReceipt: NotificationReceiptRecord?
}

extension ShiftlinkAPI {
    // MARK: Managed Overtime opportunities (FCFS + Seniority)

    static func listManagedOvertimePostings(
        orgId: String,
        state: OvertimePostingStateKind? = nil,
        limit: Int = 50
    ) async throws -> [ManagedOvertimePostingDTO] {
        var variables: [String: Any] = [
            "orgId": orgId,
            "sortDirection": "ASC",
            "limit": min(limit, 200)
        ]
        if let state {
            variables["filter"] = ["state": ["eq": state.rawValue]]
        }

        let request = GraphQLRequest<ManagedOvertimePostingsByOrgResponse>(
            document: Self.managedOvertimePostingsByOrgDocument,
            variables: variables,
            responseType: ManagedOvertimePostingsByOrgResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let records = payload.overtimePostingsByOrg?.items.compactMap { $0 } ?? []
            return records.compactMap(Self.makeManagedPostingDTO(from:))
        case .failure(let error):
            throw error
        }
    }

    static func getManagedOvertimePosting(id: String) async throws -> ManagedOvertimePostingDTO {
        let request = GraphQLRequest<GetManagedOvertimePostingResponse>(
            document: Self.getManagedOvertimePostingDocument,
            variables: ["id": id],
            responseType: GetManagedOvertimePostingResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.getOvertimePosting,
                  let dto = Self.makeManagedPostingDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func createManagedOvertimePosting(
        orgId: String,
        createdBy: String,
        input: NewManagedOvertimePostingInput
    ) async throws -> ManagedOvertimePostingDTO {
        var payload: [String: Any] = [
            "orgId": orgId,
            "title": input.title,
            "scenario": input.scenario.rawValue,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt),
            "slots": input.slots,
            "policy": input.policy.rawValue,
            "createdBy": createdBy
        ]
        payload["location"] = input.location
        payload["notes"] = input.notes
        payload["deadline"] = input.deadline.map(encode(date:))

        let request = GraphQLRequest<CreateManagedOvertimePostingResponse>(
            document: Self.createManagedOvertimePostingDocument,
            variables: ["input": payload],
            responseType: CreateManagedOvertimePostingResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.createOvertimePosting,
                  let dto = Self.makeManagedPostingDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func updateManagedOvertimePosting(
        id: String,
        input: NewManagedOvertimePostingInput
    ) async throws -> ManagedOvertimePostingDTO {
        var payload: [String: Any] = [
            "id": id,
            "title": input.title,
            "scenario": input.scenario.rawValue,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt),
            "slots": input.slots,
            "policy": input.policy.rawValue
        ]
        payload["location"] = input.location
        payload["notes"] = input.notes
        payload["deadline"] = input.deadline.map(encode(date:))

        let request = GraphQLRequest<UpdateManagedOvertimePostingResponse>(
            document: Self.updateManagedOvertimePostingDocument,
            variables: ["input": payload],
            responseType: UpdateManagedOvertimePostingResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimePosting,
                  let dto = Self.makeManagedPostingDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func closeManagedOvertimePosting(id: String) async throws -> ManagedOvertimePostingDTO {
        let request = GraphQLRequest<UpdateManagedOvertimePostingResponse>(
            document: Self.updateManagedOvertimePostingDocument,
            variables: ["input": ["id": id, "state": OvertimePostingStateKind.closed.rawValue]],
            responseType: UpdateManagedOvertimePostingResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimePosting,
                  let dto = Self.makeManagedPostingDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func deleteManagedOvertimePosting(id: String) async throws {
        let request = GraphQLRequest<DeleteManagedOvertimePostingResponse>(
            document: Self.deleteManagedOvertimePostingDocument,
            variables: ["input": ["id": id]],
            responseType: DeleteManagedOvertimePostingResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        if case .failure(let error) = result {
            throw error
        }
    }

    static func createOvertimeSignup(input: NewOvertimeSignupInput) async throws -> OvertimeSignupDTO {
        var payload: [String: Any] = [
            "postingId": input.postingId,
            "orgId": input.orgId,
            "officerId": input.officerId,
            "status": input.status.rawValue,
            "submittedAt": encode(date: Date())
        ]
        payload["rank"] = input.rank
        payload["rankPriority"] = input.rankPriority ?? rankPriority(for: input.rank)
        payload["badgeNumber"] = input.badgeNumber
        payload["tieBreakerKey"] = input.tieBreakerKey ?? input.badgeNumber ?? input.officerId
        payload["notes"] = input.notes
        payload["forcedBy"] = input.forcedBy
        payload["forcedReason"] = input.forcedReason

        let request = GraphQLRequest<CreateOvertimeSignupResponse>(
            document: Self.createOvertimeSignupDocument,
            variables: ["input": payload],
            responseType: CreateOvertimeSignupResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.createOvertimeSignup,
                  let dto = Self.makeOvertimeSignupDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func updateOvertimeSignup(
        id: String,
        status: OvertimeSignupStatusKind,
        notes: String? = nil,
        forcedBy: String? = nil,
        forcedReason: String? = nil
    ) async throws -> OvertimeSignupDTO {
        var payload: [String: Any] = [
            "id": id,
            "status": status.rawValue
        ]
        payload["notes"] = notes
        payload["forcedBy"] = forcedBy
        payload["forcedReason"] = forcedReason

        let request = GraphQLRequest<UpdateOvertimeSignupResponse>(
            document: Self.updateOvertimeSignupDocument,
            variables: ["input": payload],
            responseType: UpdateOvertimeSignupResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimeSignup,
                  let dto = Self.makeOvertimeSignupDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func withdrawOvertimeSignup(id: String) async throws -> OvertimeSignupDTO {
        try await updateOvertimeSignup(id: id, status: .withdrawn)
    }

    // MARK: - Legacy Calendar-backed overtime board

    static func listOvertimePostings(orgId: String, limit: Int = 200) async throws -> [OvertimePostingDTO] {
        var filter: [String: Any] = [
            "category": ["eq": overtimeCategory]
        ]
        if !orgId.isEmpty {
            filter["orgId"] = ["eq": orgId]
        }

        let request = GraphQLRequest<ListCalendarEventsResponse>(
            document: Self.listCalendarEventsDocument,
            variables: ["filter": filter, "limit": min(limit, 500)],
            responseType: ListCalendarEventsResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let records = payload.listCalendarEvents?.items.compactMap { $0 } ?? []
            return records.compactMap(Self.makeOvertimePostingDTO)
        case .failure(let error):
            throw error
        }
    }

    static func listCalendarEvents(ownerIds: [String]) async throws -> [CalendarEventDTO] {
        guard !ownerIds.isEmpty else { return [] }
        var filter: [String: Any] = [:]
        if ownerIds.count == 1, let owner = ownerIds.first {
            filter["ownerId"] = ["eq": owner]
        } else {
            filter["or"] = ownerIds.map { ["ownerId": ["eq": $0]] }
        }

        let request = GraphQLRequest<ListCalendarEventsResponse>(
            document: Self.listCalendarEventsDocument,
            variables: ["filter": filter],
            responseType: ListCalendarEventsResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let records = payload.listCalendarEvents?.items.compactMap { $0 } ?? []
            return records.compactMap(Self.makeCalendarEventDTO)
        case .failure(let error):
            throw error
        }
    }

    static func createCalendarEvent(ownerId: String, orgId: String?, input: NewCalendarEventInput) async throws -> CalendarEventDTO {
        let payload = input.graphQLPayload(ownerId: ownerId, orgId: orgId)
        let request = GraphQLRequest<CreateCalendarEventResponse>(
            document: Self.createCalendarEventDocument,
            variables: ["input": payload],
            responseType: CreateCalendarEventResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createCalendarEvent,
                  let dto = Self.makeCalendarEventDTO(record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func updateCalendarEvent(id: String, ownerId: String, input: NewCalendarEventInput) async throws -> CalendarEventDTO {
        var payload = input.graphQLPayload(ownerId: ownerId, orgId: nil)
        payload["id"] = id
        let request = GraphQLRequest<UpdateCalendarEventResponse>(
            document: Self.updateCalendarEventDocument,
            variables: ["input": payload],
            responseType: UpdateCalendarEventResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateCalendarEvent,
                  let dto = Self.makeCalendarEventDTO(record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func deleteCalendarEvent(id: String) async throws {
        let request = GraphQLRequest<DeleteCalendarEventResponse>(
            document: Self.deleteCalendarEventDocument,
            variables: ["input": ["id": id]],
            responseType: DeleteCalendarEventResponse.self
        )
        let response = try await Amplify.API.mutate(request: request)
        if case .failure(let error) = response {
            throw error
        }
    }

    // MARK: - Assignments & roster

    static func listAssignments(orgId: String, limit: Int = 500) async throws -> [OfficerAssignmentDTO] {
        let request = GraphQLRequest<AssignmentsByOrgResponse>(
            document: Self.assignmentsByOrgDocument,
            variables: [
                "orgId": orgId,
                "limit": min(limit, 500),
                "sortDirection": "ASC"
            ],
            responseType: AssignmentsByOrgResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            let records = payload.assignmentsByOrg?.items.compactMap { $0 } ?? []
            return records.compactMap(Self.makeOfficerAssignmentDTO)
        case .failure(let error):
            throw error
        }
    }

    static func fetchCurrentAssignment(orgId: String, badgeNumber: String) async throws -> OfficerAssignmentDTO? {
        let request = GraphQLRequest<AssignmentsByOfficerResponse>(
            document: Self.assignmentsByOfficerDocument,
            variables: [
                "badgeNumber": badgeNumber,
                "limit": 1,
                "sortDirection": "DESC"
            ],
            responseType: AssignmentsByOfficerResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.assignmentsByOfficer?.items.compactMap({ $0 }).first else {
                return nil
            }
            return Self.makeOfficerAssignmentDTO(record)
        case .failure(let error):
            throw error
        }
    }

    static func upsertAssignment(
        for badgeNumber: String,
        orgId: String,
        assignmentTitle: String,
        rank: String?,
        vehicle: String?,
        profile: OfficerAssignmentProfile
    ) async throws -> OfficerAssignmentDTO {
        if let existing = try await fetchCurrentAssignment(orgId: orgId, badgeNumber: badgeNumber) {
            return try await updateAssignment(
                id: existing.id,
                orgId: orgId,
                badgeNumber: badgeNumber,
                assignmentTitle: assignmentTitle,
                rank: rank,
                vehicle: vehicle,
                profile: profile
            )
        } else {
            return try await createAssignment(
                orgId: orgId,
                badgeNumber: badgeNumber,
                assignmentTitle: assignmentTitle,
                rank: rank,
                vehicle: vehicle,
                profile: profile
            )
        }
    }

    static func deleteAssignment(id: String) async throws {
        let request = GraphQLRequest<DeleteOfficerAssignmentResponse>(
            document: Self.deleteOfficerAssignmentDocument,
            variables: ["input": ["id": id]],
            responseType: DeleteOfficerAssignmentResponse.self
        )
        let response = try await Amplify.API.mutate(request: request)
        if case .failure(let error) = response {
            throw error
        }
    }

    static func listRosterEntries(orgId: String?, badgeNumber: String? = nil) async throws -> [RosterEntryDTO] {
        guard let orgId, !orgId.isEmpty else { return [] }
        var filter: [String: Any] = ["orgId": ["eq": orgId]]
        if let badge = badgeNumber, !badge.isEmpty {
            filter["badgeNumber"] = ["eq": badge]
        }

        let request = GraphQLRequest<ListRosterEntriesResponse>(
            document: Self.listRosterEntriesDocument,
            variables: ["filter": filter],
            responseType: ListRosterEntriesResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            let records = payload.listRosterEntries?.items.compactMap { $0 } ?? []
            return records.compactMap(Self.makeRosterEntryDTO)
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Notification preferences

    static func fetchNotificationPreferences(userId: String) async throws -> NotificationPreferenceDTO? {
        let request = GraphQLRequest<NotificationPreferencesByUserResponse>(
            document: Self.notificationPreferencesByUserDocument,
            variables: ["userId": userId, "limit": 1],
            responseType: NotificationPreferencesByUserResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.notificationPreferencesByUser?.items.compactMap({ $0 }).first else {
                return nil
            }
            return Self.makeNotificationPreferenceDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    static func upsertNotificationPreferences(_ prefs: NotificationPreferenceDTO) async throws -> NotificationPreferenceDTO {
        var draft = prefs
        if let existing = try await fetchNotificationPreferences(userId: prefs.userId) {
            draft.id = existing.id ?? prefs.id
        }

        if let identifier = draft.id {
            return try await updateNotificationPreference(id: identifier, payload: draft)
        } else {
            return try await createNotificationPreference(payload: draft)
        }
    }

    // MARK: - Helpers for assignments & preferences

    private static func createAssignment(
        orgId: String,
        badgeNumber: String,
        assignmentTitle: String,
        rank: String?,
        vehicle: String?,
        profile: OfficerAssignmentProfile
    ) async throws -> OfficerAssignmentDTO {
        let input = assignmentPayload(
            orgId: orgId,
            badgeNumber: badgeNumber,
            assignmentTitle: assignmentTitle,
            rank: rank,
            vehicle: vehicle,
            profile: profile
        )

        let request = GraphQLRequest<CreateOfficerAssignmentResponse>(
            document: Self.createOfficerAssignmentDocument,
            variables: ["input": input],
            responseType: CreateOfficerAssignmentResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createOfficerAssignment else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return Self.makeOfficerAssignmentDTO(record)
        case .failure(let error):
            throw error
        }
    }

    private static func updateAssignment(
        id: String,
        orgId: String,
        badgeNumber: String,
        assignmentTitle: String,
        rank: String?,
        vehicle: String?,
        profile: OfficerAssignmentProfile
    ) async throws -> OfficerAssignmentDTO {
        var input = assignmentPayload(
            orgId: orgId,
            badgeNumber: badgeNumber,
            assignmentTitle: assignmentTitle,
            rank: rank,
            vehicle: vehicle,
            profile: profile
        )
        input["id"] = id

        let request = GraphQLRequest<UpdateOfficerAssignmentResponse>(
            document: Self.updateOfficerAssignmentDocument,
            variables: ["input": input],
            responseType: UpdateOfficerAssignmentResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateOfficerAssignment else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return Self.makeOfficerAssignmentDTO(record)
        case .failure(let error):
            throw error
        }
    }

    private static func assignmentPayload(
        orgId: String,
        badgeNumber: String,
        assignmentTitle: String,
        rank: String?,
        vehicle: String?,
        profile: OfficerAssignmentProfile
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "orgId": orgId,
            "badgeNumber": badgeNumber,
            "title": assignmentTitle
        ]
        if let rank, !rank.isEmpty {
            payload["detail"] = rank
        }
        if let vehicle, !vehicle.isEmpty {
            payload["location"] = vehicle
        }
        if let encoded = encodeAssignmentProfile(profile) {
            payload["notes"] = encoded
        }
        payload["updatedAt"] = encode(date: Date())
        return payload
    }

    private static func createNotificationPreference(payload: NotificationPreferenceDTO) async throws -> NotificationPreferenceDTO {
        let request = GraphQLRequest<CreateNotificationPreferenceResponse>(
            document: Self.createNotificationPreferenceDocument,
            variables: ["input": notificationPreferencePayload(payload, includeId: false)],
            responseType: CreateNotificationPreferenceResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createNotificationPreference else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return Self.makeNotificationPreferenceDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    private static func updateNotificationPreference(id: String, payload: NotificationPreferenceDTO) async throws -> NotificationPreferenceDTO {
        var input = notificationPreferencePayload(payload, includeId: true)
        input["id"] = id

        let request = GraphQLRequest<UpdateNotificationPreferenceResponse>(
            document: Self.updateNotificationPreferenceDocument,
            variables: ["input": input],
            responseType: UpdateNotificationPreferenceResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateNotificationPreference else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return Self.makeNotificationPreferenceDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    private static func notificationPreferencePayload(_ prefs: NotificationPreferenceDTO, includeId: Bool) -> [String: Any] {
        var input: [String: Any] = [
            "userId": prefs.userId,
            "generalBulletin": prefs.generalBulletin,
            "taskAlert": prefs.taskAlert,
            "overtime": prefs.overtime,
            "squadMessages": prefs.squadMessages,
            "other": prefs.other
        ]
        if includeId, let id = prefs.id {
            input["id"] = id
        }
        if let phone = prefs.contactPhone, !phone.isEmpty {
            input["contactPhone"] = phone
        }
        if let email = prefs.contactEmail, !email.isEmpty {
            input["contactEmail"] = email
        }
        if let backup = prefs.backupEmail, !backup.isEmpty {
            input["backupEmail"] = backup
        }
        return input
    }

    // MARK: - Squad management

    static func listSquads(orgId: String, includeInactive: Bool = false) async throws -> [SquadDTO] {
        var filter: [String: Any] = ["orgId": ["eq": orgId]]
        if !includeInactive {
            filter["isActive"] = ["eq": true]
        }
        let request = GraphQLRequest<ListSquadsResponse>(
            document: Self.listSquadsDocument,
            variables: [
                "filter": filter,
                "limit": 200
            ],
            responseType: ListSquadsResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            let records = payload.listSquads?.items?.compactMap { $0 } ?? []
            return records.compactMap { makeSquadDTO(from: $0) }
                .sorted { lhs, rhs in
                    let bureauComparison = lhs.bureau.localizedCaseInsensitiveCompare(rhs.bureau)
                    if bureauComparison == .orderedSame {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return bureauComparison == .orderedAscending
                }
        case .failure(let error):
            throw error
        }
    }

    static func getSquad(id: String) async throws -> SquadDTO? {
        let request = GraphQLRequest<GetSquadResponse>(
            document: Self.getSquadDocument,
            variables: ["id": id],
            responseType: GetSquadResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.getSquad else { return nil }
            return makeSquadDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    static func createSquad(orgId: String, input: SquadDraftInput) async throws -> SquadDTO {
        let request = GraphQLRequest<CreateSquadResponse>(
            document: Self.createSquadDocument,
            variables: ["input": squadInputPayload(orgId: orgId, input: input)],
            responseType: CreateSquadResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createSquad else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return makeSquadDTO(from: record, includeMemberships: false)
        case .failure(let error):
            throw error
        }
    }

    static func updateSquad(id: String, input: SquadDraftInput) async throws -> SquadDTO {
        var payload = squadInputPayload(orgId: nil, input: input)
        payload["id"] = id
        let request = GraphQLRequest<UpdateSquadResponse>(
            document: Self.updateSquadDocument,
            variables: ["input": payload],
            responseType: UpdateSquadResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateSquad else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return makeSquadDTO(from: record, includeMemberships: false)
        case .failure(let error):
            throw error
        }
    }

    static func listSquadMembershipsByUser(
        userId: String,
        includeInactive: Bool = false,
        role: SquadRoleKind? = nil
    ) async throws -> [SquadMembershipDTO] {
        var variables: [String: Any] = [
            "userId": userId,
            "limit": 200
        ]
        if let filter = membershipFilter(includeInactive: includeInactive, role: role) {
            variables["filter"] = filter
        }
        let request = GraphQLRequest<SquadMembershipsByUserResponse>(
            document: Self.squadMembershipsByUserDocument,
            variables: variables,
            responseType: SquadMembershipsByUserResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            return payload.squadMembershipsByUser?.items.compactMap { $0 }.compactMap(makeMembershipDTO) ?? []
        case .failure(let error):
            throw error
        }
    }

    static func listSquadMembershipsBySquad(
        squadId: String,
        includeInactive: Bool = false
    ) async throws -> [SquadMembershipDTO] {
        var variables: [String: Any] = [
            "squadId": squadId,
            "limit": 200
        ]
        if let filter = membershipFilter(includeInactive: includeInactive, role: nil) {
            variables["filter"] = filter
        }
        let request = GraphQLRequest<SquadMembershipsBySquadResponse>(
            document: Self.squadMembershipsBySquadDocument,
            variables: variables,
            responseType: SquadMembershipsBySquadResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            return payload.squadMembershipsBySquad?.items.compactMap { $0 }.compactMap(makeMembershipDTO) ?? []
        case .failure(let error):
            throw error
        }
    }

    static func createSquadMembership(input: SquadMembershipInput) async throws -> SquadMembershipDTO {
        let request = GraphQLRequest<CreateSquadMembershipResponse>(
            document: Self.createSquadMembershipDocument,
            variables: ["input": squadMembershipPayload(input)],
            responseType: CreateSquadMembershipResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createSquadMembership, let dto = makeMembershipDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func updateSquadMembership(
        id: String,
        role: SquadRoleKind? = nil,
        isPrimary: Bool? = nil,
        isActive: Bool? = nil
    ) async throws -> SquadMembershipDTO {
        var payload: [String: Any] = ["id": id]
        if let role {
            payload["roleInSquad"] = role.rawValue
        }
        if let isPrimary {
            payload["isPrimary"] = isPrimary
        }
        if let isActive {
            payload["isActive"] = isActive
        }
        let request = GraphQLRequest<UpdateSquadMembershipResponse>(
            document: Self.updateSquadMembershipDocument,
            variables: ["input": payload],
            responseType: UpdateSquadMembershipResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateSquadMembership, let dto = makeMembershipDTO(from: record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func deleteSquadMembership(id: String) async throws {
        let request = GraphQLRequest<DeleteSquadMembershipResponse>(
            document: Self.deleteSquadMembershipDocument,
            variables: ["input": ["id": id]],
            responseType: DeleteSquadMembershipResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Department notifications & inbox

    static func listNotificationMessages(
        orgId: String,
        category: NotificationCategoryKind,
        limit: Int = 50
    ) async throws -> [NotificationMessageRecord] {
        let request = GraphQLRequest<NotificationMessagesByOrgResponse>(
            document: Self.notificationMessagesByOrgDocument,
            variables: [
                "orgId": orgId,
                "sortDirection": "DESC",
                "filter": ["category": ["eq": category.rawValue]],
                "limit": min(limit, 200)
            ],
            responseType: NotificationMessagesByOrgResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            return payload.notificationMessagesByOrg?.items.compactMap { $0 } ?? []
        case .failure(let error):
            throw error
        }
    }

    static func createNotificationMessage(
        orgId: String,
        title: String,
        body: String,
        category: NotificationCategoryKind,
        recipients: [String],
        metadata: [String: Any]?,
        createdBy: String
    ) async throws -> NotificationMessageRecord {
        var input: [String: Any] = [
            "orgId": orgId,
            "title": title,
            "body": body,
            "category": category.rawValue,
            "recipients": recipients,
            "createdBy": createdBy
        ]
        if let metadata, !metadata.isEmpty {
            input["metadata"] = try encodeJSONDictionary(metadata)
        }

        let request = GraphQLRequest<CreateNotificationMessageResponse>(
            document: Self.createNotificationMessageDocument,
            variables: ["input": input],
            responseType: CreateNotificationMessageResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createNotificationMessage else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return record
        case .failure(let error):
            throw error
        }
    }

    @discardableResult
    static func updateNotificationMessage(
        id: String,
        metadata: [String: Any]
    ) async throws -> NotificationMessageRecord {
        let request = GraphQLRequest<UpdateNotificationMessageResponse>(
            document: Self.updateNotificationMessageDocument,
            variables: [
                "input": [
                    "id": id,
                    "metadata": try encodeJSONDictionary(metadata)
                ]
            ],
            responseType: UpdateNotificationMessageResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateNotificationMessage else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return record
        case .failure(let error):
            throw error
        }
    }

    static func deleteNotificationMessage(id: String) async throws {
        let request = GraphQLRequest<DeleteNotificationMessageResponse>(
            document: Self.deleteNotificationMessageDocument,
            variables: [
                "input": [
                    "id": id
                ]
            ],
            responseType: DeleteNotificationMessageResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    static func sendNotification(
        orgId: String,
        recipients: [String],
        title: String,
        body: String,
        category: NotificationCategoryKind,
        metadata: [String: Any]? = nil
    ) async throws -> NotificationSendResultRecord? {
        var input: [String: Any] = [
            "orgId": orgId,
            "recipients": recipients,
            "title": title,
            "body": body,
            "category": category.rawValue
        ]
        if let metadata, !metadata.isEmpty {
            input["metadata"] = try encodeJSONDictionary(metadata)
        }

        let request = GraphQLRequest<SendNotificationResponse>(
            document: Self.sendNotificationDocument,
            variables: ["input": input],
            responseType: SendNotificationResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            return payload.sendNotification
        case .failure(let error):
            throw error
        }
    }

    static func fetchNotificationReceiptsForUser(
        userId: String,
        limit: Int = 200
    ) async throws -> [NotificationReceiptRecord] {
        let request = GraphQLRequest<NotificationReceiptsByUserResponse>(
            document: Self.notificationReceiptsByUserDocument,
            variables: [
                "userId": userId,
                "sortDirection": "DESC",
                "limit": min(limit, 500)
            ],
            responseType: NotificationReceiptsByUserResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            return payload.notificationReceiptsByUser?.items.compactMap { $0 } ?? []
        case .failure(let error):
            throw error
        }
    }

    @discardableResult
    static func markNotificationRead(
        notificationId: String,
        orgId: String,
        userId: String
    ) async throws -> NotificationReceiptRecord {
        if let existing = try await fetchReceipt(notificationId: notificationId, userId: userId) {
            if existing.isRead {
                return existing
            }
            return try await updateNotificationReceipt(id: existing.id)
        } else {
            return try await createNotificationReceipt(
                notificationId: notificationId,
                orgId: orgId,
                userId: userId
            )
        }
    }

    private static func fetchReceipt(notificationId: String, userId: String) async throws -> NotificationReceiptRecord? {
        let request = GraphQLRequest<NotificationReceiptsByUserResponse>(
            document: Self.notificationReceiptsByUserDocument,
            variables: [
                "userId": userId,
                "notificationId": ["eq": notificationId],
                "limit": 1
            ],
            responseType: NotificationReceiptsByUserResponse.self
        )

        let response = try await Amplify.API.query(request: request)
        switch response {
        case .success(let payload):
            return payload.notificationReceiptsByUser?.items.compactMap { $0 }.first
        case .failure(let error):
            throw error
        }
    }

    private static func createNotificationReceipt(
        notificationId: String,
        orgId: String,
        userId: String
    ) async throws -> NotificationReceiptRecord {
        let now = encode(date: Date())
        let request = GraphQLRequest<CreateNotificationReceiptResponse>(
            document: Self.createNotificationReceiptDocument,
            variables: [
                "input": [
                    "notificationId": notificationId,
                    "orgId": orgId,
                    "userId": userId,
                    "isRead": true,
                    "readAt": now
                ]
            ],
            responseType: CreateNotificationReceiptResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.createNotificationReceipt else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return record
        case .failure(let error):
            throw error
        }
    }

    private static func updateNotificationReceipt(id: String) async throws -> NotificationReceiptRecord {
        let request = GraphQLRequest<UpdateNotificationReceiptResponse>(
            document: Self.updateNotificationReceiptDocument,
            variables: [
                "input": [
                    "id": id,
                    "isRead": true,
                    "readAt": encode(date: Date())
                ]
            ],
            responseType: UpdateNotificationReceiptResponse.self
        )

        let response = try await Amplify.API.mutate(request: request)
        switch response {
        case .success(let payload):
            guard let record = payload.updateNotificationReceipt else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return record
        case .failure(let error):
            throw error
        }
    }

}

// MARK: - GraphQL Documents

extension ShiftlinkAPI {
    static func parse(dateString: String) -> Date? {
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        return fallbackISOFormatter.date(from: dateString)
    }

    static func encode(date: Date) -> String {
        isoFormatter.string(from: date)
    }
}

private extension ShiftlinkAPI {
    static let listRosterEntriesDocument = """
    query ListRosterEntries($filter: ModelRosterEntryFilterInput) {
      listRosterEntries(filter: $filter) {
        items {
          id
          orgId
          badgeNumber
          shift
          startsAt
          endsAt
        }
      }
    }
    """

    static let assignmentsByOfficerDocument = """
    query AssignmentsByOfficer($badgeNumber: String!, $sortDirection: ModelSortDirection, $limit: Int) {
      assignmentsByOfficer(badgeNumber: $badgeNumber, sortDirection: $sortDirection, limit: $limit) {
        items {
          id
          orgId
          badgeNumber
          title
          detail
          location
          notes
          updatedAt
        }
      }
    }
    """

    static let listSquadsDocument = """
    query ListSquads($filter: ModelSquadFilterInput, $limit: Int) {
      listSquads(filter: $filter, limit: $limit) {
        items {
          id
          orgId
          name
          bureau
          shift
          notes
          isActive
          createdAt
          updatedAt
          memberships {
            items {
              id
              squadId
              userId
              roleInSquad
              isPrimary
              isActive
            }
          }
        }
        nextToken
      }
    }
    """

    static let getSquadDocument = """
    query GetSquad($id: ID!) {
      getSquad(id: $id) {
        id
        orgId
        name
        bureau
        shift
        notes
        isActive
        createdAt
        updatedAt
        memberships {
          items {
            id
            squadId
            userId
            roleInSquad
            isPrimary
            isActive
          }
        }
      }
    }
    """

    static let createSquadDocument = """
    mutation CreateSquad($input: CreateSquadInput!) {
      createSquad(input: $input) {
        id
        orgId
        name
        bureau
        shift
        notes
        isActive
        createdAt
        updatedAt
      }
    }
    """

    static let updateSquadDocument = """
    mutation UpdateSquad($input: UpdateSquadInput!) {
      updateSquad(input: $input) {
        id
        orgId
        name
        bureau
        shift
        notes
        isActive
        createdAt
        updatedAt
      }
    }
    """

    static let createSquadMembershipDocument = """
    mutation CreateSquadMembership($input: CreateSquadMembershipInput!) {
      createSquadMembership(input: $input) {
        id
        squadId
        userId
        roleInSquad
        isPrimary
        isActive
      }
    }
    """

    static let updateSquadMembershipDocument = """
    mutation UpdateSquadMembership($input: UpdateSquadMembershipInput!) {
      updateSquadMembership(input: $input) {
        id
        squadId
        userId
        roleInSquad
        isPrimary
        isActive
      }
    }
    """

    static let deleteSquadMembershipDocument = """
    mutation DeleteSquadMembership($input: DeleteSquadMembershipInput!) {
      deleteSquadMembership(input: $input) {
        id
      }
    }
    """

    static let squadMembershipsByUserDocument = """
    query SquadMembershipsByUser($userId: String!, $filter: ModelSquadMembershipFilterInput, $limit: Int) {
      squadMembershipsByUser(userId: $userId, filter: $filter, limit: $limit) {
        items {
          id
          squadId
          userId
          roleInSquad
          isPrimary
          isActive
        }
        nextToken
      }
    }
    """

    static let squadMembershipsBySquadDocument = """
    query SquadMembershipsBySquad($squadId: ID!, $filter: ModelSquadMembershipFilterInput, $limit: Int) {
      squadMembershipsBySquad(squadId: $squadId, filter: $filter, limit: $limit) {
        items {
          id
          squadId
          userId
          roleInSquad
          isPrimary
          isActive
        }
        nextToken
      }
    }
    """

    static let assignmentsByOrgDocument = """
    query AssignmentsByOrg($orgId: String!, $sortDirection: ModelSortDirection, $limit: Int, $nextToken: String) {
      assignmentsByOrg(orgId: $orgId, sortDirection: $sortDirection, limit: $limit, nextToken: $nextToken) {
        items {
          id
          orgId
          badgeNumber
          title
          detail
          location
          notes
          updatedAt
        }
      }
    }
    """

    static let createRosterEntryDocument = """
    mutation CreateRosterEntry($input: CreateRosterEntryInput!, $condition: ModelRosterEntryConditionInput) {
      createRosterEntry(input: $input, condition: $condition) {
        id
        orgId
        badgeNumber
        shift
        startsAt
        endsAt
      }
    }
    """

    static let deleteRosterEntryDocument = """
    mutation DeleteRosterEntry($input: DeleteRosterEntryInput!, $condition: ModelRosterEntryConditionInput) {
      deleteRosterEntry(input: $input, condition: $condition) {
        id
      }
    }
    """

    static let listCalendarEventsDocument = """
    query ListCalendarEvents($filter: ModelCalendarEventFilterInput) {
      listCalendarEvents(filter: $filter) {
        items {
          id
          orgId
          ownerId
          title
          category
          color
          notes
          startsAt
          endsAt
          reminderMinutesBefore
          createdAt
          updatedAt
        }
      }
    }
    """

    static let createCalendarEventDocument = """
    mutation CreateCalendarEvent($input: CreateCalendarEventInput!, $condition: ModelCalendarEventConditionInput) {
      createCalendarEvent(input: $input, condition: $condition) {
        id
        orgId
        ownerId
        title
        category
        color
        notes
        startsAt
        endsAt
        reminderMinutesBefore
        createdAt
        updatedAt
      }
    }
    """

    static let updateCalendarEventDocument = """
    mutation UpdateCalendarEvent($input: UpdateCalendarEventInput!, $condition: ModelCalendarEventConditionInput) {
      updateCalendarEvent(input: $input, condition: $condition) {
        id
        orgId
        ownerId
        title
        category
        color
        notes
        startsAt
        endsAt
        reminderMinutesBefore
        createdAt
        updatedAt
      }
    }
    """

    static let deleteCalendarEventDocument = """
    mutation DeleteCalendarEvent($input: DeleteCalendarEventInput!, $condition: ModelCalendarEventConditionInput) {
      deleteCalendarEvent(input: $input, condition: $condition) {
        id
      }
    }
    """

    static let listVehiclesDocument = """
    query ListVehicles($filter: ModelVehicleFilterInput) {
      listVehicles(filter: $filter) {
        items {
          id
          orgId
          callsign
          make
          model
          plate
          inService
        }
      }
    }
    """

    static let overtimePostingsByOrgDocument = """
    query OvertimePostingsByOrg($orgId: String!, $sortDirection: ModelSortDirection, $filter: ModelOvertimePostingFilterInput, $limit: Int, $nextToken: String) {
      overtimePostingsByOrg(orgId: $orgId, sortDirection: $sortDirection, filter: $filter, limit: $limit, nextToken: $nextToken) {
        items {
          id
          orgId
          title
          location
          scenario
          startsAt
          endsAt
          slots
          policySnapshot
          state
          createdBy
          selectionPolicy
          needsEscalation
          createdAt
          updatedAt
        }
        nextToken
      }
    }
    """

    static let createOvertimePostingV2Document = """
    mutation CreateOvertimePosting($input: CreateOvertimePostingInput!) {
      createOvertimePosting(input: $input) {
        id
        orgId
        title
        location
        scenario
        startsAt
        endsAt
        slots
        policySnapshot
        state
        createdBy
        selectionPolicy
        needsEscalation
        createdAt
        updatedAt
      }
    }
    """

    static let updateOvertimePostingV2Document = """
    mutation UpdateOvertimePosting($input: UpdateOvertimePostingInput!) {
      updateOvertimePosting(input: $input) {
        id
        orgId
        title
        location
        scenario
        startsAt
        endsAt
        slots
        policySnapshot
        state
        createdBy
        selectionPolicy
        needsEscalation
        createdAt
        updatedAt
      }
    }
    """

    static let deleteOvertimePostingDocument = """
    mutation DeleteOvertimePosting($input: DeleteOvertimePostingInput!) {
      deleteOvertimePosting(input: $input) {
        id
        orgId
        title
        location
        scenario
        startsAt
        endsAt
        slots
        policySnapshot
        state
        createdBy
        createdAt
        updatedAt
      }
    }
    """

    static let managedOvertimePostingsByOrgDocument = """
    query OvertimePostingsByOrg($orgId: String!, $startsAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelOvertimePostingFilterInput, $limit: Int, $nextToken: String) {
      overtimePostingsByOrg(orgId: $orgId, startsAt: $startsAt, sortDirection: $sortDirection, filter: $filter, limit: $limit, nextToken: $nextToken) {
        items {
          id
          orgId
          title
          location
          scenario
          startsAt
          endsAt
          slots
          policy
          notes
          deadline
          state
          createdBy
          createdAt
          updatedAt
          signups(limit: 250) {
            items {
              id
              postingId
              orgId
              officerId
              status
              rank
              rankPriority
              badgeNumber
              tieBreakerKey
              submittedAt
              forcedBy
              forcedReason
              notes
              createdAt
              updatedAt
            }
          }
        }
        nextToken
      }
    }
    """

    static let getManagedOvertimePostingDocument = """
    query GetOvertimePosting($id: ID!) {
      getOvertimePosting(id: $id) {
        id
        orgId
        title
        location
        scenario
        startsAt
        endsAt
        slots
        policy
        notes
        deadline
        state
        createdBy
        createdAt
        updatedAt
        signups(limit: 500) {
          items {
            id
            postingId
            orgId
            officerId
            status
            rank
            rankPriority
            badgeNumber
            tieBreakerKey
            submittedAt
            forcedBy
            forcedReason
            notes
            createdAt
            updatedAt
          }
        }
      }
    }
    """

    static let createManagedOvertimePostingDocument = """
    mutation CreateOvertimePosting($input: CreateOvertimePostingInput!) {
      createOvertimePosting(input: $input) {
        id
        orgId
        title
        location
        scenario
        startsAt
        endsAt
        slots
        policy
        notes
        deadline
        state
        createdBy
        createdAt
        updatedAt
        signups {
          items {
            id
            postingId
            officerId
            status
          }
        }
      }
    }
    """

    static let updateManagedOvertimePostingDocument = """
    mutation UpdateOvertimePosting($input: UpdateOvertimePostingInput!) {
      updateOvertimePosting(input: $input) {
        id
        orgId
        title
        location
        scenario
        startsAt
        endsAt
        slots
        policy
        notes
        deadline
        state
        createdBy
        createdAt
        updatedAt
        signups {
          items {
            id
            postingId
            officerId
            status
          }
        }
      }
    }
    """

    static let deleteManagedOvertimePostingDocument = """
    mutation DeleteOvertimePosting($input: DeleteOvertimePostingInput!) {
      deleteOvertimePosting(input: $input) {
        id
      }
    }
    """

    static let createOvertimeSignupDocument = """
    mutation CreateOvertimeSignup($input: CreateOvertimeSignupInput!) {
      createOvertimeSignup(input: $input) {
        id
        postingId
        orgId
        officerId
        status
        rank
        rankPriority
        badgeNumber
        tieBreakerKey
        submittedAt
        forcedBy
        forcedReason
        notes
        createdAt
        updatedAt
      }
    }
    """

    static let updateOvertimeSignupDocument = """
    mutation UpdateOvertimeSignup($input: UpdateOvertimeSignupInput!) {
      updateOvertimeSignup(input: $input) {
        id
        postingId
        orgId
        officerId
        status
        rank
        rankPriority
        badgeNumber
        tieBreakerKey
        submittedAt
        forcedBy
        forcedReason
        notes
        createdAt
        updatedAt
      }
    }
"""
    static let createOvertimeAuditEventDocument = """
    mutation CreateOvertimeAuditEvent($input: CreateOvertimeAuditEventInput!) {
      createOvertimeAuditEvent(input: $input) {
        id
        postingId
        type
        details
        createdBy
        createdAt
      }
    }
    """

    static let notifyOvertimeEventDocument = """
    mutation NotifyOvertimeEvent($input: OvertimeNotificationInput!) {
      notifyOvertimeEvent(input: $input) {
        success
        delivered
        recipientCount
        message
      }
    }
    """

    static let sendNotificationDocument = """
    mutation SendNotification($input: OvertimeNotificationInput!) {
      sendNotification(input: $input) {
        success
        delivered
        recipientCount
        message
      }
    }
    """

    static let updateNotificationMessageDocument = """
    mutation UpdateNotificationMessage($input: UpdateNotificationMessageInput!) {
      updateNotificationMessage(input: $input) {
        id
        orgId
        title
        body
        category
        recipients
        metadata
        createdBy
        createdAt
        updatedAt
      }
    }
    """

    static let deleteNotificationMessageDocument = """
    mutation DeleteNotificationMessage($input: DeleteNotificationMessageInput!) {
      deleteNotificationMessage(input: $input) {
        id
        orgId
        title
        body
        category
        recipients
        metadata
        createdBy
        createdAt
        updatedAt
      }
    }
    """

    static let notificationMessagesByOrgDocument = """
    query NotificationMessagesByOrg($orgId: String!, $createdAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelNotificationMessageFilterInput, $limit: Int, $nextToken: String) {
      notificationMessagesByOrg(orgId: $orgId, createdAt: $createdAt, sortDirection: $sortDirection, filter: $filter, limit: $limit, nextToken: $nextToken) {
        items {
          id
          orgId
          title
          body
          category
          recipients
          metadata
          createdBy
          createdAt
          updatedAt
        }
        nextToken
      }
    }
    """

    static let createNotificationMessageDocument = """
    mutation CreateNotificationMessage($input: CreateNotificationMessageInput!) {
      createNotificationMessage(input: $input) {
        id
        orgId
        title
        body
        category
        recipients
        metadata
        createdBy
        createdAt
        updatedAt
      }
    }
    """

    static let notificationReceiptsByUserDocument = """
    query NotificationReceiptsByUser($userId: String!, $notificationId: ModelIDKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelNotificationReceiptFilterInput, $limit: Int, $nextToken: String) {
      notificationReceiptsByUser(userId: $userId, notificationId: $notificationId, sortDirection: $sortDirection, filter: $filter, limit: $limit, nextToken: $nextToken) {
        items {
          id
          notificationId
          userId
          orgId
          isRead
          readAt
        }
        nextToken
      }
    }
    """

    static let createNotificationReceiptDocument = """
    mutation CreateNotificationReceipt($input: CreateNotificationReceiptInput!) {
      createNotificationReceipt(input: $input) {
        id
        notificationId
        userId
        orgId
        isRead
        readAt
        createdAt
        updatedAt
      }
    }
    """

    static let updateNotificationReceiptDocument = """
    mutation UpdateNotificationReceipt($input: UpdateNotificationReceiptInput!) {
      updateNotificationReceipt(input: $input) {
        id
        notificationId
        userId
        orgId
        isRead
        readAt
        createdAt
        updatedAt
      }
    }
    """

    static let auditsByPostingDocument = """
    query AuditsByPosting($postingId: ID!, $sortDirection: ModelSortDirection, $limit: Int, $nextToken: String) {
      auditsByPosting(postingId: $postingId, sortDirection: $sortDirection, limit: $limit, nextToken: $nextToken) {
        items {
          id
          postingId
          type
          details
          createdBy
          createdAt
        }
        nextToken
      }
    }
    """

    /// Update the mutation name or shape to match your deployed resolver.
    static let sendDepartmentAlertDocument = """
    mutation SendDepartmentAlert($input: DepartmentAlertInput!) {
      sendDepartmentAlert(input: $input) {
        success
        message
      }
    }
    """

    static let notificationPreferencesByUserDocument = """
    query NotificationPreferencesByUser($userId: String!, $limit: Int) {
      notificationPreferencesByUser(userId: $userId, limit: $limit) {
        items {
          id
          userId
          generalBulletin
          taskAlert
          overtime
          squadMessages
          other
          contactPhone
          contactEmail
          backupEmail
        }
      }
    }
    """

    static let createNotificationPreferenceDocument = """
    mutation CreateNotificationPreference($input: CreateNotificationPreferenceInput!) {
      createNotificationPreference(input: $input) {
        id
        userId
        generalBulletin
        taskAlert
        overtime
        squadMessages
        other
        contactPhone
        contactEmail
        backupEmail
      }
    }
    """

    static let updateNotificationPreferenceDocument = """
    mutation UpdateNotificationPreference($input: UpdateNotificationPreferenceInput!) {
      updateNotificationPreference(input: $input) {
        id
        userId
        generalBulletin
        taskAlert
        overtime
        squadMessages
        other
        contactPhone
        contactEmail
        backupEmail
      }
    }
    """

    static let createOfficerAssignmentDocument = """
    mutation CreateOfficerAssignment($input: CreateOfficerAssignmentInput!, $condition: ModelOfficerAssignmentConditionInput) {
      createOfficerAssignment(input: $input, condition: $condition) {
        id
        orgId
        badgeNumber
        title
        detail
        location
        notes
        updatedAt
      }
    }
    """

    static let updateOfficerAssignmentDocument = """
    mutation UpdateOfficerAssignment($input: UpdateOfficerAssignmentInput!, $condition: ModelOfficerAssignmentConditionInput) {
      updateOfficerAssignment(input: $input, condition: $condition) {
        id
        orgId
        badgeNumber
        title
        detail
        location
        notes
        updatedAt
      }
    }
    """

    static let deleteOfficerAssignmentDocument = """
    mutation DeleteOfficerAssignment($input: DeleteOfficerAssignmentInput!, $condition: ModelOfficerAssignmentConditionInput) {
      deleteOfficerAssignment(input: $input, condition: $condition) {
        id
      }
    }
    """

    static func makeRosterEntryDTO(_ record: RosterEntryRecord) -> RosterEntryDTO? {
        guard
            let startDate = parse(dateString: record.startsAt),
            let endDate = parse(dateString: record.endsAt)
        else { return nil }

        return RosterEntryDTO(
            id: record.id,
            orgId: record.orgId,
            badgeNumber: record.badgeNumber,
            shift: record.shift,
            startsAt: startDate,
            endsAt: endDate
        )
    }

    static func makeOvertimePostingDTO(_ record: CalendarEventRecord) -> OvertimePostingDTO? {
        guard record.category == overtimeCategory else { return nil }
        guard
            let orgId = record.orgId,
            let starts = parse(dateString: record.startsAt),
            let ends = parse(dateString: record.endsAt)
        else { return nil }

        let postedAt = record.createdAt.flatMap { parse(dateString: $0) }
        let details = decodeJobDetails(from: record.notes)

        return OvertimePostingDTO(
            id: record.id,
            orgId: orgId,
            ownerId: record.ownerId,
            title: record.title,
            startsAt: starts,
            endsAt: ends,
            reminderMinutesBefore: record.reminderMinutesBefore,
            postedAt: postedAt,
            details: details
        )
    }

    static func makeCalendarEventDTO(_ record: CalendarEventRecord) -> CalendarEventDTO? {
        guard
            let starts = parse(dateString: record.startsAt),
            let ends = parse(dateString: record.endsAt)
        else { return nil }

        return CalendarEventDTO(
            id: record.id,
            ownerId: record.ownerId,
            orgId: record.orgId,
            title: record.title,
            category: record.category,
            colorHex: record.color,
            notes: record.notes,
            startsAt: starts,
            endsAt: ends,
            reminderMinutesBefore: record.reminderMinutesBefore
        )
    }

    static func makeManagedPostingDTO(from record: ManagedOvertimePostingRecord) -> ManagedOvertimePostingDTO? {
        guard
            let starts = parse(dateString: record.startsAt),
            let ends = parse(dateString: record.endsAt),
            let scenario = OvertimeScenarioKind(rawValue: record.scenario),
            let policy = OvertimePolicyKind(rawValue: record.policy),
            let state = OvertimePostingStateKind(rawValue: record.state)
        else {
            return nil
        }

        let deadlineDate = record.deadline.flatMap { parse(dateString: $0) }
        let created = record.createdAt.flatMap { parse(dateString: $0) }
        let updated = record.updatedAt.flatMap { parse(dateString: $0) }
        let signups = record.signups?.items.compactMap { $0 }.compactMap(makeOvertimeSignupDTO(from:)) ?? []

        return ManagedOvertimePostingDTO(
            id: record.id,
            orgId: record.orgId,
            title: record.title,
            location: record.location,
            scenario: scenario,
            startsAt: starts,
            endsAt: ends,
            slots: record.slots,
            policy: policy,
            notes: record.notes,
            deadline: deadlineDate,
            state: state,
            createdBy: record.createdBy,
            createdAt: created,
            updatedAt: updated,
            signups: signups
        )
    }

    static func makeOvertimeSignupDTO(from record: OvertimeSignupRecord) -> OvertimeSignupDTO? {
        guard let status = OvertimeSignupStatusKind(rawValue: record.status) else {
            return nil
        }
        return OvertimeSignupDTO(
            id: record.id,
            postingId: record.postingId,
            officerId: record.officerId,
            status: status,
            rank: record.rank,
            rankPriority: record.rankPriority,
            badgeNumber: record.badgeNumber,
            tieBreakerKey: record.tieBreakerKey,
            submittedAt: record.submittedAt.flatMap { parse(dateString: $0) },
            forcedBy: record.forcedBy,
            forcedReason: record.forcedReason,
            notes: record.notes,
            createdAt: record.createdAt.flatMap { parse(dateString: $0) },
            updatedAt: record.updatedAt.flatMap { parse(dateString: $0) }
        )
    }

    static func rankPriority(for rank: String?) -> Int {
        guard let rank = rank?.lowercased() else { return 999 }
        if rank.contains("capt") {
            return 1
        }
        if rank.contains("lt") {
            return 2
        }
        if rank.contains("serg") {
            return 3
        }
        if rank.contains("corp") {
            return 4
        }
        if rank.contains("detect") {
            return 5
        }
        return 10
    }

    static func makeOvertimeAuditDTO(_ record: OvertimeAuditEventRecord) -> OvertimeAuditEventDTO? {
        let details = record.details
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

        return OvertimeAuditEventDTO(
            id: record.id,
            postingId: record.postingId,
            type: record.type,
            details: details,
            createdBy: record.createdBy,
            createdAt: record.createdAt.flatMap(parse(dateString:))
        )
    }

    static func makeOfficerAssignmentDTO(_ record: OfficerAssignmentRecord) -> OfficerAssignmentDTO {
        let profile = decodeAssignmentProfile(from: record.notes)
            .withFallback(rank: record.detail, vehicle: record.location)
        return OfficerAssignmentDTO(
            id: record.id,
            orgId: record.orgId,
            badgeNumber: record.badgeNumber,
            title: record.title,
            detail: record.detail,
            location: record.location,
            notes: record.notes,
            updatedAt: record.updatedAt.flatMap(parse(dateString:)),
            profile: profile
        )
    }

    static func makeNotificationPreferenceDTO(from record: NotificationPreferenceRecord) -> NotificationPreferenceDTO {
        NotificationPreferenceDTO(
            id: record.id,
            userId: record.userId,
            generalBulletin: record.generalBulletin,
            taskAlert: record.taskAlert,
            overtime: record.overtime,
            squadMessages: record.squadMessages,
            other: record.other,
            contactPhone: record.contactPhone,
            contactEmail: record.contactEmail,
            backupEmail: record.backupEmail
        )
    }

    static func encodeAssignmentProfile(_ profile: OfficerAssignmentProfile) -> String? {
        let sanitized = profile.sanitized()
        guard sanitized.containsData else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(sanitized) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeAssignmentProfile(from notes: String?) -> OfficerAssignmentProfile {
        guard let notes, !notes.isEmpty, let data = notes.data(using: .utf8) else {
            return OfficerAssignmentProfile()
        }
        if let decoded = try? JSONDecoder().decode(OfficerAssignmentProfile.self, from: data) {
            return decoded
        }
        return OfficerAssignmentProfile(
            fullName: notes,
            rank: nil,
            vehicle: nil,
            specialAssignment: nil,
            departmentPhone: nil,
            departmentExtension: nil,
            departmentEmail: nil,
            squad: nil,
            mfaVerified: nil,
            userId: nil
        )
    }

    static func encode(jobDetails: OvertimeJobDetails) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(jobDetails) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeJobDetails(from notes: String?) -> OvertimeJobDetails? {
        guard let notes, !notes.isEmpty else { return nil }
        if let data = notes.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(OvertimeJobDetails.self, from: data) {
            return decoded
        }
        return OvertimeJobDetails(
            description: notes,
            location: "Unspecified",
            rate: "Standard",
            contact: nil,
            postedBy: nil,
            postedByName: nil
        )
    }

    private static func squadInputPayload(orgId: String?, input: SquadDraftInput) -> [String: Any] {
        var payload: [String: Any] = [
            "name": input.name,
            "bureau": input.bureau,
            "isActive": input.isActive
        ]
        if let orgId {
            payload["orgId"] = orgId
        }
        if let shift = input.shift?.trimmedOrNil {
            payload["shift"] = shift
        }
        if let notes = input.notes?.trimmedOrNil {
            payload["notes"] = notes
        }
        return payload
    }

    private static func squadMembershipPayload(_ input: SquadMembershipInput) -> [String: Any] {
        var payload: [String: Any] = [
            "squadId": input.squadId,
            "userId": input.userId,
            "roleInSquad": input.role.rawValue,
            "isPrimary": input.isPrimary,
            "isActive": input.isActive
        ]
        return payload
    }

    private static func makeSquadDTO(from record: SquadRecord, includeMemberships: Bool = true) -> SquadDTO {
        let memberships: [SquadMembershipDTO]
        if includeMemberships {
            memberships = record.memberships?.items?.compactMap { $0 }.compactMap(makeMembershipDTO) ?? []
        } else {
            memberships = []
        }
        let supervisors = memberships.filter { $0.role == .supervisor }
        let officers = memberships.filter { $0.role == .officer }
        return SquadDTO(
            id: record.id,
            orgId: record.orgId,
            name: record.name,
            bureau: record.bureau,
            shift: record.shift,
            notes: record.notes,
            isActive: record.isActive ?? true,
            supervisorMemberships: supervisors,
            officerMemberships: officers
        )
    }

    private static func makeMembershipDTO(from record: SquadMembershipRecord) -> SquadMembershipDTO? {
        guard let role = SquadRoleKind(rawValue: record.roleInSquad.uppercased()) else { return nil }
        return SquadMembershipDTO(
            id: record.id,
            squadId: record.squadId,
            userId: record.userId,
            role: role,
            isPrimary: record.isPrimary ?? true,
            isActive: record.isActive ?? true
        )
    }

    private static func membershipFilter(includeInactive: Bool, role: SquadRoleKind?) -> [String: Any]? {
        var filter: [String: Any] = [:]
        if !includeInactive {
            filter["isActive"] = ["eq": true]
        }
        if let role {
            filter["roleInSquad"] = ["eq": role.rawValue]
        }
        return filter.isEmpty ? nil : filter
    }

    static func encodeJSONPayload<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ShiftlinkAPIError.malformedResponse
        }
        return string
    }

    static func encodeJSONDictionary(_ dictionary: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ShiftlinkAPIError.malformedResponse
        }
        return string
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

}

private extension OfficerAssignmentProfile {
    func sanitized() -> OfficerAssignmentProfile {
        OfficerAssignmentProfile(
            fullName: fullName?.trimmedOrNil,
            rank: rank?.trimmedOrNil,
            vehicle: vehicle?.trimmedOrNil,
            specialAssignment: specialAssignment?.trimmedOrNil,
            departmentPhone: departmentPhone?.trimmedOrNil,
            departmentExtension: departmentExtension?.trimmedOrNil,
            departmentEmail: departmentEmail?.trimmedOrNil,
            squad: squad?.trimmedOrNil,
            mfaVerified: mfaVerified,
            userId: userId?.trimmedOrNil
        )
    }

    var containsData: Bool {
        let strings = [fullName, rank, vehicle, specialAssignment, departmentPhone, departmentExtension, departmentEmail, squad, userId]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return !strings.isEmpty || mfaVerified != nil
    }

    func withFallback(rank: String?, vehicle: String?) -> OfficerAssignmentProfile {
        var copy = self
        if (copy.rank?.isEmpty ?? true), let rank, !rank.isEmpty {
            copy.rank = rank
        }
        if (copy.vehicle?.isEmpty ?? true), let vehicle, !vehicle.isEmpty {
            copy.vehicle = vehicle
        }
        return copy
    }
}

private extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
