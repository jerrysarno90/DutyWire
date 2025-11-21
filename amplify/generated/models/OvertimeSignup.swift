// swiftlint:disable all
import Amplify
import Foundation

public struct OvertimeSignup: Model {
  public let id: String
  public var postingId: String
  public var orgId: String
  public var officerId: String
  public var status: OvertimeSignupStatus
  public var rank: String?
  public var rankPriority: Int?
  public var badgeNumber: String?
  public var tieBreakerKey: String?
  public var submittedAt: Temporal.DateTime
  public var forcedBy: String?
  public var forcedReason: String?
  public var notes: String?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      postingId: String,
      orgId: String,
      officerId: String,
      status: OvertimeSignupStatus,
      rank: String? = nil,
      rankPriority: Int? = nil,
      badgeNumber: String? = nil,
      tieBreakerKey: String? = nil,
      submittedAt: Temporal.DateTime,
      forcedBy: String? = nil,
      forcedReason: String? = nil,
      notes: String? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.postingId = postingId
      self.orgId = orgId
      self.officerId = officerId
      self.status = status
      self.rank = rank
      self.rankPriority = rankPriority
      self.badgeNumber = badgeNumber
      self.tieBreakerKey = tieBreakerKey
      self.submittedAt = submittedAt
      self.forcedBy = forcedBy
      self.forcedReason = forcedReason
      self.notes = notes
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}