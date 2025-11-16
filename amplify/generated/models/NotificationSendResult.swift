// swiftlint:disable all
import Amplify
import Foundation

public struct NotificationSendResult: Embeddable {
  var success: Bool
  var delivered: Int?
  var recipientCount: Int?
  var message: String?
}