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
    case updatedAt
    case createdAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let vehicle = Vehicle.keys
    
    model.authRules = [
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete]),
      rule(allow: .private, operations: [.read])
    ]
    
    model.listPluralName = "Vehicles"
    model.syncPluralName = "Vehicles"
    
    model.attributes(
      .index(fields: ["id"], name: nil),
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
      .field(vehicle.updatedAt, is: .required, ofType: .dateTime),
      .field(vehicle.createdAt, is: .required, ofType: .dateTime)
    )
    }
    public class Path: ModelPath<Vehicle> { }
    
    public static var rootPath: PropertyContainerPath? { Path() }
}

extension Vehicle: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}
extension ModelPath where ModelType == Vehicle {
  public var id: FieldPath<String>   {
      string("id") 
    }
  public var orgId: FieldPath<String>   {
      string("orgId") 
    }
  public var callsign: FieldPath<String>   {
      string("callsign") 
    }
  public var make: FieldPath<String>   {
      string("make") 
    }
  public var model: FieldPath<String>   {
      string("model") 
    }
  public var plate: FieldPath<String>   {
      string("plate") 
    }
  public var inService: FieldPath<Bool>   {
      bool("inService") 
    }
  public var updatedAt: FieldPath<Temporal.DateTime>   {
      datetime("updatedAt") 
    }
  public var createdAt: FieldPath<Temporal.DateTime>   {
      datetime("createdAt") 
    }
}