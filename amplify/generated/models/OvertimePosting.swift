// swiftlint:disable all
import Amplify
import Foundation

public struct OvertimePosting: Model {
  public let id: String
  public var orgId: String
  public var title: String
  public var location: String?
  public var scenario: OvertimeScenario
  public var startsAt: Temporal.DateTime
  public var endsAt: Temporal.DateTime
  public var slots: Int
  public var policy: OvertimePolicy
  public var notes: String?
  public var deadline: Temporal.DateTime?
  public var state: OvertimePostingState
  public var createdBy: String
  public var signups: List<OvertimeSignup>?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      title: String,
      location: String? = nil,
      scenario: OvertimeScenario,
      startsAt: Temporal.DateTime,
      endsAt: Temporal.DateTime,
      slots: Int,
      policy: OvertimePolicy,
      notes: String? = nil,
      deadline: Temporal.DateTime? = nil,
      state: OvertimePostingState,
      createdBy: String,
      signups: List<OvertimeSignup>? = [],
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.orgId = orgId
      self.title = title
      self.location = location
      self.scenario = scenario
      self.startsAt = startsAt
      self.endsAt = endsAt
      self.slots = slots
      self.policy = policy
      self.notes = notes
      self.deadline = deadline
      self.state = state
      self.createdBy = createdBy
      self.signups = signups
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}