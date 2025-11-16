// swiftlint:disable all
import Amplify
import Foundation

public enum OvertimeScenario: String, EnumPersistable {
  case patrolShortShift = "PATROL_SHORT_SHIFT"
  case sergeantShortShift = "SERGEANT_SHORT_SHIFT"
  case specialEvent = "SPECIAL_EVENT"
  case otherOvertime = "OTHER_OVERTIME"
}