//
//  AmplifyBootstrap.swift
//  ShiftlinkMain
//
//  Created by Codex on 11/21/25.
//

import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import AWSS3StoragePlugin

/// Centralized Amplify configuration with Gen 2 + Gen 1 fallbacks.
enum AmplifyBootstrap {
    private static var didConfigure = false

    static func configure() {
        guard !didConfigure else { return }
        do {
            let resource = loadConfigurationResource()

            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin(modelRegistration: AmplifyModels()))

            if resource?.containsS3Plugin == true {
                try Amplify.add(plugin: AWSS3StoragePlugin())
            }

            if let configURL = resource?.url {
                let configuration = try AmplifyConfiguration(configurationFile: configURL)
                try Amplify.configure(configuration)
            } else {
                try Amplify.configure()
            }

            didConfigure = true
            print("[Amplify] configured")
        } catch {
            assertionFailure("Amplify failed to configure: \(error)")
        }
    }

    private static func loadConfigurationResource() -> (url: URL, containsS3Plugin: Bool)? {
        let candidates = ["amplifyconfiguration", "amplify configuration", "amplify_outputs"]
        for name in candidates {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let containsS3 = ((object["storage"] as? [String: Any])?["plugins"] as? [String: Any])?["awsS3StoragePlugin"] != nil

            return (url, containsS3)
        }
        return nil
    }
}
