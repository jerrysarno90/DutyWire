// swiftlint:disable all
import Amplify
import Foundation

public struct NotificationReceipt: Model {
  public let id: String
  public var notificationId: String
  public var userId: String
  public var orgId: String
  public var isRead: Bool
  public var readAt: Temporal.DateTime?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      notificationId: String,
      userId: String,
      orgId: String,
      isRead: Bool,
      readAt: Temporal.DateTime? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.notificationId = notificationId
      self.userId = userId
      self.orgId = orgId
      self.isRead = isRead
      self.readAt = readAt
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}