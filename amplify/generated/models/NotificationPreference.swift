// swiftlint:disable all
import Amplify
import Foundation

public struct NotificationPreference: Model {
  public let id: String
  public var userId: String
  public var generalBulletin: Bool
  public var taskAlert: Bool
  public var overtime: Bool
  public var squadMessages: Bool
  public var other: Bool
  public var contactPhone: String?
  public var contactEmail: String?
  public var backupEmail: String?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      userId: String,
      generalBulletin: Bool,
      taskAlert: Bool,
      overtime: Bool,
      squadMessages: Bool,
      other: Bool,
      contactPhone: String? = nil,
      contactEmail: String? = nil,
      backupEmail: String? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.userId = userId
      self.generalBulletin = generalBulletin
      self.taskAlert = taskAlert
      self.overtime = overtime
      self.squadMessages = squadMessages
      self.other = other
      self.contactPhone = contactPhone
      self.contactEmail = contactEmail
      self.backupEmail = backupEmail
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}