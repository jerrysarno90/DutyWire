// swiftlint:disable all
import Amplify
import Foundation

public enum OvertimeSelectionPolicy: String, EnumPersistable {
  case rotation = "ROTATION"
  case seniority = "SENIORITY"
  case firstCome = "FIRST_COME"
}