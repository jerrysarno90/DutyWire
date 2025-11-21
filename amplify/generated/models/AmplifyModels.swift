// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "4c7de1c9c9ecde3c2a294e619102a0f6"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: RosterEntry.self)
    ModelRegistry.register(modelType: Vehicle.self)
    ModelRegistry.register(modelType: CalendarEvent.self)
    ModelRegistry.register(modelType: OfficerAssignment.self)
    ModelRegistry.register(modelType: OvertimePosting.self)
    ModelRegistry.register(modelType: OvertimeSignup.self)
    ModelRegistry.register(modelType: NotificationEndpoint.self)
    ModelRegistry.register(modelType: NotificationMessage.self)
    ModelRegistry.register(modelType: NotificationPreference.self)
    ModelRegistry.register(modelType: Squad.self)
    ModelRegistry.register(modelType: SquadMembership.self)
    ModelRegistry.register(modelType: NotificationReceipt.self)
  }
}