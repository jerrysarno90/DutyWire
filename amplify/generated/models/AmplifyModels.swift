// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "4d3b5c0d28889af5d70789f6ec10d333"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: RosterEntry.self)
    ModelRegistry.register(modelType: Vehicle.self)
    ModelRegistry.register(modelType: CalendarEvent.self)
    ModelRegistry.register(modelType: OfficerAssignment.self)
    ModelRegistry.register(modelType: OvertimePosting.self)
    ModelRegistry.register(modelType: OvertimeInvite.self)
    ModelRegistry.register(modelType: OvertimeAuditEvent.self)
    ModelRegistry.register(modelType: NotificationEndpoint.self)
    ModelRegistry.register(modelType: NotificationMessage.self)
    ModelRegistry.register(modelType: NotificationPreference.self)
  }
}