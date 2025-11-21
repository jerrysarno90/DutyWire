// swiftlint:disable all
import Amplify
import Foundation

extension OvertimeSignup {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case postingId
    case orgId
    case officerId
    case status
    case rank
    case rankPriority
    case badgeNumber
    case tieBreakerKey
    case submittedAt
    case forcedBy
    case forcedReason
    case notes
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let overtimeSignup = OvertimeSignup.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "officerId", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete, .read])
    ]
    
    model.listPluralName = "OvertimeSignups"
    model.syncPluralName = "OvertimeSignups"
    
    model.attributes(
      .index(fields: ["postingId", "submittedAt"], name: "signupsByPosting"),
      .index(fields: ["orgId", "submittedAt"], name: "signupsByOrg"),
      .index(fields: ["officerId", "status"], name: "signupsByOfficer"),
      .primaryKey(fields: [overtimeSignup.id])
    )
    
    model.fields(
      .field(overtimeSignup.id, is: .required, ofType: .string),
      .field(overtimeSignup.postingId, is: .required, ofType: .string),
      .field(overtimeSignup.orgId, is: .required, ofType: .string),
      .field(overtimeSignup.officerId, is: .required, ofType: .string),
      .field(overtimeSignup.status, is: .required, ofType: .enum(type: OvertimeSignupStatus.self)),
      .field(overtimeSignup.rank, is: .optional, ofType: .string),
      .field(overtimeSignup.rankPriority, is: .optional, ofType: .int),
      .field(overtimeSignup.badgeNumber, is: .optional, ofType: .string),
      .field(overtimeSignup.tieBreakerKey, is: .optional, ofType: .string),
      .field(overtimeSignup.submittedAt, is: .required, ofType: .dateTime),
      .field(overtimeSignup.forcedBy, is: .optional, ofType: .string),
      .field(overtimeSignup.forcedReason, is: .optional, ofType: .string),
      .field(overtimeSignup.notes, is: .optional, ofType: .string),
      .field(overtimeSignup.createdAt, is: .optional, ofType: .dateTime),
      .field(overtimeSignup.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension OvertimeSignup: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}