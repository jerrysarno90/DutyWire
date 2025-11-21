// swiftlint:disable all
import Amplify
import Foundation

extension NotificationReceipt {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case notificationId
    case userId
    case orgId
    case isRead
    case readAt
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let notificationReceipt = NotificationReceipt.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "userId", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.read])
    ]
    
    model.listPluralName = "NotificationReceipts"
    model.syncPluralName = "NotificationReceipts"
    
    model.attributes(
      .index(fields: ["notificationId", "userId"], name: "notificationReceiptsByNotification"),
      .index(fields: ["userId", "notificationId"], name: "notificationReceiptsByUser"),
      .primaryKey(fields: [notificationReceipt.id])
    )
    
    model.fields(
      .field(notificationReceipt.id, is: .required, ofType: .string),
      .field(notificationReceipt.notificationId, is: .required, ofType: .string),
      .field(notificationReceipt.userId, is: .required, ofType: .string),
      .field(notificationReceipt.orgId, is: .required, ofType: .string),
      .field(notificationReceipt.isRead, is: .required, ofType: .bool),
      .field(notificationReceipt.readAt, is: .optional, ofType: .dateTime),
      .field(notificationReceipt.createdAt, is: .optional, ofType: .dateTime),
      .field(notificationReceipt.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension NotificationReceipt: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}