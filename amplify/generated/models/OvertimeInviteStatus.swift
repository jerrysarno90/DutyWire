// swiftlint:disable all
import Amplify
import Foundation

public enum OvertimeInviteStatus: String, EnumPersistable {
  case pending = "PENDING"
  case accepted = "ACCEPTED"
  case declined = "DECLINED"
  case ordered = "ORDERED"
  case expired = "EXPIRED"
}