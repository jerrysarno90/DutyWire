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
    case updatedAt
    case createdAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let rosterEntry = RosterEntry.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete]),
      rule(allow: .private, operations: [.read])
    ]
    
    model.listPluralName = "RosterEntries"
    model.syncPluralName = "RosterEntries"
    
    model.attributes(
      .index(fields: ["id"], name: nil),
      .primaryKey(fields: [rosterEntry.id])
    )
    
    model.fields(
      .field(rosterEntry.id, is: .required, ofType: .string),
      .field(rosterEntry.orgId, is: .required, ofType: .string),
      .field(rosterEntry.badgeNumber, is: .required, ofType: .string),
      .field(rosterEntry.shift, is: .optional, ofType: .string),
      .field(rosterEntry.startsAt, is: .required, ofType: .dateTime),
      .field(rosterEntry.endsAt, is: .required, ofType: .dateTime),
      .field(rosterEntry.updatedAt, is: .required, ofType: .dateTime),
      .field(rosterEntry.createdAt, is: .required, ofType: .dateTime)
    )
    }
    public class Path: ModelPath<RosterEntry> { }
    
    public static var rootPath: PropertyContainerPath? { Path() }
}

extension RosterEntry: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}
extension ModelPath where ModelType == RosterEntry {
  public var id: FieldPath<String>   {
      string("id") 
    }
  public var orgId: FieldPath<String>   {
      string("orgId") 
    }
  public var badgeNumber: FieldPath<String>   {
      string("badgeNumber") 
    }
  public var shift: FieldPath<String>   {
      string("shift") 
    }
  public var startsAt: FieldPath<Temporal.DateTime>   {
      datetime("startsAt") 
    }
  public var endsAt: FieldPath<Temporal.DateTime>   {
      datetime("endsAt") 
    }
  public var updatedAt: FieldPath<Temporal.DateTime>   {
      datetime("updatedAt") 
    }
  public var createdAt: FieldPath<Temporal.DateTime>   {
      datetime("createdAt") 
    }
}