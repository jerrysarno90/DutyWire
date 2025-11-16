// swiftlint:disable all
import Amplify
import Foundation

public struct OvertimeAuditEvent: Model {
  public let id: String
  public var postingId: String
  public var type: String
  public var details: String?
  public var createdBy: String?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      postingId: String,
      type: String,
      details: String? = nil,
      createdBy: String? = nil,
      createdAt: Temporal.DateTime? = nil) {
    self.init(id: id,
      postingId: postingId,
      type: type,
      details: details,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: nil)
  }
  internal init(id: String = UUID().uuidString,
      postingId: String,
      type: String,
      details: String? = nil,
      createdBy: String? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.postingId = postingId
      self.type = type
      self.details = details
      self.createdBy = createdBy
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}