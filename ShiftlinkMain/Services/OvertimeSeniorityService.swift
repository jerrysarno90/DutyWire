import Foundation

struct OvertimeSeniorityService {
    private let fallbackHelper = OvertimeRotationEngine()
    private let priorityOrder: [OvertimeRankBucket] = [.captain, .lieutenant, .sergeant, .patrol]

    func planInvites(
        for posting: OvertimePostingContext,
        policy: RotationPolicySnapshot,
        delayMinutes: Int
    ) throws -> RotationEngineResult {
        var invites: [RotationInviteStep] = []
        var seen = Set<String>()
        var sequence = 1

        for bucket in priorityOrder {
            guard let snapshot = policy[bucket: bucket] else { continue }
            let officers = snapshot.orderedOfficerIds.sorted { lhs, rhs in
                lhs.numericValue < rhs.numericValue
            }
            for officer in officers where !seen.contains(officer) {
                let delay = max(0, delayMinutes * (sequence - 1))
                invites.append(
                    RotationInviteStep(
                        id: UUID(),
                        officerId: officer,
                        bucket: bucket,
                        sequence: sequence,
                        reason: .rotation,
                        delayMinutes: delay
                    )
                )
                seen.insert(officer)
                sequence += 1
            }
        }

        let fallback = fallbackHelper.fallbackAction(for: posting.scenario, policy: policy)
        return RotationEngineResult(invitePlan: invites, fallback: fallback, delayBetweenInvites: delayMinutes)
    }
}
