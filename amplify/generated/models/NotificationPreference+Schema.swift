// swiftlint:disable all
import Amplify
import Foundation

extension NotificationPreference {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case userId
    case generalBulletin
    case taskAlert
    case overtime
    case squadMessages
    case other
    case contactPhone
    case contactEmail
    case backupEmail
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let notificationPreference = NotificationPreference.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "userId", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.read])
    ]
    
    model.listPluralName = "NotificationPreferences"
    model.syncPluralName = "NotificationPreferences"
    
    model.attributes(
      .index(fields: ["userId"], name: "notificationPreferencesByUser"),
      .primaryKey(fields: [notificationPreference.id])
    )
    
    model.fields(
      .field(notificationPreference.id, is: .required, ofType: .string),
      .field(notificationPreference.userId, is: .required, ofType: .string),
      .field(notificationPreference.generalBulletin, is: .required, ofType: .bool),
      .field(notificationPreference.taskAlert, is: .required, ofType: .bool),
      .field(notificationPreference.overtime, is: .required, ofType: .bool),
      .field(notificationPreference.squadMessages, is: .required, ofType: .bool),
      .field(notificationPreference.other, is: .required, ofType: .bool),
      .field(notificationPreference.contactPhone, is: .optional, ofType: .string),
      .field(notificationPreference.contactEmail, is: .optional, ofType: .string),
      .field(notificationPreference.backupEmail, is: .optional, ofType: .string),
      .field(notificationPreference.createdAt, is: .optional, ofType: .dateTime),
      .field(notificationPreference.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension NotificationPreference: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}