// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "59b559ca8aa05c07eed6e4c5cd460e2a"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: Vehicle.self)
    ModelRegistry.register(modelType: RosterEntry.self)
  }
}