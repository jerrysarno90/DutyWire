// swiftlint:disable all
import Amplify
import Foundation

extension RosterEntry {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case badgeNumber
    case shift
    case startsAt
    case endsAt
    case notes
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let rosterEntry = RosterEntry.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "badgeNumber", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin"], provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Supervisor"], provider: .userPools, operations: [.read])
    ]
    
    model.listPluralName = "RosterEntries"
    model.syncPluralName = "RosterEntries"
    
    model.attributes(
      .index(fields: ["orgId", "startsAt"], name: "rosterEntriesByOrg"),
      .primaryKey(fields: [rosterEntry.id])
    )
    
    model.fields(
      .field(rosterEntry.id, is: .required, ofType: .string),
      .field(rosterEntry.orgId, is: .required, ofType: .string),
      .field(rosterEntry.badgeNumber, is: .required, ofType: .string),
      .field(rosterEntry.shift, is: .optional, ofType: .string),
      .field(rosterEntry.startsAt, is: .required, ofType: .dateTime),
      .field(rosterEntry.endsAt, is: .required, ofType: .dateTime),
      .field(rosterEntry.notes, is: .optional, ofType: .string),
      .field(rosterEntry.createdAt, is: .optional, ofType: .dateTime),
      .field(rosterEntry.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension RosterEntry: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}