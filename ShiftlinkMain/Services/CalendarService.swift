import Foundation

/// Thin wrapper around the Amplify-generated API helpers for calendar CRUD operations.
enum CalendarService {
    static func fetchEvents(forOwnerIds ownerIds: [String]) async throws -> [CalendarEventDTO] {
        guard !ownerIds.isEmpty else { return [] }
        return try await ShiftlinkAPI.listCalendarEvents(ownerIds: ownerIds)
    }

    static func createEvent(ownerId: String, orgId: String?, input: NewCalendarEventInput) async throws -> CalendarEventDTO {
        try await ShiftlinkAPI.createCalendarEvent(ownerId: ownerId, orgId: orgId, input: input)
    }

    static func updateEvent(id: String, ownerId: String, input: NewCalendarEventInput) async throws -> CalendarEventDTO {
        try await ShiftlinkAPI.updateCalendarEvent(id: id, ownerId: ownerId, input: input)
    }

    static func deleteEvent(id: String) async throws {
        try await ShiftlinkAPI.deleteCalendarEvent(id: id)
    }
}
