//
//  TenantRegistry.swift
//  ShiftlinkMain
//
//  Created by Codex on 11/11/25.
//

import Foundation

/// High-level status of a tenant’s onboarding lifecycle.
enum TenantOnboardingStatus: String, Codable, CaseIterable, Identifiable {
    case awaitingVerification
    case pendingOwnerBootstrap
    case ready
    case suspended

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .awaitingVerification: return "Awaiting Verification"
        case .pendingOwnerBootstrap: return "Pending Owner Bootstrap"
        case .ready: return "Ready"
        case .suspended: return "Suspended"
        }
    }
}

/// Minimal policy knobs we want every tenant to track before users sign in.
struct TenantSecurityPolicy: Codable, Hashable {
    var requiresPhishingResistantMFA: Bool
    var inviteExpiryHours: Int
    var allowSelfRegistration: Bool
    var defaultRole: String
}

struct TenantLexicon: Codable, Hashable {
    var squadSingular: String
    var squadPlural: String
    var bureauSingular: String
    var bureauPlural: String
    var taskSingular: String
    var taskPlural: String

    init(
        squadSingular: String = "Squad",
        squadPlural: String = "Squads",
        bureauSingular: String = "Bureau",
        bureauPlural: String = "Bureaus",
        taskSingular: String = "Task",
        taskPlural: String = "Tasks"
    ) {
        self.squadSingular = squadSingular
        self.squadPlural = squadPlural
        self.bureauSingular = bureauSingular
        self.bureauPlural = bureauPlural
        self.taskSingular = taskSingular
        self.taskPlural = taskPlural
    }

    static let `standard` = TenantLexicon()
}

struct TenantMetadata: Identifiable, Codable, Hashable {
    let id: UUID
    let orgId: String
    let siteKey: String
    let displayName: String
    var verifiedDomains: [String]
    var ownerUsernames: [String]
    var securityOfficerUsernames: [String]
    var onboardingStatus: TenantOnboardingStatus
    var securityPolicy: TenantSecurityPolicy
    var lexicon: TenantLexicon
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        orgId: String,
        siteKey: String,
        displayName: String,
        verifiedDomains: [String],
        ownerUsernames: [String],
        securityOfficerUsernames: [String],
        onboardingStatus: TenantOnboardingStatus,
        securityPolicy: TenantSecurityPolicy,
        lexicon: TenantLexicon = .standard,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orgId = orgId
        self.siteKey = siteKey
        self.displayName = displayName
        self.verifiedDomains = verifiedDomains.map { $0.lowercased() }
        self.ownerUsernames = ownerUsernames
        self.securityOfficerUsernames = securityOfficerUsernames
        self.onboardingStatus = onboardingStatus
        self.securityPolicy = securityPolicy
        self.lexicon = lexicon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func owns(domain: String) -> Bool {
        let normalized = domain.lowercased()
        return verifiedDomains.contains(where: { $0 == normalized })
    }
}

extension TenantMetadata {
    /// Local-only sample tenants so the UI can exercise multi-tenant paths while we build secure onboarding.
    static let sampleTenants: [TenantMetadata] = [
        TenantMetadata(
            orgId: "demo-pd",
            siteKey: "DEMO-PD",
            displayName: "Demo Police Department",
            verifiedDomains: ["demopd.example", "ops.demopd.example", "gmail.com"],
            ownerUsernames: ["gmail.com", "sheriff.demopd", "chief.demopd"],
            securityOfficerUsernames: ["gmail.com", "aso.demopd"],
            onboardingStatus: .ready,
            securityPolicy: TenantSecurityPolicy(
                requiresPhishingResistantMFA: true,
                inviteExpiryHours: 24,
                allowSelfRegistration: false,
                defaultRole: "Officer"
            ),
            lexicon: .standard
        ),
        TenantMetadata(
            orgId: "alpha-sheriff",
            siteKey: "ALPHA-SO",
            displayName: "Alpha County Sheriff's Office",
            verifiedDomains: ["alphaso.example"],
            ownerUsernames: ["sheriff.alpha", "chief.alpha"],
            securityOfficerUsernames: ["aso.alpha"],
            onboardingStatus: .pendingOwnerBootstrap,
            securityPolicy: TenantSecurityPolicy(
                requiresPhishingResistantMFA: true,
                inviteExpiryHours: 12,
                allowSelfRegistration: false,
                defaultRole: "Officer"
            ),
            lexicon: TenantLexicon(
                squadSingular: "Platoon",
                squadPlural: "Platoons",
                bureauSingular: "Division",
                bureauPlural: "Divisions",
                taskSingular: "Directive",
                taskPlural: "Directives"
            )
        ),
        TenantMetadata(
            orgId: "beta-campus",
            siteKey: "BETA-CAMPUS",
            displayName: "Beta University Public Safety",
            verifiedDomains: ["publicsafety.beta.edu"],
            ownerUsernames: ["captain.beta"],
            securityOfficerUsernames: ["aso.beta", "infosec.beta"],
            onboardingStatus: .awaitingVerification,
            securityPolicy: TenantSecurityPolicy(
                requiresPhishingResistantMFA: false,
                inviteExpiryHours: 48,
                allowSelfRegistration: true,
                defaultRole: "Supervisor"
            ),
            lexicon: TenantLexicon(
                squadSingular: "Watch",
                squadPlural: "Watches",
                bureauSingular: "Precinct",
                bureauPlural: "Precincts",
                taskSingular: "Assignment",
                taskPlural: "Assignments"
            )
        )
    ]
}

/// Extremely lightweight registry we can swap out for a backend service later.
final class TenantRegistry {
    static let shared = TenantRegistry()

    private(set) var tenants: [TenantMetadata]
    private var siteKeyIndex: [String: TenantMetadata] = [:]
    private var orgIdIndex: [String: TenantMetadata] = [:]
    private var domainIndex: [String: TenantMetadata] = [:]

    init(initialTenants: [TenantMetadata] = TenantMetadata.sampleTenants) {
        self.tenants = initialTenants
        rebuildIndexes()
    }

    func tenant(forSiteKey siteKey: String) -> TenantMetadata? {
        siteKeyIndex[siteKey.lowercased()]
    }

    func tenant(forOrgId orgId: String) -> TenantMetadata? {
        orgIdIndex[orgId.lowercased()]
    }

    func tenant(forDomain domain: String) -> TenantMetadata? {
        domainIndex[domain.lowercased()]
    }

    func resolveTenant(siteKey: String?, orgId: String?, email: String? = nil) -> TenantMetadata? {
        if let siteKey, let tenant = tenant(forSiteKey: siteKey) {
            return tenant
        }
        if let orgId, let tenant = tenant(forOrgId: orgId) {
            return tenant
        }
        if
            let email,
            let domainPart = email.split(separator: "@").last.map(String.init),
            let tenant = tenant(forDomain: domainPart)
        {
            return tenant
        }
        return nil
    }

    func upsert(_ tenant: TenantMetadata) {
        if let index = tenants.firstIndex(where: { $0.id == tenant.id }) {
            tenants[index] = tenant
        } else {
            tenants.append(tenant)
        }
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        siteKeyIndex.removeAll()
        orgIdIndex.removeAll()
        domainIndex.removeAll()

        for tenant in tenants {
            siteKeyIndex[tenant.siteKey.lowercased()] = tenant
            orgIdIndex[tenant.orgId.lowercased()] = tenant
            for domain in tenant.verifiedDomains {
                domainIndex[domain.lowercased()] = tenant
            }
        }
    }
}
