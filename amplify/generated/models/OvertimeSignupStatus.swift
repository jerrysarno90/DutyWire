// swiftlint:disable all
import Amplify
import Foundation

public enum OvertimeSignupStatus: String, EnumPersistable {
  case pending = "PENDING"
  case confirmed = "CONFIRMED"
  case withdrawn = "WITHDRAWN"
  case forced = "FORCED"
}