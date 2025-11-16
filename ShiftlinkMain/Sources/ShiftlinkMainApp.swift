//
//  ShiftlinkMainApp.swift
//  ShiftlinkMain
//
//  Created by Jerry Sarno on 11/2/25.
//

import SwiftUI
import Amplify
import UIKit

@main
struct ShiftlinkMainApp: App {
    @StateObject private var auth = AuthViewModel()
    @UIApplicationDelegateAdaptor(PushNotificationCoordinator.self) private var pushCoordinator

    init() {
        AmplifyBootstrap.configure()
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(Color(.systemBlue))
        }
    }
}
