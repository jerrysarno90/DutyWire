// swiftlint:disable all
import Amplify
import Foundation

public struct Squad: Model {
  public let id: String
  public var orgId: String
  public var name: String
  public var bureau: String
  public var shift: String?
  public var notes: String?
  public var isActive: Bool
  public var memberships: List<SquadMembership>?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      name: String,
      bureau: String,
      shift: String? = nil,
      notes: String? = nil,
      isActive: Bool,
      memberships: List<SquadMembership>? = [],
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.orgId = orgId
      self.name = name
      self.bureau = bureau
      self.shift = shift
      self.notes = notes
      self.isActive = isActive
      self.memberships = memberships
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}