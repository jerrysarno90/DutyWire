//
//  OnboardingAccessController.swift
//  ShiftlinkMain
//
//  Created by Codex on 11/11/25.
//

import Foundation

enum OnboardingAccessDecision {
    case allowed(tenant: TenantMetadata)
    case blocked(reason: String)
}

/// Central gatekeeper that validates site keys and duty emails before allowing authentication.
final class OnboardingAccessController {
    static let shared = OnboardingAccessController()

    private init() {}

    func evaluate(siteKey rawSiteKey: String, email rawEmail: String) -> OnboardingAccessDecision {
        let siteKey = rawSiteKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !siteKey.isEmpty else {
            return blocked(
                reason: "Enter your agency site key.",
                tenant: nil,
                metadata: ["email": email]
            )
        }

        guard !email.isEmpty else {
            return blocked(
                reason: "Enter your agency email address.",
                tenant: nil,
                metadata: ["siteKey": siteKey]
            )
        }

        guard let tenant = TenantRegistry.shared.tenant(forSiteKey: siteKey) else {
            return blocked(
                reason: "That site key is not registered. Contact DutyWire Support to be added.",
                tenant: nil,
                metadata: ["siteKey": siteKey, "email": email]
            )
        }

        guard tenant.onboardingStatus == .ready else {
            return blocked(
                reason: "\(tenant.displayName) is still onboarding (\(tenant.onboardingStatus.displayName)). Please try again later or contact DutyWire Support.",
                tenant: tenant,
                metadata: ["siteKey": siteKey, "email": email]
            )
        }

        guard isEmailAllowed(email, tenant: tenant) else {
            return blocked(
                reason: "This email domain is not authorized for \(tenant.displayName). Use your duty email or contact DutyWire to be provisioned.",
                tenant: tenant,
                metadata: ["siteKey": siteKey, "email": email]
            )
        }

        AuditLogger.shared.record(
            category: .authentication,
            tenantId: tenant.orgId,
            message: "Login gate passed",
            metadata: ["siteKey": siteKey, "email": email]
        )
        return .allowed(tenant: tenant)
    }

    private func isEmailAllowed(_ email: String, tenant: TenantMetadata) -> Bool {
        guard let domainPart = email.split(separator: "@").last.map(String.init) else {
            return false
        }
        return tenant.owns(domain: domainPart)
    }

    private func blocked(
        reason: String,
        tenant: TenantMetadata?,
        metadata: [String: String]
    ) -> OnboardingAccessDecision {
        AuditLogger.shared.record(
            category: .onboarding,
            tenantId: tenant?.orgId,
            message: reason,
            metadata: metadata
        )
        return .blocked(reason: reason)
    }
}
