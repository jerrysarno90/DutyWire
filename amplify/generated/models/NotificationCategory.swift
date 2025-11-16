// swiftlint:disable all
import Amplify
import Foundation

public enum NotificationCategory: String, EnumPersistable {
  case overtimePosted = "OVERTIME_POSTED"
  case overtimeEscalation = "OVERTIME_ESCALATION"
  case overtimeForceAssign = "OVERTIME_FORCE_ASSIGN"
  case squadAlert = "SQUAD_ALERT"
  case taskAlert = "TASK_ALERT"
  case bulletin = "BULLETIN"
}