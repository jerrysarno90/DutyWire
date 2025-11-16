// swiftlint:disable all
import Amplify
import Foundation

public struct OfficerAssignment: Model {
  public let id: String
  public var orgId: String
  public var badgeNumber: String
  public var title: String
  public var detail: String?
  public var location: String?
  public var notes: String?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      badgeNumber: String,
      title: String,
      detail: String? = nil,
      location: String? = nil,
      notes: String? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.orgId = orgId
      self.badgeNumber = badgeNumber
      self.title = title
      self.detail = detail
      self.location = location
      self.notes = notes
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}