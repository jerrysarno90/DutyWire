// swiftlint:disable all
import Amplify
import Foundation

extension Vehicle {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case callsign
    case make
    case model
    case plate
    case inService
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let vehicle = Vehicle.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin"], provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Supervisor"], provider: .userPools, operations: [.read, .update]),
      rule(allow: .private, operations: [.read])
    ]
    
    model.listPluralName = "Vehicles"
    model.syncPluralName = "Vehicles"
    
    model.attributes(
      .index(fields: ["orgId", "callsign"], name: "vehiclesByOrg"),
      .primaryKey(fields: [vehicle.id])
    )
    
    model.fields(
      .field(vehicle.id, is: .required, ofType: .string),
      .field(vehicle.orgId, is: .required, ofType: .string),
      .field(vehicle.callsign, is: .required, ofType: .string),
      .field(vehicle.make, is: .optional, ofType: .string),
      .field(vehicle.model, is: .optional, ofType: .string),
      .field(vehicle.plate, is: .optional, ofType: .string),
      .field(vehicle.inService, is: .optional, ofType: .bool),
      .field(vehicle.createdAt, is: .optional, ofType: .dateTime),
      .field(vehicle.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension Vehicle: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}