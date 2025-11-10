// swiftlint:disable all
import Amplify
import Foundation

public struct RosterEntry: Model {
  public let id: String
  public var orgId: String
  public var badgeNumber: String
  public var shift: String?
  public var startsAt: Temporal.DateTime
  public var endsAt: Temporal.DateTime
  public var updatedAt: Temporal.DateTime
  public var createdAt: Temporal.DateTime
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      badgeNumber: String,
      shift: String? = nil,
      startsAt: Temporal.DateTime,
      endsAt: Temporal.DateTime,
      updatedAt: Temporal.DateTime,
      createdAt: Temporal.DateTime) {
      self.id = id
      self.orgId = orgId
      self.badgeNumber = badgeNumber
      self.shift = shift
      self.startsAt = startsAt
      self.endsAt = endsAt
      self.updatedAt = updatedAt
      self.createdAt = createdAt
  }
}