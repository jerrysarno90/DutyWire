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
  public var policySnapshot: String
  public var selectionPolicy: OvertimeSelectionPolicy?
  public var needsEscalation: Bool?
  public var state: OvertimePostingState
  public var createdBy: String
  public var invites: List<OvertimeInvite>?
  public var auditTrail: List<OvertimeAuditEvent>?
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
      policySnapshot: String,
      selectionPolicy: OvertimeSelectionPolicy? = nil,
      needsEscalation: Bool? = nil,
      state: OvertimePostingState,
      createdBy: String,
      invites: List<OvertimeInvite>? = [],
      auditTrail: List<OvertimeAuditEvent>? = [],
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
      self.policySnapshot = policySnapshot
      self.selectionPolicy = selectionPolicy
      self.needsEscalation = needsEscalation
      self.state = state
      self.createdBy = createdBy
      self.invites = invites
      self.auditTrail = auditTrail
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}