// swiftlint:disable all
import Amplify
import Foundation

extension OvertimePosting {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case title
    case location
    case scenario
    case startsAt
    case endsAt
    case slots
    case policySnapshot
    case selectionPolicy
    case needsEscalation
    case state
    case createdBy
    case invites
    case auditTrail
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let overtimePosting = OvertimePosting.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "createdBy", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete, .read])
    ]
    
    model.listPluralName = "OvertimePostings"
    model.syncPluralName = "OvertimePostings"
    
    model.attributes(
      .index(fields: ["orgId", "startsAt"], name: "overtimeByOrg"),
      .primaryKey(fields: [overtimePosting.id])
    )
    
    model.fields(
      .field(overtimePosting.id, is: .required, ofType: .string),
      .field(overtimePosting.orgId, is: .required, ofType: .string),
      .field(overtimePosting.title, is: .required, ofType: .string),
      .field(overtimePosting.location, is: .optional, ofType: .string),
      .field(overtimePosting.scenario, is: .required, ofType: .enum(type: OvertimeScenario.self)),
      .field(overtimePosting.startsAt, is: .required, ofType: .dateTime),
      .field(overtimePosting.endsAt, is: .required, ofType: .dateTime),
      .field(overtimePosting.slots, is: .required, ofType: .int),
      .field(overtimePosting.policySnapshot, is: .required, ofType: .string),
      .field(overtimePosting.selectionPolicy, is: .optional, ofType: .enum(type: OvertimeSelectionPolicy.self)),
      .field(overtimePosting.needsEscalation, is: .optional, ofType: .bool),
      .field(overtimePosting.state, is: .required, ofType: .enum(type: OvertimePostingState.self)),
      .field(overtimePosting.createdBy, is: .required, ofType: .string),
      .hasMany(overtimePosting.invites, is: .optional, ofType: OvertimeInvite.self, associatedWith: OvertimeInvite.keys.postingId),
      .hasMany(overtimePosting.auditTrail, is: .optional, ofType: OvertimeAuditEvent.self, associatedWith: OvertimeAuditEvent.keys.postingId),
      .field(overtimePosting.createdAt, is: .optional, ofType: .dateTime),
      .field(overtimePosting.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension OvertimePosting: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}