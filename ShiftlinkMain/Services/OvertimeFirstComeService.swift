import Foundation

struct OvertimeFirstComeService {
    private let fallbackHelper = OvertimeRotationEngine()

    func planInvites(
        for posting: OvertimePostingContext,
        policy: RotationPolicySnapshot
    ) throws -> RotationEngineResult {
        var invites: [RotationInviteStep] = []
        var seen = Set<String>()
        var sequence = 1

        let bucketOrder: [OvertimeRankBucket] = [.captain, .lieutenant, .sergeant, .patrol]

        for bucket in bucketOrder {
            guard let snapshot = policy[bucket: bucket] else { continue }
            for officer in snapshot.orderedOfficerIds where !seen.contains(officer) {
                invites.append(
                    RotationInviteStep(
                        id: UUID(),
                        officerId: officer,
                        bucket: bucket,
                        sequence: sequence,
                        reason: .rotation,
                        delayMinutes: 0
                    )
                )
                seen.insert(officer)
                sequence += 1
            }
        }

        let fallback = fallbackHelper.fallbackAction(for: posting.scenario, policy: policy)
        return RotationEngineResult(invitePlan: invites, fallback: fallback, delayBetweenInvites: 0)
    }
}
