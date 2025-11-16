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

// MARK: - Overtime Rotation (v2) Models

enum OvertimeScenarioKind: String, Codable, CaseIterable {
    case patrolShortShift = "PATROL_SHORT_SHIFT"
    case sergeantShortShift = "SERGEANT_SHORT_SHIFT"
    case specialEvent = "SPECIAL_EVENT"
    case seniorityBased = "SENIORITY_BASED"
    case other = "OTHER_OVERTIME"
}

enum OvertimePostingStateKind: String, Codable, CaseIterable {
    case open = "OPEN"
    case filled = "FILLED"
    case closed = "CLOSED"
}

enum OvertimeInviteStatusKind: String, Codable, CaseIterable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case declined = "DECLINED"
    case ordered = "ORDERED"
    case expired = "EXPIRED"
}

enum OvertimeSelectionPolicyKind: String, Codable, CaseIterable {
    case rotation = "ROTATION"
    case seniority = "SENIORITY"
    case firstCome = "FIRST_COME"
}

struct RotationOvertimePostingDTO: Identifiable {
    let id: String
    let orgId: String
    let title: String
    let location: String?
    let scenario: OvertimeScenarioKind
    let startsAt: Date
    let endsAt: Date
    let slots: Int
    let state: OvertimePostingStateKind
    let createdBy: String
    let createdAt: Date?
    let updatedAt: Date?
    let policySnapshot: RotationPolicySnapshot
    let needsEscalation: Bool
    let selectionPolicy: OvertimeSelectionPolicyKind
}

struct NewRotationOvertimePostingInput {
    var orgId: String
    var title: String
    var location: String?
    var scenario: OvertimeScenarioKind
    var startsAt: Date
    var endsAt: Date
    var slots: Int
    var policySnapshot: RotationPolicySnapshot
    var needsEscalation: Bool
    var selectionPolicy: OvertimeSelectionPolicyKind
}

struct OvertimeInviteDTO: Identifiable {
    let id: String
    let postingId: String
    let officerId: String
    let bucket: OvertimeRankBucket
    let sequence: Int
    let reason: RotationInviteStep.Reason
    let status: OvertimeInviteStatusKind
    let scheduledAt: Date?
    let respondedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
}

struct OvertimeAuditEventDTO: Identifiable {
    let id: String
    let postingId: String
    let type: String
    let details: [String: Any]?
    let createdBy: String?
    let createdAt: Date?
}

struct NotificationDispatchRequest {
    var orgId: String
    var recipients: [String]
    var title: String
    var body: String
    var category: String
    var postingId: String?
    var metadata: [String: Any]?
}

typealias OvertimeNotificationRequest = NotificationDispatchRequest

struct NotificationPreferenceDTO: Equatable {
    var id: String?
    var userId: String
    var generalBulletin: Bool
    var taskAlert: Bool
    var overtime: Bool
    var squadMessages: Bool
    var other: Bool
    var contactPhone: String?
    var contactEmail: String?
    var backupEmail: String?

    init(
        id: String? = nil,
        userId: String,
        generalBulletin: Bool = true,
        taskAlert: Bool = true,
        overtime: Bool = true,
        squadMessages: Bool = true,
        other: Bool = true,
        contactPhone: String? = nil,
        contactEmail: String? = nil,
        backupEmail: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.generalBulletin = generalBulletin
        self.taskAlert = taskAlert
        self.overtime = overtime
        self.squadMessages = squadMessages
        self.other = other
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.backupEmail = backupEmail
    }

    static func placeholder(userId: String) -> NotificationPreferenceDTO {
        NotificationPreferenceDTO(id: nil, userId: userId)
    }

    var contactMetadata: [String: String] {
        var details: [String: String] = [:]
        if let phone = sanitized(contactPhone) {
            details["phone"] = phone
        }
        if let email = sanitized(contactEmail) {
            details["email"] = email
        }
        if let backup = sanitized(backupEmail) {
            details["backupEmail"] = backup
        }
        return details
    }

    private func sanitized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func graphQLInput(using identifier: String) -> [String: Any] {
        var payload: [String: Any] = [
            "id": identifier,
            "userId": userId,
            "generalBulletin": generalBulletin,
            "taskAlert": taskAlert,
            "overtime": overtime,
            "squadMessages": squadMessages,
            "other": other
        ]
        if let phone = sanitized(contactPhone) {
            payload["contactPhone"] = phone
        }
        if let email = sanitized(contactEmail) {
            payload["contactEmail"] = email
        }
        if let backup = sanitized(backupEmail) {
            payload["backupEmail"] = backup
        }
        return payload
    }

    func createInput() -> [String: Any] {
        graphQLInput(using: id ?? UUID().uuidString)
    }

    func updateInput() throws -> [String: Any] {
        guard let identifier = id else { throw ShiftlinkAPIError.missingIdentifiers }
        return graphQLInput(using: identifier)
    }
}

struct CalendarEventDTO: Identifiable {
    let id: String
    let ownerId: String
    let orgId: String
    let title: String
    let category: String
    let colorHex: String
    let notes: String?
    let startsAt: Date
    let endsAt: Date
}

struct NewCalendarEventInput {
    var title: String
    var startsAt: Date
    var endsAt: Date
    var category: String
    var colorHex: String
    var notes: String?
}

// MARK: - API Service

enum ShiftlinkAPIError: LocalizedError {
    case missingIdentifiers
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingIdentifiers:
            return "Missing the identifiers required to fetch data from Amplify."
        case .malformedResponse:
            return "Received an unexpected payload from the Amplify API."
        }
    }
}

struct ShiftlinkAPI {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let overtimeCategory = "OVERTIME"
    static let unassignedOwnerToken = "__UNASSIGNED__"

    // MARK: Roster Entries

    static func listRosterEntries(orgId: String, badgeNumber: String?) async throws -> [RosterEntryDTO] {
        var clauses: [[String: Any]] = [
            ["orgId": ["eq": orgId]]
        ]
        if let badgeNumber, !badgeNumber.isEmpty {
            clauses.append(["badgeNumber": ["eq": badgeNumber]])
        }

        let filterPayload: [String: Any]
        if clauses.count == 1, let single = clauses.first {
            filterPayload = single
        } else {
            filterPayload = ["and": clauses]
        }

        let request = GraphQLRequest<ListRosterEntriesResponse>(
            document: Self.listRosterEntriesDocument,
            variables: ["filter": filterPayload],
            responseType: ListRosterEntriesResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let items = payload.listRosterEntries?.items ?? []
            return items
                .compactMap { $0 }
                .compactMap(Self.makeRosterEntryDTO)
        case .failure(let error):
            throw error
        }
    }

    static func fetchCurrentAssignment(orgId: String, badgeNumber: String) async throws -> OfficerAssignmentDTO? {
        let variables: [String: Any] = [
            "badgeNumber": badgeNumber,
            "sortDirection": "DESC",
            "limit": 1
        ]

        let request = GraphQLRequest<AssignmentsByOfficerResponse>(
            document: Self.assignmentsByOfficerDocument,
            variables: variables,
            responseType: AssignmentsByOfficerResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let assignment = payload.assignmentsByOfficer?.items
                .compactMap { $0 }
                .first { $0.orgId.caseInsensitiveCompare(orgId) == .orderedSame }
            return assignment.flatMap(Self.makeOfficerAssignmentDTO)
        case .failure(let error):
            throw error
        }
    }

    static func listAssignments(orgId: String, limit: Int = 200) async throws -> [OfficerAssignmentDTO] {
        let request = GraphQLRequest<AssignmentsByOrgResponse>(
            document: Self.assignmentsByOrgDocument,
            variables: [
                "orgId": orgId,
                "sortDirection": "DESC",
                "limit": limit
            ],
            responseType: AssignmentsByOrgResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let items = payload.assignmentsByOrg?.items ?? []
            return items.compactMap { $0 }.map(Self.makeOfficerAssignmentDTO)
        case .failure(let error):
            throw error
        }
    }

    static func upsertAssignment(for badgeNumber: String, orgId: String, assignmentTitle: String, rank: String?, vehicle: String?, profile: OfficerAssignmentProfile) async throws -> OfficerAssignmentDTO {
        let existing = try await fetchCurrentAssignment(orgId: orgId, badgeNumber: badgeNumber)
        let payload: [String: Any?] = [
            "badgeNumber": badgeNumber,
            "orgId": orgId,
            "title": assignmentTitle,
            "detail": rank?.trimmedOrNil,
            "location": vehicle?.trimmedOrNil,
            "notes": encodeAssignmentProfile(profile)
        ]
        let input = payload.compactMapValues { $0 }

        if let assignmentId = existing?.id {
            let request = GraphQLRequest<UpdateAssignmentResponse>(
                document: Self.updateOfficerAssignmentDocument,
                variables: ["input": input.merging(["id": assignmentId]) { $1 }],
                responseType: UpdateAssignmentResponse.self
            )
            let result = try await Amplify.API.mutate(request: request)
            switch result {
            case .success(let response):
                guard let record = response.updateOfficerAssignment else {
                    throw ShiftlinkAPIError.malformedResponse
                }
                return makeOfficerAssignmentDTO(record)
            case .failure(let error):
                throw error
            }
        } else {
            let request = GraphQLRequest<CreateAssignmentResponse>(
                document: Self.createOfficerAssignmentDocument,
                variables: ["input": input],
                responseType: CreateAssignmentResponse.self
            )
            let result = try await Amplify.API.mutate(request: request)
            switch result {
            case .success(let response):
                return makeOfficerAssignmentDTO(response.createOfficerAssignment)
            case .failure(let error):
                throw error
            }
        }
    }

    static func deleteAssignment(id: String) async throws {
        let request = GraphQLRequest<DeleteAssignmentResponse>(
            document: Self.deleteOfficerAssignmentDocument,
            variables: ["input": ["id": id]],
            responseType: DeleteAssignmentResponse.self
        )
        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    static func createRosterEntry(_ input: NewRosterEntryInput) async throws -> RosterEntryDTO {
        var inputPayload: [String: Any] = [
            "orgId": input.orgId,
            "badgeNumber": input.badgeNumber,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt)
        ]
        if let shift = input.shift, !shift.isEmpty {
            inputPayload["shift"] = shift
        }

        let request = GraphQLRequest<CreateRosterEntryResponse>(
            document: Self.createRosterEntryDocument,
            variables: ["input": inputPayload],
            responseType: CreateRosterEntryResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let dto = Self.makeRosterEntryDTO(payload.createRosterEntry) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func deleteRosterEntry(id: String) async throws {
        let request = GraphQLRequest<DeleteRosterEntryResponse>(
            document: Self.deleteRosterEntryDocument,
            variables: ["input": ["id": id]],
            responseType: DeleteRosterEntryResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    // MARK: Overtime Postings

    static func listOvertimePostings(orgId: String) async throws -> [OvertimePostingDTO] {
        let variables: [String: Any] = [
            "filter": [
                "and": [
                    ["orgId": ["eq": orgId]],
                    ["category": ["eq": overtimeCategory]]
                ]
            ]
        ]

        let request = GraphQLRequest<ListCalendarEventsResponse>(
            document: Self.listCalendarEventsDocument,
            variables: variables,
            responseType: ListCalendarEventsResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            return payload.listCalendarEvents.items.compactMap(Self.makeOvertimePostingDTO)
        case .failure(let error):
            throw error
        }
    }

    static func listCalendarEvents(ownerIds: [String]) async throws -> [CalendarEventDTO] {
        let ownerFilters = ownerIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ["ownerId": ["eq": $0]] }

        guard !ownerFilters.isEmpty else { return [] }

        let filter: [String: Any]
        if ownerFilters.count == 1, let first = ownerFilters.first {
            filter = first
        } else {
            filter = ["or": ownerFilters]
        }

        let variables: [String: Any] = ["filter": filter]

        let request = GraphQLRequest<ListCalendarEventsResponse>(
            document: Self.listCalendarEventsDocument,
            variables: variables,
            responseType: ListCalendarEventsResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            return payload.listCalendarEvents.items.compactMap(Self.makeCalendarEventDTO)
        case .failure(let error):
            throw error
        }
    }

    static func createCalendarEvent(ownerId: String, orgId: String?, input: NewCalendarEventInput) async throws -> CalendarEventDTO {
        var payload: [String: Any] = [
            "ownerId": ownerId,
            "orgId": (orgId?.isEmpty == false ? orgId! : "PERSONAL"),
            "title": input.title,
            "category": input.category,
            "color": input.colorHex,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt)
        ]
        if let notes = input.notes, !notes.isEmpty { payload["notes"] = notes }

        let request = GraphQLRequest<CreateCalendarEventResponse>(
            document: Self.createCalendarEventDocument,
            variables: ["input": payload],
            responseType: CreateCalendarEventResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let dto = Self.makeCalendarEventDTO(payload.createCalendarEvent) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func updateCalendarEvent(id: String, ownerId: String, input: NewCalendarEventInput) async throws -> CalendarEventDTO {
        var payload: [String: Any] = [
            "id": id,
            "ownerId": ownerId,
            "title": input.title,
            "category": input.category,
            "color": input.colorHex,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt)
        ]
        payload["notes"] = input.notes

        let request = GraphQLRequest<UpdateCalendarEventResponse>(
            document: Self.updateCalendarEventDocument,
            variables: ["input": payload],
            responseType: UpdateCalendarEventResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let dto = Self.makeCalendarEventDTO(payload.updateCalendarEvent) else {
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

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    static func createOvertimePosting(
        orgId: String,
        posterId: String,
        posterName: String?,
        input: NewOvertimePostingInput
    ) async throws -> OvertimePostingDTO {
        let jobDetails = OvertimeJobDetails(
            description: input.description,
            location: input.location,
            rate: input.rate,
            contact: input.contact,
            postedBy: posterId,
            postedByName: posterName
        )

        guard let notesString = encode(jobDetails: jobDetails) else {
            throw ShiftlinkAPIError.malformedResponse
        }

        var payload: [String: Any] = [
            "orgId": orgId,
            "ownerId": unassignedOwnerToken,
            "title": input.title,
            "category": overtimeCategory,
            "color": input.priorityColorHex,
            "notes": notesString,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt)
        ]

        if let reminder = input.reminderMinutesBefore {
            payload["reminderMinutesBefore"] = reminder
        }

        let request = GraphQLRequest<CreateCalendarEventResponse>(
            document: Self.createCalendarEventDocument,
            variables: ["input": payload],
            responseType: CreateCalendarEventResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let dto = Self.makeOvertimePostingDTO(payload.createCalendarEvent) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func claimOvertimePosting(id: String, badgeNumber: String) async throws -> OvertimePostingDTO {
        return try await updateOvertimePostingOwner(id: id, ownerId: badgeNumber)
    }

    static func releaseOvertimePosting(id: String) async throws -> OvertimePostingDTO {
        return try await updateOvertimePostingOwner(id: id, ownerId: unassignedOwnerToken)
    }

    private static func updateOvertimePostingOwner(id: String, ownerId: String) async throws -> OvertimePostingDTO {
        let request = GraphQLRequest<UpdateCalendarEventResponse>(
            document: Self.updateCalendarEventDocument,
            variables: ["input": ["id": id, "ownerId": ownerId]],
            responseType: UpdateCalendarEventResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let dto = Self.makeOvertimePostingDTO(payload.updateCalendarEvent) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    // MARK: Rotation Overtime (v2)

    static func listRotationOvertimePostings(
        orgId: String,
        state: OvertimePostingStateKind? = nil,
        limit: Int = 50
    ) async throws -> [RotationOvertimePostingDTO] {
        var variables: [String: Any] = [
            "orgId": orgId,
            "sortDirection": "ASC",
            "limit": limit
        ]
        if let state {
            variables["filter"] = [
                "state": ["eq": state.rawValue]
            ]
        }

        let request = GraphQLRequest<OvertimePostingsByOrgResponse>(
            document: Self.overtimePostingsByOrgDocument,
            variables: variables,
            responseType: OvertimePostingsByOrgResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let records = payload.overtimePostingsByOrg?.items ?? []
            return records.compactMap(Self.makeRotationPostingDTO)
        case .failure(let error):
            throw error
        }
    }

    static func createRotationOvertimePosting(
        createdBy: String,
        input: NewRotationOvertimePostingInput
    ) async throws -> RotationOvertimePostingDTO {
        let snapshotJSON = try encodeJSONPayload(input.policySnapshot)
        var payload: [String: Any] = [
            "orgId": input.orgId,
            "title": input.title,
            "scenario": input.scenario.rawValue,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt),
            "slots": input.slots,
            "policySnapshot": snapshotJSON,
            "state": OvertimePostingStateKind.open.rawValue,
            "createdBy": createdBy,
            "needsEscalation": input.needsEscalation,
            "selectionPolicy": input.selectionPolicy.rawValue
        ]
        if let location = input.location, !location.isEmpty {
            payload["location"] = location
        }

        let request = GraphQLRequest<CreateOvertimePostingV2Response>(
            document: Self.createOvertimePostingV2Document,
            variables: ["input": payload],
            responseType: CreateOvertimePostingV2Response.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            return try makeRotationPostingDTO(from: payload.createOvertimePosting)
        case .failure(let error):
            throw error
        }
    }

    static func updateOvertimePostingState(
        postingId: String,
        newState: OvertimePostingStateKind
    ) async throws -> RotationOvertimePostingDTO {
        let request = GraphQLRequest<UpdateOvertimePostingV2Response>(
            document: Self.updateOvertimePostingV2Document,
            variables: ["input": ["id": postingId, "state": newState.rawValue]],
            responseType: UpdateOvertimePostingV2Response.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimePosting else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return try makeRotationPostingDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    static func updateRotationOvertimePosting(
        postingId: String,
        input: NewRotationOvertimePostingInput
    ) async throws -> RotationOvertimePostingDTO {
        let snapshotJSON = try encodeJSONPayload(input.policySnapshot)
        var payload: [String: Any] = [
            "id": postingId,
            "title": input.title,
            "scenario": input.scenario.rawValue,
            "startsAt": encode(date: input.startsAt),
            "endsAt": encode(date: input.endsAt),
            "slots": input.slots,
            "policySnapshot": snapshotJSON,
            "needsEscalation": input.needsEscalation,
            "selectionPolicy": input.selectionPolicy.rawValue
        ]
        if let location = input.location, !location.isEmpty {
            payload["location"] = location
        } else {
            payload["location"] = nil
        }

        let request = GraphQLRequest<UpdateOvertimePostingV2Response>(
            document: Self.updateOvertimePostingV2Document,
            variables: ["input": payload],
            responseType: UpdateOvertimePostingV2Response.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimePosting else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return try makeRotationPostingDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    static func deleteRotationOvertimePosting(postingId: String) async throws {
        let request = GraphQLRequest<DeleteOvertimePostingResponse>(
            document: Self.deleteOvertimePostingDocument,
            variables: ["input": ["id": postingId]],
            responseType: DeleteOvertimePostingResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    static func updatePostingEscalationStatus(postingId: String, needsEscalation: Bool) async throws -> RotationOvertimePostingDTO {
        let request = GraphQLRequest<UpdateOvertimePostingV2Response>(
            document: Self.updateOvertimePostingV2Document,
            variables: ["input": ["id": postingId, "needsEscalation": needsEscalation]],
            responseType: UpdateOvertimePostingV2Response.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimePosting else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return try makeRotationPostingDTO(from: record)
        case .failure(let error):
            throw error
        }
    }

    static func createOvertimeInvites(postingId: String, plan: [RotationInviteStep]) async throws -> [OvertimeInviteDTO] {
        guard !plan.isEmpty else { return [] }
        var created: [OvertimeInviteDTO] = []
        for step in plan.sorted(by: { $0.sequence < $1.sequence }) {
            let payload: [String: Any] = [
                "postingId": postingId,
                "officerId": step.officerId,
                "bucket": step.bucket.rawValue,
                "sequence": step.sequence,
                "reason": step.reason.rawValue,
                "status": OvertimeInviteStatusKind.pending.rawValue
            ]

            let request = GraphQLRequest<CreateOvertimeInviteResponse>(
                document: Self.createOvertimeInviteDocument,
                variables: ["input": payload],
                responseType: CreateOvertimeInviteResponse.self
            )

            let result = try await Amplify.API.mutate(request: request)
            switch result {
            case .success(let payload):
                guard let dto = makeOvertimeInviteDTO(payload.createOvertimeInvite) else {
                    throw ShiftlinkAPIError.malformedResponse
                }
                created.append(dto)
            case .failure(let error):
                throw error
            }
        }
        return created
    }

    static func listOvertimeInvites(postingId: String) async throws -> [OvertimeInviteDTO] {
        let request = GraphQLRequest<ListOvertimeInvitesResponse>(
            document: Self.invitesByPostingDocument,
            variables: [
                "postingId": postingId,
                "sortDirection": "ASC",
                "limit": 500
            ],
            responseType: ListOvertimeInvitesResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let items = payload.invitesByPosting?.items ?? []
            return items.compactMap(Self.makeOvertimeInviteDTO)
        case .failure(let error):
            throw error
        }
    }

    static func deleteOvertimeInvites(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            let request = GraphQLRequest<DeleteOvertimeInviteResponse>(
                document: Self.deleteOvertimeInviteDocument,
                variables: ["input": ["id": id]],
                responseType: DeleteOvertimeInviteResponse.self
            )
            let result = try await Amplify.API.mutate(request: request)
            if case .failure(let error) = result {
                throw error
            }
        }
    }

    static func createForceAssignmentInvite(
        postingId: String,
        officerId: String,
        bucket: OvertimeRankBucket,
        sequence: Int
    ) async throws -> OvertimeInviteDTO {
        var payload: [String: Any] = [
            "postingId": postingId,
            "officerId": officerId,
            "bucket": bucket.rawValue,
            "sequence": sequence,
            "reason": RotationInviteStep.Reason.forcedAssignment.rawValue,
            "status": OvertimeInviteStatusKind.ordered.rawValue
        ]
        payload["scheduledAt"] = encode(date: Date())

        let request = GraphQLRequest<CreateOvertimeInviteResponse>(
            document: Self.createOvertimeInviteDocument,
            variables: ["input": payload],
            responseType: CreateOvertimeInviteResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let response):
            guard let dto = makeOvertimeInviteDTO(response.createOvertimeInvite) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func scheduleRotationInvites(
        posting: RotationOvertimePostingDTO,
        plan: [RotationInviteStep],
        invites: [OvertimeInviteDTO]
    ) async throws -> [OvertimeInviteDTO] {
        guard !plan.isEmpty else { return [] }
        let baseDate = posting.createdAt ?? posting.startsAt
        let invitesBySequence = Dictionary(uniqueKeysWithValues: invites.map { ($0.sequence, $0) })
        var scheduledInvites: [OvertimeInviteDTO] = []

        for step in plan {
            guard let invite = invitesBySequence[step.sequence] else { continue }
            let scheduledAt = baseDate.addingTimeInterval(Double(step.delayMinutes) * 60)
            let updatedInvite = try await updateOvertimeInviteSchedule(
                inviteId: invite.id,
                scheduledAt: scheduledAt,
                status: nil
            )
            scheduledInvites.append(updatedInvite)
        }

        return scheduledInvites
    }

    static func updateOvertimeInviteStatus(
        inviteId: String,
        status: OvertimeInviteStatusKind,
        respondedAt: Date? = nil
    ) async throws -> OvertimeInviteDTO {
        var payload: [String: Any] = [
            "id": inviteId,
            "status": status.rawValue
        ]
        if let respondedAt {
            payload["respondedAt"] = encode(date: respondedAt)
        }

        let request = GraphQLRequest<UpdateOvertimeInviteResponse>(
            document: Self.updateOvertimeInviteDocument,
            variables: ["input": payload],
            responseType: UpdateOvertimeInviteResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimeInvite else {
                throw ShiftlinkAPIError.malformedResponse
            }
            guard let dto = makeOvertimeInviteDTO(record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    private static func updateOvertimeInviteSchedule(
        inviteId: String,
        scheduledAt: Date,
        status: OvertimeInviteStatusKind?
    ) async throws -> OvertimeInviteDTO {
        var payload: [String: Any] = [
            "id": inviteId,
            "scheduledAt": encode(date: scheduledAt)
        ]
        if let status {
            payload["status"] = status.rawValue
        }
        let request = GraphQLRequest<UpdateOvertimeInviteResponse>(
            document: Self.updateOvertimeInviteDocument,
            variables: ["input": payload],
            responseType: UpdateOvertimeInviteResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let record = payload.updateOvertimeInvite else {
                throw ShiftlinkAPIError.malformedResponse
            }
            guard let dto = makeOvertimeInviteDTO(record) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func logOvertimeAuditEvent(
        postingId: String,
        type: String,
        details: [String: Any]? = nil,
        createdBy: String?
    ) async throws -> OvertimeAuditEventDTO {
        var payload: [String: Any] = [
            "postingId": postingId,
            "type": type
        ]
        if let createdBy, !createdBy.isEmpty {
            payload["createdBy"] = createdBy
        }
        if let details, !details.isEmpty {
            payload["details"] = try encodeJSONDictionary(details)
        }

        let request = GraphQLRequest<CreateOvertimeAuditEventResponse>(
            document: Self.createOvertimeAuditEventDocument,
            variables: ["input": payload],
            responseType: CreateOvertimeAuditEventResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            guard let dto = makeOvertimeAuditDTO(payload.createOvertimeAuditEvent) else {
                throw ShiftlinkAPIError.malformedResponse
            }
            return dto
        case .failure(let error):
            throw error
        }
    }

    static func listOvertimeAuditEvents(postingId: String) async throws -> [OvertimeAuditEventDTO] {
        let request = GraphQLRequest<ListOvertimeAuditsResponse>(
            document: Self.auditsByPostingDocument,
            variables: [
                "postingId": postingId,
                "sortDirection": "ASC",
                "limit": 200
            ],
            responseType: ListOvertimeAuditsResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let items = payload.auditsByPosting?.items ?? []
            return items.compactMap(Self.makeOvertimeAuditDTO)
        case .failure(let error):
            throw error
        }
    }

    @discardableResult
    static func notifyOvertimeEvent(request: NotificationDispatchRequest) async -> Bool {
        let extra = request.postingId.map { ["postingId": $0] } ?? [:]
        return await dispatchNotification(
            document: Self.notifyOvertimeEventDocument,
            responseType: NotifyOvertimeEventResponse.self,
            keyPath: \.notifyOvertimeEvent,
            request: request,
            additionalFields: extra
        )
    }

    @discardableResult
    static func sendNotification(request: NotificationDispatchRequest) async -> Bool {
        return await dispatchNotification(
            document: Self.sendNotificationDocument,
            responseType: SendNotificationResponse.self,
            keyPath: \.sendNotification,
            request: request
        )
    }

    private static func dispatchNotification<Response: Decodable>(
        document: String,
        responseType: Response.Type,
        keyPath: KeyPath<Response, NotificationSendResultRecord?>,
        request: NotificationDispatchRequest,
        additionalFields: [String: Any] = [:]
    ) async -> Bool {
        var input: [String: Any] = [
            "orgId": request.orgId,
            "recipients": request.recipients,
            "title": request.title,
            "body": request.body,
            "category": request.category
        ]

        if let metadata = request.metadata, !metadata.isEmpty {
            do {
                input["metadata"] = try encodeJSONDictionary(metadata)
            } catch {
                print("[DutyWire] Failed to encode notification metadata: \(error)")
            }
        }

        for (key, value) in additionalFields {
            input[key] = value
        }

        let gqlRequest = GraphQLRequest<Response>(
            document: document,
            variables: ["input": input],
            responseType: responseType
        )

        do {
            let result = try await Amplify.API.mutate(request: gqlRequest)
            switch result {
            case .success(let payload):
                guard let summary = payload[keyPath: keyPath] else {
                    return false
                }
                return summary.success ?? false
            case .failure(let error):
                print("[DutyWire] Notification dispatch failed: \(error)")
                return false
            }
        } catch {
            print("[DutyWire] Notification dispatch error: \(error)")
            return false
        }
    }

    // MARK: Vehicles

    static func listVehicles(orgId: String) async throws -> [VehicleDTO] {
        let request = GraphQLRequest<ListVehiclesResponse>(
            document: Self.listVehiclesDocument,
            variables: ["filter": ["orgId": ["eq": orgId]]],
            responseType: ListVehiclesResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            return payload.listVehicles.items.map {
                VehicleDTO(
                    id: $0.id,
                    orgId: $0.orgId,
                    callsign: $0.callsign,
                    make: $0.make,
                    model: $0.model,
                    plate: $0.plate,
                    inService: $0.inService
                )
            }
        case .failure(let error):
            throw error
        }
    }

    // MARK: Department Alerts

    static func sendDepartmentAlert(_ input: DepartmentAlertPayload) async throws -> MutationResponsePayload {
        let request = GraphQLRequest<SendAlertResponse>(
            document: Self.sendDepartmentAlertDocument,
            variables: ["input": [
                "orgId": input.orgId,
                "siteKey": input.siteKey ?? "",
                "title": input.title,
                "message": input.message,
                "priority": input.priority.uppercased()
            ]],
            responseType: SendAlertResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            return payload.sendDepartmentAlert
        case .failure(let error):
            throw error
        }
    }

    // MARK: Notification Preferences

    static func fetchNotificationPreferences(userId: String) async throws -> NotificationPreferenceDTO? {
        let request = GraphQLRequest<NotificationPreferencesByUserResponse>(
            document: notificationPreferencesByUserDocument,
            variables: ["userId": userId, "limit": 1],
            responseType: NotificationPreferencesByUserResponse.self
        )

        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let payload):
            let record = payload.notificationPreferencesByUser?.items.compactMap { $0 }.first
            return record.map(makeNotificationPreferenceDTO)
        case .failure(let error):
            throw error
        }
    }

    static func upsertNotificationPreferences(_ prefs: NotificationPreferenceDTO) async throws -> NotificationPreferenceDTO {
        if prefs.id == nil {
            return try await createNotificationPreference(prefs)
        } else {
            return try await updateNotificationPreference(prefs)
        }
    }

    private static func createNotificationPreference(_ prefs: NotificationPreferenceDTO) async throws -> NotificationPreferenceDTO {
        let request = GraphQLRequest<CreateNotificationPreferenceResponse>(
            document: createNotificationPreferenceDocument,
            variables: ["input": prefs.createInput()],
            responseType: CreateNotificationPreferenceResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            if let record = payload.createNotificationPreference {
                return makeNotificationPreferenceDTO(from: record)
            }
            throw ShiftlinkAPIError.malformedResponse
        case .failure(let error):
            throw error
        }
    }

    private static func updateNotificationPreference(_ prefs: NotificationPreferenceDTO) async throws -> NotificationPreferenceDTO {
        let request = GraphQLRequest<UpdateNotificationPreferenceResponse>(
            document: updateNotificationPreferenceDocument,
            variables: ["input": try prefs.updateInput()],
            responseType: UpdateNotificationPreferenceResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            if let record = payload.updateNotificationPreference {
                return makeNotificationPreferenceDTO(from: record)
            }
            throw ShiftlinkAPIError.malformedResponse
        case .failure(let error):
            throw error
        }
    }

    private static func makeNotificationPreferenceDTO(from record: NotificationPreferenceRecord) -> NotificationPreferenceDTO {
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

}

// MARK: - GraphQL Payloads

private struct ListRosterEntriesResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [RosterEntryRecord?]
    }
    let listRosterEntries: ItemsContainer?
}

private struct AssignmentsByOfficerResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [OfficerAssignmentRecord?]
    }
    let assignmentsByOfficer: ItemsContainer?
}

private struct AssignmentsByOrgResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [OfficerAssignmentRecord?]
    }
    let assignmentsByOrg: ItemsContainer?
}

private struct CreateRosterEntryResponse: Decodable {
    let createRosterEntry: RosterEntryRecord
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

private struct CalendarEventRecord: Decodable {
    let id: String
    let orgId: String
    let ownerId: String
    let title: String
    let category: String
    let color: String
    let notes: String?
    let startsAt: String
    let endsAt: String
    let reminderMinutesBefore: Int?
    let createdAt: String?
    let updatedAt: String?
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

private struct CreateAssignmentResponse: Decodable {
    let createOfficerAssignment: OfficerAssignmentRecord
}

private struct UpdateAssignmentResponse: Decodable {
    let updateOfficerAssignment: OfficerAssignmentRecord?
}

private struct DeleteAssignmentResponse: Decodable {
    let deleteOfficerAssignment: OfficerAssignmentRecord?
}

private struct ListCalendarEventsResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [CalendarEventRecord]
    }
    let listCalendarEvents: ItemsContainer
}

private struct CreateCalendarEventResponse: Decodable {
    let createCalendarEvent: CalendarEventRecord
}

private struct UpdateCalendarEventResponse: Decodable {
    let updateCalendarEvent: CalendarEventRecord
}

private struct DeleteCalendarEventResponse: Decodable {
    let deleteCalendarEvent: CalendarEventRecord?
}

private struct ListVehiclesResponse: Decodable {
    struct ItemsContainer: Decodable {
        struct Item: Decodable {
            let id: String
            let orgId: String
            let callsign: String
            let make: String?
            let model: String?
            let plate: String?
            let inService: Bool?
        }
        let items: [Item]
    }
    let listVehicles: ItemsContainer
}

private struct SendAlertResponse: Decodable {
    let sendDepartmentAlert: MutationResponsePayload
}

private struct NotificationPreferenceConnection: Decodable {
    let items: [NotificationPreferenceRecord?]
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

private struct OvertimePostingsByOrgResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [OvertimePostingRecord]
        let nextToken: String?
    }
    let overtimePostingsByOrg: ItemsContainer?
}

private struct CreateOvertimePostingV2Response: Decodable {
    let createOvertimePosting: OvertimePostingRecord
}

private struct UpdateOvertimePostingV2Response: Decodable {
    let updateOvertimePosting: OvertimePostingRecord?
}

private struct DeleteOvertimePostingResponse: Decodable {
    let deleteOvertimePosting: OvertimePostingRecord?
}

private struct OvertimePostingRecord: Decodable {
    let id: String
    let orgId: String
    let title: String
    let location: String?
    let scenario: String
    let startsAt: String
    let endsAt: String
    let slots: Int
    let policySnapshot: String
    let state: String
    let createdBy: String
    let createdAt: String?
    let updatedAt: String?
    let needsEscalation: Bool?
    let selectionPolicy: String?
}

private struct ListOvertimeInvitesResponse: Decodable {
    struct ItemsContainer: Decodable {
        let items: [OvertimeInviteRecord]
        let nextToken: String?
    }
    let invitesByPosting: ItemsContainer?
}

private struct CreateOvertimeInviteResponse: Decodable {
    let createOvertimeInvite: OvertimeInviteRecord
}

private struct UpdateOvertimeInviteResponse: Decodable {
    let updateOvertimeInvite: OvertimeInviteRecord?
}

private struct DeleteOvertimeInviteResponse: Decodable {
    let deleteOvertimeInvite: OvertimeInviteRecord?
}

private struct OvertimeInviteRecord: Decodable {
    let id: String
    let postingId: String
    let officerId: String
    let bucket: String
    let sequence: Int
    let reason: String
    let status: String
    let scheduledAt: String?
    let respondedAt: String?
    let createdAt: String?
    let updatedAt: String?
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

private struct NotificationSendResultRecord: Decodable {
    let success: Bool?
    let delivered: Int?
    let recipientCount: Int?
    let message: String?
}

// MARK: - GraphQL Documents

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

    static let createOvertimeInviteDocument = """
    mutation CreateOvertimeInvite($input: CreateOvertimeInviteInput!) {
      createOvertimeInvite(input: $input) {
        id
        postingId
        officerId
        bucket
        sequence
        reason
        status
        scheduledAt
        respondedAt
        createdAt
        updatedAt
      }
    }
    """

    static let updateOvertimeInviteDocument = """
    mutation UpdateOvertimeInvite($input: UpdateOvertimeInviteInput!) {
      updateOvertimeInvite(input: $input) {
        id
        postingId
        officerId
        bucket
        sequence
        reason
        status
        scheduledAt
        respondedAt
        createdAt
        updatedAt
      }
    }
    """

    static let deleteOvertimeInviteDocument = """
    mutation DeleteOvertimeInvite($input: DeleteOvertimeInviteInput!) {
      deleteOvertimeInvite(input: $input) {
        id
        postingId
        officerId
        bucket
        sequence
        reason
        status
        scheduledAt
        respondedAt
        createdAt
        updatedAt
      }
    }
    """

    static let invitesByPostingDocument = """
    query InvitesByPosting($postingId: ID!, $sortDirection: ModelSortDirection, $limit: Int, $nextToken: String) {
      invitesByPosting(postingId: $postingId, sortDirection: $sortDirection, limit: $limit, nextToken: $nextToken) {
        items {
          id
          postingId
          officerId
          bucket
          sequence
          reason
          status
          scheduledAt
          respondedAt
          createdAt
          updatedAt
        }
        nextToken
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

    static func parse(dateString: String) -> Date? {
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        return fallbackISOFormatter.date(from: dateString)
    }

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
            let starts = parse(dateString: record.startsAt),
            let ends = parse(dateString: record.endsAt)
        else { return nil }

        let postedAt = record.createdAt.flatMap { parse(dateString: $0) }
        let details = decodeJobDetails(from: record.notes)

        return OvertimePostingDTO(
            id: record.id,
            orgId: record.orgId,
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
            endsAt: ends
        )
    }

    static func makeRotationPostingDTO(from record: OvertimePostingRecord) throws -> RotationOvertimePostingDTO {
        guard
            let starts = parse(dateString: record.startsAt),
            let ends = parse(dateString: record.endsAt)
        else {
            throw ShiftlinkAPIError.malformedResponse
        }

        guard
            let scenario = OvertimeScenarioKind(rawValue: record.scenario),
            let state = OvertimePostingStateKind(rawValue: record.state)
        else {
            throw ShiftlinkAPIError.malformedResponse
        }

        guard let snapshot = decodePolicySnapshot(from: record.policySnapshot) else {
            throw ShiftlinkAPIError.malformedResponse
        }

        let selectionPolicy = OvertimeSelectionPolicyKind(rawValue: record.selectionPolicy ?? "ROTATION") ?? .rotation

        return RotationOvertimePostingDTO(
            id: record.id,
            orgId: record.orgId,
            title: record.title,
            location: record.location,
            scenario: scenario,
            startsAt: starts,
            endsAt: ends,
            slots: record.slots,
            state: state,
            createdBy: record.createdBy,
            createdAt: record.createdAt.flatMap(parse(dateString:)),
            updatedAt: record.updatedAt.flatMap(parse(dateString:)),
            policySnapshot: snapshot,
            needsEscalation: record.needsEscalation ?? false,
            selectionPolicy: selectionPolicy
        )
    }

    static func makeRotationPostingDTO(_ record: OvertimePostingRecord) -> RotationOvertimePostingDTO? {
        return try? makeRotationPostingDTO(from: record)
    }

    static func makeOvertimeInviteDTO(_ record: OvertimeInviteRecord) -> OvertimeInviteDTO? {
        guard
            let bucket = OvertimeRankBucket(rawValue: record.bucket.lowercased()),
            let status = OvertimeInviteStatusKind(rawValue: record.status)
        else {
            return nil
        }
        let reason = RotationInviteStep.Reason(rawValue: record.reason) ?? .rotation
        return OvertimeInviteDTO(
            id: record.id,
            postingId: record.postingId,
            officerId: record.officerId,
            bucket: bucket,
            sequence: record.sequence,
            reason: reason,
            status: status,
            scheduledAt: record.scheduledAt.flatMap(parse(dateString:)),
            respondedAt: record.respondedAt.flatMap(parse(dateString:)),
            createdAt: record.createdAt.flatMap(parse(dateString:)),
            updatedAt: record.updatedAt.flatMap(parse(dateString:))
        )
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
    return OfficerAssignmentProfile(fullName: notes, rank: nil, vehicle: nil, specialAssignment: nil, departmentPhone: nil, departmentExtension: nil, departmentEmail: nil, squad: nil, mfaVerified: nil, userId: nil)
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

static func encode(date: Date) -> String {
    isoFormatter.string(from: date)
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

static func decodePolicySnapshot(from json: String) -> RotationPolicySnapshot? {
    guard let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(RotationPolicySnapshot.self, from: data)
}

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
