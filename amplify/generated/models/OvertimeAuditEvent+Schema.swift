// swiftlint:disable all
import Amplify
import Foundation

extension OvertimeAuditEvent {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case postingId
    case type
    case details
    case createdBy
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let overtimeAuditEvent = OvertimeAuditEvent.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete, .read])
    ]
    
    model.listPluralName = "OvertimeAuditEvents"
    model.syncPluralName = "OvertimeAuditEvents"
    
    model.attributes(
      .index(fields: ["postingId", "createdAt"], name: "auditsByPosting"),
      .primaryKey(fields: [overtimeAuditEvent.id])
    )
    
    model.fields(
      .field(overtimeAuditEvent.id, is: .required, ofType: .string),
      .field(overtimeAuditEvent.postingId, is: .required, ofType: .string),
      .field(overtimeAuditEvent.type, is: .required, ofType: .string),
      .field(overtimeAuditEvent.details, is: .optional, ofType: .string),
      .field(overtimeAuditEvent.createdBy, is: .optional, ofType: .string),
      .field(overtimeAuditEvent.createdAt, is: .optional, ofType: .dateTime),
      .field(overtimeAuditEvent.updatedAt, is: .optional, isReadOnly: true, ofType: .dateTime)
    )
    }
}

extension OvertimeAuditEvent: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}