// swiftlint:disable all
import Amplify
import Foundation

public struct SquadMembership: Model {
  public let id: String
  public var squadId: String
  public var userId: String
  public var roleInSquad: SquadRole
  public var isPrimary: Bool
  public var isActive: Bool
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      squadId: String,
      userId: String,
      roleInSquad: SquadRole,
      isPrimary: Bool,
      isActive: Bool,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.squadId = squadId
      self.userId = userId
      self.roleInSquad = roleInSquad
      self.isPrimary = isPrimary
      self.isActive = isActive
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}