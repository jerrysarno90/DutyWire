// swiftlint:disable all
import Amplify
import Foundation

extension OvertimeInvite {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case postingId
    case officerId
    case bucket
    case sequence
    case reason
    case status
    case respondedAt
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let overtimeInvite = OvertimeInvite.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "officerId", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete, .read])
    ]
    
    model.listPluralName = "OvertimeInvites"
    model.syncPluralName = "OvertimeInvites"
    
    model.attributes(
      .index(fields: ["postingId", "sequence"], name: "invitesByPosting"),
      .primaryKey(fields: [overtimeInvite.id])
    )
    
    model.fields(
      .field(overtimeInvite.id, is: .required, ofType: .string),
      .field(overtimeInvite.postingId, is: .required, ofType: .string),
      .field(overtimeInvite.officerId, is: .required, ofType: .string),
      .field(overtimeInvite.bucket, is: .required, ofType: .string),
      .field(overtimeInvite.sequence, is: .required, ofType: .int),
      .field(overtimeInvite.reason, is: .required, ofType: .string),
      .field(overtimeInvite.status, is: .required, ofType: .enum(type: OvertimeInviteStatus.self)),
      .field(overtimeInvite.respondedAt, is: .optional, ofType: .dateTime),
      .field(overtimeInvite.createdAt, is: .optional, ofType: .dateTime),
      .field(overtimeInvite.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension OvertimeInvite: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}