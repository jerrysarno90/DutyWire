// swiftlint:disable all
import Amplify
import Foundation

public struct CalendarEvent: Model {
  public let id: String
  public var orgId: String
  public var ownerId: String
  public var title: String
  public var category: String
  public var color: String
  public var notes: String?
  public var startsAt: Temporal.DateTime
  public var endsAt: Temporal.DateTime
  public var reminderMinutesBefore: Int?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      ownerId: String,
      title: String,
      category: String,
      color: String,
      notes: String? = nil,
      startsAt: Temporal.DateTime,
      endsAt: Temporal.DateTime,
      reminderMinutesBefore: Int? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.orgId = orgId
      self.ownerId = ownerId
      self.title = title
      self.category = category
      self.color = color
      self.notes = notes
      self.startsAt = startsAt
      self.endsAt = endsAt
      self.reminderMinutesBefore = reminderMinutesBefore
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}