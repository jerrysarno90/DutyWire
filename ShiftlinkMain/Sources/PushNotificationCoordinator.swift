import SwiftUI
import UIKit
import UserNotifications

final class PushNotificationCoordinator: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let tokenDefaultsKey = "DutyWire.PushToken"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        persist(token: token)
        NotificationCenter.default.post(name: .pushTokenUpdated, object: token)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[DutyWire] Remote notification registration failed:", error)
    }

    private func persist(token: String) {
        let current = UserDefaults.standard.string(forKey: Self.tokenDefaultsKey)
        guard current != token else { return }
        UserDefaults.standard.set(token, forKey: Self.tokenDefaultsKey)
    }
}

extension Notification.Name {
    static let pushTokenUpdated = Notification.Name("DutyWirePushTokenUpdated")
}
