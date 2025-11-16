// swiftlint:disable all
import Amplify
import Foundation

public struct OvertimeInvite: Model {
  public let id: String
  public var postingId: String
  public var officerId: String
  public var bucket: String
  public var sequence: Int
  public var reason: String
  public var status: OvertimeInviteStatus
  public var respondedAt: Temporal.DateTime?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      postingId: String,
      officerId: String,
      bucket: String,
      sequence: Int,
      reason: String,
      status: OvertimeInviteStatus,
      respondedAt: Temporal.DateTime? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.postingId = postingId
      self.officerId = officerId
      self.bucket = bucket
      self.sequence = sequence
      self.reason = reason
      self.status = status
      self.respondedAt = respondedAt
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}