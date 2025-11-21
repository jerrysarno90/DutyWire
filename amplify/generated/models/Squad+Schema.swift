// swiftlint:disable all
import Amplify
import Foundation

extension Squad {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case name
    case bureau
    case shift
    case notes
    case isActive
    case memberships
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let squad = Squad.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["AgencyManager", "Admin"], provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Supervisor"], provider: .userPools, operations: [.read])
    ]
    
    model.listPluralName = "Squads"
    model.syncPluralName = "Squads"
    
    model.attributes(
      .primaryKey(fields: [squad.id])
    )
    
    model.fields(
      .field(squad.id, is: .required, ofType: .string),
      .field(squad.orgId, is: .required, ofType: .string),
      .field(squad.name, is: .required, ofType: .string),
      .field(squad.bureau, is: .required, ofType: .string),
      .field(squad.shift, is: .optional, ofType: .string),
      .field(squad.notes, is: .optional, ofType: .string),
      .field(squad.isActive, is: .required, ofType: .bool),
      .hasMany(squad.memberships, is: .optional, ofType: SquadMembership.self, associatedWith: SquadMembership.keys.squadId),
      .field(squad.createdAt, is: .optional, ofType: .dateTime),
      .field(squad.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension Squad: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}