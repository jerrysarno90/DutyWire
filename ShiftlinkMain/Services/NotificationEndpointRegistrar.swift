import Foundation
import UIKit

actor NotificationEndpointRegistrar {
    static let shared = NotificationEndpointRegistrar()

    private var lastRegisteredToken: String?
    private var lastUserId: String?
    private var lastOrgId: String?
    private var lastEndpointId: String?

    func registerCurrentDevice(token: String, userId: String, orgId: String) async {
        guard token != lastRegisteredToken || userId != lastUserId || orgId != lastOrgId else { return }
        do {
            let record = try await NotificationEndpointService.upsertEndpoint(
                userId: userId,
                orgId: orgId,
                token: token,
                platform: .ios,
                deviceName: UIDevice.current.name
            )
            lastRegisteredToken = token
            lastUserId = userId
            lastOrgId = orgId
            lastEndpointId = record.id
        } catch {
            print("[DutyWire] Failed to register notification endpoint: \(error)")
        }
    }

    func disableAfterSignOut() async {
        guard let endpointId = lastEndpointId else {
            lastRegisteredToken = nil
            lastUserId = nil
            return
        }

        do {
            try await NotificationEndpointService.setEnabled(endpointId: endpointId, enabled: false)
        } catch {
            print("[DutyWire] Failed to disable notification endpoint: \(error)")
        }

        lastRegisteredToken = nil
        lastUserId = nil
        lastOrgId = nil
        lastEndpointId = nil
    }
}
