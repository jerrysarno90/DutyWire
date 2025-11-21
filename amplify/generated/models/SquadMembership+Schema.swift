// swiftlint:disable all
import Amplify
import Foundation

extension SquadMembership {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case squadId
    case userId
    case roleInSquad
    case isPrimary
    case isActive
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let squadMembership = SquadMembership.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["AgencyManager", "Admin"], provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Supervisor"], provider: .userPools, operations: [.read]),
      rule(allow: .owner, ownerField: "userId", identityClaim: "cognito:username", provider: .userPools, operations: [.read])
    ]
    
    model.listPluralName = "SquadMemberships"
    model.syncPluralName = "SquadMemberships"
    
    model.attributes(
      .index(fields: ["squadId"], name: "membershipBySquad"),
      .index(fields: ["userId"], name: "membershipByUser"),
      .primaryKey(fields: [squadMembership.id])
    )
    
    model.fields(
      .field(squadMembership.id, is: .required, ofType: .string),
      .field(squadMembership.squadId, is: .required, ofType: .string),
      .field(squadMembership.userId, is: .required, ofType: .string),
      .field(squadMembership.roleInSquad, is: .required, ofType: .enum(type: SquadRole.self)),
      .field(squadMembership.isPrimary, is: .required, ofType: .bool),
      .field(squadMembership.isActive, is: .required, ofType: .bool),
      .field(squadMembership.createdAt, is: .optional, ofType: .dateTime),
      .field(squadMembership.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension SquadMembership: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}