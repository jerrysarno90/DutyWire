import Foundation
import Amplify

enum NotificationPlatformKind: String {
    case ios = "IOS"
    case android = "ANDROID"
}

struct NotificationEndpointRecord: Decodable, Identifiable {
    let id: String
    let orgId: String
    let userId: String
    let deviceToken: String
    let platform: String
    let deviceName: String?
    var enabled: Bool?
    let lastUsedAt: String?
    let platformEndpointArn: String?
}

private struct NotificationEndpointConnection: Decodable {
    let items: [NotificationEndpointRecord?]
    let nextToken: String?
}

private struct EndpointsByUserResponse: Decodable {
    let notificationEndpointsByUser: NotificationEndpointConnection?
}

private struct EndpointsByOrgResponse: Decodable {
    let notificationEndpointsByOrg: NotificationEndpointConnection?
}

private struct ListNotificationEndpointsResponse: Decodable {
    let listNotificationEndpoints: NotificationEndpointConnection?
}

private struct CreateNotificationEndpointResponse: Decodable {
    let createNotificationEndpoint: NotificationEndpointRecord?
}

private struct UpdateNotificationEndpointResponse: Decodable {
    let updateNotificationEndpoint: NotificationEndpointRecord?
}

enum NotificationEndpointService {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let endpointsByUserQuery = """
    query NotificationEndpointsByUser($userId: String!, $limit: Int, $nextToken: String) {
      notificationEndpointsByUser(userId: $userId, sortDirection: DESC, limit: $limit, nextToken: $nextToken) {
        items {
          id
          orgId
          userId
          deviceToken
          platform
          deviceName
          enabled
          lastUsedAt
          platformEndpointArn
        }
        nextToken
      }
    }
    """

    private static let legacyListEndpointsQuery = """
    query ListNotificationEndpoints($filter: ModelNotificationEndpointFilterInput, $limit: Int, $nextToken: String) {
      listNotificationEndpoints(filter: $filter, limit: $limit, nextToken: $nextToken) {
        items {
          id
          orgId
          userId
          deviceToken
          platform
          deviceName
          enabled
          lastUsedAt
          platformEndpointArn
        }
        nextToken
      }
    }
    """

    private static let endpointsByOrgQuery = """
    query NotificationEndpointsByOrg($orgId: String!, $limit: Int, $nextToken: String) {
      notificationEndpointsByOrg(orgId: $orgId, limit: $limit, nextToken: $nextToken, sortDirection: DESC) {
        items {
          id
          orgId
          userId
          deviceToken
          platform
          deviceName
          enabled
          lastUsedAt
          platformEndpointArn
        }
        nextToken
      }
    }
    """

    private static let createEndpointMutation = """
    mutation CreateNotificationEndpoint($input: CreateNotificationEndpointInput!) {
      createNotificationEndpoint(input: $input) {
        id
        orgId
        userId
        deviceToken
        platform
        deviceName
        enabled
        lastUsedAt
        platformEndpointArn
      }
    }
    """

    private static let updateEndpointMutation = """
    mutation UpdateNotificationEndpoint($input: UpdateNotificationEndpointInput!) {
      updateNotificationEndpoint(input: $input) {
        id
        orgId
        userId
        deviceToken
        platform
        deviceName
        enabled
        lastUsedAt
        platformEndpointArn
      }
    }
    """

    static func upsertEndpoint(
        userId: String,
        orgId: String,
        token: String,
        platform: NotificationPlatformKind,
        deviceName: String?
    ) async throws -> NotificationEndpointRecord {
        if let existing = try await findEndpoint(userId: userId, orgId: orgId, token: token) {
            return try await updateEndpoint(
                id: existing.id,
                orgId: orgId,
                deviceToken: token,
                platform: platform,
                deviceName: deviceName,
                enabled: true
            )
        } else {
            return try await createEndpoint(
                userId: userId,
                orgId: orgId,
                deviceToken: token,
                platform: platform,
                deviceName: deviceName
            )
        }
    }

    static func setEnabled(endpointId: String, enabled: Bool) async throws {
        _ = try await updateEndpoint(
            id: endpointId,
            orgId: nil,
            deviceToken: nil,
            platform: nil,
            deviceName: nil,
            enabled: enabled
        )
    }

    private static func createEndpoint(
        userId: String,
        orgId: String,
        deviceToken: String,
        platform: NotificationPlatformKind,
        deviceName: String?
    ) async throws -> NotificationEndpointRecord {
        var input: [String: Any] = [
            "id": UUID().uuidString,
            "userId": userId,
            "orgId": orgId,
            "deviceToken": deviceToken,
            "platform": platform.rawValue,
            "enabled": true,
            "lastUsedAt": isoFormatter.string(from: Date())
        ]
        if let deviceName {
            input["deviceName"] = deviceName
        }

        let request = GraphQLRequest<CreateNotificationEndpointResponse>(
            document: createEndpointMutation,
            variables: ["input": input],
            responseType: CreateNotificationEndpointResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            if let record = payload.createNotificationEndpoint {
                return record
            }
            throw NotificationServiceError.malformedResponse
        case .failure(let error):
            throw error
        }
    }

    private static func updateEndpoint(
        id: String,
        orgId: String?,
        deviceToken: String?,
        platform: NotificationPlatformKind?,
        deviceName: String?,
        enabled: Bool?
    ) async throws -> NotificationEndpointRecord {
        var input: [String: Any] = [
            "id": id,
            "lastUsedAt": isoFormatter.string(from: Date())
        ]
        if let orgId {
            input["orgId"] = orgId
        }
        if let deviceToken {
            input["deviceToken"] = deviceToken
        }
        if let platform {
            input["platform"] = platform.rawValue
        }
        if let deviceName {
            input["deviceName"] = deviceName
        }
        if let enabled {
            input["enabled"] = enabled
        }

        let request = GraphQLRequest<UpdateNotificationEndpointResponse>(
            document: updateEndpointMutation,
            variables: ["input": input],
            responseType: UpdateNotificationEndpointResponse.self
        )

        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let payload):
            if let record = payload.updateNotificationEndpoint {
                return record
            }
            throw NotificationServiceError.malformedResponse
        case .failure(let error):
            throw error
        }
    }

    private static func findEndpoint(userId: String, orgId: String, token: String) async throws -> NotificationEndpointRecord? {
        let endpoints = try await listEndpointsByUser(userId: userId, limit: 25)
        return endpoints.first { $0.orgId == orgId && $0.deviceToken == token }
    }

    static func listEndpointsForUser(userId: String) async throws -> [NotificationEndpointRecord] {
        try await listEndpointsByUser(userId: userId, limit: 200)
    }

    static func listEndpointsForOrg(orgId: String, limit: Int = 500) async throws -> [NotificationEndpointRecord] {
        var collected: [NotificationEndpointRecord] = []
        var nextToken: String? = nil

        repeat {
            var variables: [String: Any] = [
                "orgId": orgId,
                "limit": min(limit, 200)
            ]
            if let token = nextToken {
                variables["nextToken"] = token
            }

            let request = GraphQLRequest<EndpointsByOrgResponse>(
                document: endpointsByOrgQuery,
                variables: variables,
                responseType: EndpointsByOrgResponse.self
            )

            let result = try await Amplify.API.query(request: request)
            switch result {
            case .success(let payload):
                let items = payload.notificationEndpointsByOrg?.items.compactMap { $0 } ?? []
                collected.append(contentsOf: items)
                nextToken = payload.notificationEndpointsByOrg?.nextToken
            case .failure(let error):
                throw error
            }
        } while nextToken != nil && collected.count < limit

        return collected
    }

    static func listEndpoints(for recipients: [String], orgId: String?) async throws -> [NotificationEndpointRecord] {
        var deduped = Set(recipients)
        let includeAll = deduped.contains("*")
        deduped.remove("*")
        var results: [NotificationEndpointRecord] = []

        if includeAll, let orgId {
            let orgEndpoints = try await listEndpointsForOrg(orgId: orgId, limit: 1000)
            results.append(contentsOf: orgEndpoints)
        }

        guard !deduped.isEmpty else {
            return results
        }

        for recipient in deduped {
            let endpoints = try await listEndpointsByUser(userId: recipient, limit: 200)
            results.append(contentsOf: endpoints)
        }

        // Deduplicate by endpoint id
        var unique: [String: NotificationEndpointRecord] = [:]
        for record in results {
            unique[record.id] = record
        }
        return Array(unique.values)
    }

    private static func listEndpointsByUser(userId: String, limit: Int) async throws -> [NotificationEndpointRecord] {
        var collected: [NotificationEndpointRecord] = []
        var nextToken: String? = nil

        repeat {
            var variables: [String: Any] = [
                "userId": userId,
                "limit": min(limit, 100)
            ]
            if let token = nextToken {
                variables["nextToken"] = token
            }

            do {
                let request = GraphQLRequest<EndpointsByUserResponse>(
                    document: endpointsByUserQuery,
                    variables: variables,
                    responseType: EndpointsByUserResponse.self
                )

                let result = try await Amplify.API.query(request: request)
                switch result {
                case .success(let payload):
                    let items = payload.notificationEndpointsByUser?.items.compactMap { $0 } ?? []
                    collected.append(contentsOf: items)
                    nextToken = payload.notificationEndpointsByUser?.nextToken
                case .failure(let error):
                    if shouldFallbackToLegacyUserQuery(error: error) {
                        return try await legacyListEndpointsByUser(userId: userId, limit: limit)
                    }
                    throw error
                }
            } catch {
                if shouldFallbackToLegacyUserQuery(error: error) {
                    return try await legacyListEndpointsByUser(userId: userId, limit: limit)
                }
                throw error
            }
        } while nextToken != nil && collected.count < limit

        return collected
    }

    private static func legacyListEndpointsByUser(userId: String, limit: Int) async throws -> [NotificationEndpointRecord] {
        var collected: [NotificationEndpointRecord] = []
        var nextToken: String? = nil

        repeat {
            var filter: [String: Any] = [
                "userId": ["eq": userId]
            ]
            var variables: [String: Any] = [
                "filter": filter,
                "limit": min(limit, 100)
            ]
            if let token = nextToken {
                variables["nextToken"] = token
            }

            let request = GraphQLRequest<ListNotificationEndpointsResponse>(
                document: legacyListEndpointsQuery,
                variables: variables,
                responseType: ListNotificationEndpointsResponse.self
            )

            let result = try await Amplify.API.query(request: request)
            switch result {
            case .success(let payload):
                let items = payload.listNotificationEndpoints?.items.compactMap { $0 } ?? []
                collected.append(contentsOf: items)
                nextToken = payload.listNotificationEndpoints?.nextToken
            case .failure(let error):
                throw error
            }
        } while nextToken != nil && collected.count < limit

        return collected
    }

    private static func shouldFallbackToLegacyUserQuery(error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        if description.contains("notificationendpointsbyuser") || description.contains("endpointsbyuser") {
            return true
        }
        return false
    }
}

enum NotificationServiceError: LocalizedError {
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "Received an unexpected response from the notification endpoint service."
        }
    }
}
