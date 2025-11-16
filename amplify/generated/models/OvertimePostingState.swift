// swiftlint:disable all
import Amplify
import Foundation

public enum OvertimePostingState: String, EnumPersistable {
  case open = "OPEN"
  case filled = "FILLED"
  case closed = "CLOSED"
}