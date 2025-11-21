// swiftlint:disable all
import Amplify
import Foundation

public enum OvertimePolicy: String, EnumPersistable {
  case firstComeFirstServed = "FIRST_COME_FIRST_SERVED"
  case seniority = "SENIORITY"
}