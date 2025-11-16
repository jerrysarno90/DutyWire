// swiftlint:disable all
import Amplify
import Foundation

public struct NotificationMessage: Model {
  public let id: String
  public var orgId: String
  public var title: String
  public var body: String
  public var category: NotificationCategory
  public var recipients: [String]
  public var metadata: String?
  public var createdBy: String
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      title: String,
      body: String,
      category: NotificationCategory,
      recipients: [String] = [],
      metadata: String? = nil,
      createdBy: String,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.orgId = orgId
      self.title = title
      self.body = body
      self.category = category
      self.recipients = recipients
      self.metadata = metadata
      self.createdBy = createdBy
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}