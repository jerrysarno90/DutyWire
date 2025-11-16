// swiftlint:disable all
import Amplify
import Foundation

extension NotificationMessage {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case title
    case body
    case category
    case recipients
    case metadata
    case createdBy
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let notificationMessage = NotificationMessage.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete, .read])
    ]
    
    model.listPluralName = "NotificationMessages"
    model.syncPluralName = "NotificationMessages"
    
    model.attributes(
      .index(fields: ["orgId", "createdAt"], name: "messagesByOrg"),
      .primaryKey(fields: [notificationMessage.id])
    )
    
    model.fields(
      .field(notificationMessage.id, is: .required, ofType: .string),
      .field(notificationMessage.orgId, is: .required, ofType: .string),
      .field(notificationMessage.title, is: .required, ofType: .string),
      .field(notificationMessage.body, is: .required, ofType: .string),
      .field(notificationMessage.category, is: .required, ofType: .enum(type: NotificationCategory.self)),
      .field(notificationMessage.recipients, is: .required, ofType: .embeddedCollection(of: String.self)),
      .field(notificationMessage.metadata, is: .optional, ofType: .string),
      .field(notificationMessage.createdBy, is: .required, ofType: .string),
      .field(notificationMessage.createdAt, is: .optional, ofType: .dateTime),
      .field(notificationMessage.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension NotificationMessage: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}