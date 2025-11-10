//
//  ShiftlinkMainApp.swift
//  ShiftlinkMain
//
//  Created by Jerry Sarno on 11/2/25.
//

import SwiftUI
import Amplify

@main
struct ShiftlinkMainApp: App {
    @StateObject private var auth = AuthViewModel()

    init() {
        AmplifyBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(Color(.systemBlue))
        }
    }
}
