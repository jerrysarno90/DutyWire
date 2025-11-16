// swiftlint:disable all
import Amplify
import Foundation

extension CalendarEvent {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case orgId
    case ownerId
    case title
    case category
    case color
    case notes
    case startsAt
    case endsAt
    case reminderMinutesBefore
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let calendarEvent = CalendarEvent.keys
    
    model.authRules = [
      rule(allow: .owner, ownerField: "ownerId", identityClaim: "cognito:username", provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .groups, groupClaim: "cognito:groups", groups: ["Admin", "Supervisor"], provider: .userPools, operations: [.create, .update, .delete, .read]),
      rule(allow: .private, operations: [.read])
    ]
    
    model.listPluralName = "CalendarEvents"
    model.syncPluralName = "CalendarEvents"
    
    model.attributes(
      .index(fields: ["orgId", "startsAt"], name: "eventsByOrg"),
      .index(fields: ["ownerId", "startsAt"], name: "eventsByOwner"),
      .primaryKey(fields: [calendarEvent.id])
    )
    
    model.fields(
      .field(calendarEvent.id, is: .required, ofType: .string),
      .field(calendarEvent.orgId, is: .required, ofType: .string),
      .field(calendarEvent.ownerId, is: .required, ofType: .string),
      .field(calendarEvent.title, is: .required, ofType: .string),
      .field(calendarEvent.category, is: .required, ofType: .string),
      .field(calendarEvent.color, is: .required, ofType: .string),
      .field(calendarEvent.notes, is: .optional, ofType: .string),
      .field(calendarEvent.startsAt, is: .required, ofType: .dateTime),
      .field(calendarEvent.endsAt, is: .required, ofType: .dateTime),
      .field(calendarEvent.reminderMinutesBefore, is: .optional, ofType: .int),
      .field(calendarEvent.createdAt, is: .optional, ofType: .dateTime),
      .field(calendarEvent.updatedAt, is: .optional, ofType: .dateTime)
    )
    }
}

extension CalendarEvent: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}