// swiftlint:disable all
import Amplify
import Foundation

extension NotificationEndpoint {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case userId
    case deviceToken
    case platform
    case deviceName
    case enabled
    case platformEndpointArn
    case lastUsedAt
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let notificationEndpoint = NotificationEndpoint.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "userId", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.read])
    ]
    
    model.listPluralName = "NotificationEndpoints"
    model.syncPluralName = "NotificationEndpoints"
    
    model.attributes(
      .index(fields: ["orgId", "updatedAt"], name: "notificationEndpointsByOrg"),
      .index(fields: ["userId", "updatedAt"], name: "endpointsByUser"),
      .primaryKey(fields: [notificationEndpoint.id])
    )
    
    model.fields(
      .field(notificationEndpoint.id, is: .required, ofType: .string),
      .field(notificationEndpoint.orgId, is: .optional, ofType: .string),
      .field(notificationEndpoint.userId, is: .required, ofType: .string),
      .field(notificationEndpoint.deviceToken, is: .required, ofType: .string),
      .field(notificationEndpoint.platform, is: .required, ofType: .enum(type: NotificationPlatform.self)),
      .field(notificationEndpoint.deviceName, is: .optional, ofType: .string),
      .field(notificationEndpoint.enabled, is: .required, ofType: .bool),
      .field(notificationEndpoint.platformEndpointArn, is: .optional, ofType: .string),
      .field(notificationEndpoint.lastUsedAt, is: .optional, ofType: .dateTime),
      .field(notificationEndpoint.createdAt, is: .optional, ofType: .dateTime),
      .field(notificationEndpoint.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension NotificationEndpoint: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}