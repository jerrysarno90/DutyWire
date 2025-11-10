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

    /// Update the mutation name or shape to match your deployed resolver.
    static let sendDepartmentAlertDocument = """
    mutation SendDepartmentAlert($input: DepartmentAlertInput!) {
      sendDepartmentAlert(input: $input) {
        success
        message
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
    return OfficerAssignmentProfile(fullName: notes)
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
            squad: squad?.trimmedOrNil
        )
    }

    var containsData: Bool {
        return [fullName, rank, vehicle, specialAssignment, departmentPhone, departmentExtension, departmentEmail, squad]
            .compactMap { $0 }
            .contains(where: { !$0.isEmpty })
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
