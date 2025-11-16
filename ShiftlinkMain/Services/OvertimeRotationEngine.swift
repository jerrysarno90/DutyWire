//
//  OvertimeRotationEngine.swift
//  DutyWire
//
//  Created by Codex on 11/12/25.
//

import Foundation

// MARK: - Core Models

/// High-level rank buckets used by the rotation policy.
enum OvertimeRankBucket: String, Codable, CaseIterable, Hashable {
    case patrol
    case sergeant
    case lieutenant
    case captain
}

/// Minimal officer record captured in the policy snapshot at the moment an OT post is created.
struct OfficerProfileSummary: Identifiable, Codable, Hashable {
    let id: String
    let badgeNumber: Int
    let displayName: String
    let rankBucket: OvertimeRankBucket
    let unit: String?
    let isEligible: Bool
}

/// Ordered queue + pointer metadata for a specific rank bucket.
struct RotationBucketSnapshot: Codable, Hashable {
    var bucket: OvertimeRankBucket
    /// Officers sorted according to the collective bargaining agreement (usually ascending badge / computer number).
    var orderedOfficerIds: [String]
    /// Officer who most recently accepted overtime from this bucket.
    var lastServedOfficerId: String?
    
    /// Returns the rotation order beginning with the officer who is junior to `lastServedOfficerId`.
    func rotationSequence(excluding excluded: Set<String> = []) -> [String] {
        guard !orderedOfficerIds.isEmpty else { return [] }
        let filtered = orderedOfficerIds.filter { !excluded.contains($0) }
        guard let last = lastServedOfficerId, let index = filtered.firstIndex(of: last) else {
            return filtered
        }
        let nextIndex = filtered.index(after: index)
        if nextIndex >= filtered.endIndex {
            return filtered
        }
        return Array(filtered[nextIndex...]) + Array(filtered[..<nextIndex])
    }
}

/// Officers available for forced assignment (least senior from the prior shift, etc).
struct ForcedAssignmentPool: Codable, Hashable {
    var bucket: OvertimeRankBucket
    var orderedOfficerIds: [String] // ascending badge number (least senior last)
    
    var leastSeniorEligible: String? {
        return orderedOfficerIds.last
    }
}

/// Snapshot of all rotation buckets + fallback pools captured when the posting is created.
struct RotationPolicySnapshot: Codable {
    var buckets: [OvertimeRankBucket: RotationBucketSnapshot]
    var fallbackPools: [OvertimeRankBucket: ForcedAssignmentPool]
    var inviteDelayMinutes: Int
    var responseDeadline: Date?
    var additionalNotes: String?
    var attachments: [AttachmentReference]?
    
    init(
        buckets: [OvertimeRankBucket: RotationBucketSnapshot],
        fallbackPools: [OvertimeRankBucket: ForcedAssignmentPool],
        inviteDelayMinutes: Int = 0,
        responseDeadline: Date? = nil,
        additionalNotes: String? = nil,
        attachments: [AttachmentReference]? = nil
    ) {
        self.buckets = buckets
        self.fallbackPools = fallbackPools
        self.inviteDelayMinutes = inviteDelayMinutes
        self.responseDeadline = responseDeadline
        self.additionalNotes = additionalNotes
        self.attachments = attachments
    }
    
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    enum CodingKeys: String, CodingKey {
        case buckets
        case fallbackPools
        case inviteDelayMinutes
        case responseDeadline
        case additionalNotes
        case attachments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buckets = try container.decode([OvertimeRankBucket: RotationBucketSnapshot].self, forKey: .buckets)
        fallbackPools = try container.decode([OvertimeRankBucket: ForcedAssignmentPool].self, forKey: .fallbackPools)
        inviteDelayMinutes = try container.decodeIfPresent(Int.self, forKey: .inviteDelayMinutes) ?? 0
        if let deadlineString = try container.decodeIfPresent(String.self, forKey: .responseDeadline) {
            responseDeadline = RotationPolicySnapshot.dateFormatter.date(from: deadlineString)
        } else {
            responseDeadline = nil
        }
        additionalNotes = try container.decodeIfPresent(String.self, forKey: .additionalNotes)
        attachments = try container.decodeIfPresent([AttachmentReference].self, forKey: .attachments)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buckets, forKey: .buckets)
        try container.encode(fallbackPools, forKey: .fallbackPools)
        try container.encode(inviteDelayMinutes, forKey: .inviteDelayMinutes)
        if let responseDeadline {
            let string = RotationPolicySnapshot.dateFormatter.string(from: responseDeadline)
            try container.encode(string, forKey: .responseDeadline)
        }
        if let additionalNotes {
            try container.encode(additionalNotes, forKey: .additionalNotes)
        }
        if let attachments, !attachments.isEmpty {
            try container.encode(attachments, forKey: .attachments)
        }
    }
    
    subscript(bucket bucket: OvertimeRankBucket) -> RotationBucketSnapshot? {
        get { buckets[bucket] }
    }
}

/// Context supplied by the supervisor when creating a posting.
struct OvertimePostingContext: Codable {
    enum VacancyScenario: String, Codable {
        case patrolPreferred
        case noSergeantOnDuty
        case supervisorRequiredButShort
    }
    
    var id: UUID
    var orgId: String
    var start: Date
    var end: Date
    var title: String
    var location: String?
    var slots: Int
    var sergeantsOnDuty: Int
    var requiresSupervisor: Bool = false
    
    var scenario: VacancyScenario {
        return .patrolPreferred
    }
}

/// Planned invite order returned by the engine.
struct RotationInviteStep: Identifiable, Codable {
    enum Reason: String, Codable {
        case rotation
        case escalatedBucket
        case forcedAssignment
    }
    
    let id: UUID
    let officerId: String
    let bucket: OvertimeRankBucket
    let sequence: Int
    let reason: Reason
    let delayMinutes: Int
}

struct RotationFallbackAction: Codable {
    let officerId: String?
    let bucket: OvertimeRankBucket
    let explanation: String
}

struct RotationEngineResult {
    let invitePlan: [RotationInviteStep]
    let fallback: RotationFallbackAction?
    let delayBetweenInvites: Int
}

// MARK: - Engine

enum RotationEngineError: Error {
    case bucketUnavailable(OvertimeRankBucket)
    case policySnapshotMissing
}

extension RotationEngineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .bucketUnavailable(let bucket):
            return "No officers are available in the \(bucket.rawValue.capitalized) queue. Select a different rank or update the roster."
        case .policySnapshotMissing:
            return "The overtime policy snapshot is missing required data."
        }
    }
}

struct OvertimeRotationEngine {
    /// Generates the invite sequence + fallback recommendation for a new posting.
    func generatePlan(
        posting: OvertimePostingContext,
        policy: RotationPolicySnapshot,
        delayBetweenInvitesMinutes: Int
    ) throws -> RotationEngineResult {
        var bucketsOrder = queueOrder(for: posting.scenario)
        let prioritizedBuckets = Set(bucketsOrder.map { $0.0 })
        for bucket in OvertimeRankBucket.allCases where policy[bucket: bucket] != nil && !prioritizedBuckets.contains(bucket) {
            bucketsOrder.append((bucket, .rotation))
        }
        
        var invites: [RotationInviteStep] = []
        var seen = Set<String>()
        var sequence = 1
        
        for (bucket, reason) in bucketsOrder {
            guard let snapshot = policy[bucket: bucket] else { continue }
            let rotation = snapshot.rotationSequence(excluding: seen)
            for officer in rotation {
                let delayMinutes = max(0, delayBetweenInvitesMinutes * (sequence - 1))
                invites.append(
                    RotationInviteStep(
                        id: UUID(),
                        officerId: officer,
                        bucket: bucket,
                        sequence: sequence,
                        reason: reason,
                        delayMinutes: delayMinutes
                    )
                )
                seen.insert(officer)
                sequence += 1
            }
        }
        
        let fallback = fallbackAction(for: posting.scenario, policy: policy)
        
        return RotationEngineResult(invitePlan: invites, fallback: fallback, delayBetweenInvites: delayBetweenInvitesMinutes)
    }
    
    /// Determines the ordered list of buckets (with reasons) for the specified scenario.
    private func queueOrder(for scenario: OvertimePostingContext.VacancyScenario) -> [(OvertimeRankBucket, RotationInviteStep.Reason)] {
        switch scenario {
        case .patrolPreferred:
            return [(.patrol, .rotation)]
        case .noSergeantOnDuty:
            return [
                (.sergeant, .rotation),
                (.lieutenant, .escalatedBucket),
                (.patrol, .escalatedBucket)
            ]
        case .supervisorRequiredButShort:
            return [
                (.sergeant, .rotation),
                (.lieutenant, .escalatedBucket)
            ]
        }
    }
    
    /// Suggests which officer should be force-assigned if the queue is exhausted.
    func fallbackAction(
        for scenario: OvertimePostingContext.VacancyScenario,
        policy: RotationPolicySnapshot
    ) -> RotationFallbackAction? {
        let preferredBucket: OvertimeRankBucket
        switch scenario {
        case .patrolPreferred:
            preferredBucket = .patrol
        case .noSergeantOnDuty, .supervisorRequiredButShort:
            preferredBucket = .sergeant
        }
        
        if let pool = policy.fallbackPools[preferredBucket], let officer = pool.leastSeniorEligible {
            return RotationFallbackAction(
                officerId: officer,
                bucket: preferredBucket,
                explanation: "Force assign least-senior \(preferredBucket.rawValue.capitalized) from prior shift per policy."
            )
        }
        
        return nil
    }
}

// MARK: - Service Facade

/// Lightweight façade so the app can swap to a backend-driven planner later.
struct OvertimeRotationService {
    private let engine = OvertimeRotationEngine()
    
    /// Computes a plan locally. In the future this method can call an API/Lambda and simply return the response.
    func planInvites(
        for posting: OvertimePostingContext,
        policy: RotationPolicySnapshot,
        delayMinutes: Int
    ) throws -> RotationEngineResult {
        return try engine.generatePlan(posting: posting, policy: policy, delayBetweenInvitesMinutes: delayMinutes)
    }
}
