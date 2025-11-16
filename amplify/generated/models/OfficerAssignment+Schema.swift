// swiftlint:disable all
import Amplify
import Foundation

extension OfficerAssignment {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case badgeNumber
    case title
    case detail
    case location
    case notes
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let officerAssignment = OfficerAssignment.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "badgeNumber", identityClaim: "cognito:username", provider: .userPools, operations: [.read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin"], provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Supervisor"], provider: .userPools, operations: [.read, .update])
    ]
    
    model.listPluralName = "OfficerAssignments"
    model.syncPluralName = "OfficerAssignments"
    
    model.attributes(
      .index(fields: ["orgId", "updatedAt"], name: "assignmentsByOrg"),
      .index(fields: ["badgeNumber", "updatedAt"], name: "assignmentsByOfficer"),
      .primaryKey(fields: [officerAssignment.id])
    )
    
    model.fields(
      .field(officerAssignment.id, is: .required, ofType: .string),
      .field(officerAssignment.orgId, is: .required, ofType: .string),
      .field(officerAssignment.badgeNumber, is: .required, ofType: .string),
      .field(officerAssignment.title, is: .required, ofType: .string),
      .field(officerAssignment.detail, is: .optional, ofType: .string),
      .field(officerAssignment.location, is: .optional, ofType: .string),
      .field(officerAssignment.notes, is: .optional, ofType: .string),
      .field(officerAssignment.createdAt, is: .optional, ofType: .dateTime),
      .field(officerAssignment.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension OfficerAssignment: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}