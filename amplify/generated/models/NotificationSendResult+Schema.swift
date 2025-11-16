// swiftlint:disable all
import Amplify
import Foundation

extension NotificationSendResult {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case success
    case delivered
    case recipientCount
    case message
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let notificationSendResult = NotificationSendResult.keys
    
    model.listPluralName = "NotificationSendResults"
    model.syncPluralName = "NotificationSendResults"
    
    model.fields(
      .field(notificationSendResult.success, is: .required, ofType: .bool),
      .field(notificationSendResult.delivered, is: .optional, ofType: .int),
      .field(notificationSendResult.recipientCount, is: .optional, ofType: .int),
      .field(notificationSendResult.message, is: .optional, ofType: .string)
    )
    }
}