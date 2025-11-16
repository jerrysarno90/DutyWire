import Foundation

enum OvertimeNotificationCenter {
    private enum Identifier {
        static func posting(_ id: String) -> String { "overtime.posting.\(id)" }
        static func deadline(_ id: String) -> String { "overtime.deadline.\(id)" }
        static func escalation(_ id: String) -> String { "overtime.escalation.\(id)" }
        static func forceAssignment(_ id: String) -> String { "overtime.force.\(id)" }
    }

    static func notifyPostingCreated(_ posting: RotationOvertimePostingDTO) async {
        await LocalNotify.requestAuthOnce()
        let body = "\(posting.title) starts \(posting.startsAt.formatted(date: .abbreviated, time: .shortened))."
        await LocalNotify.schedule(
            id: Identifier.posting(posting.id),
            title: "Overtime Posted",
            body: body,
            at: Date().addingTimeInterval(2)
        )
        await scheduleDeadlineReminderIfNeeded(posting: posting)
    }

    static func scheduleDeadlineReminderIfNeeded(posting: RotationOvertimePostingDTO) async {
        guard let deadline = posting.policySnapshot.responseDeadline else {
            LocalNotify.cancel(ids: [Identifier.deadline(posting.id)])
            return
        }
        LocalNotify.cancel(ids: [Identifier.deadline(posting.id)])
        let body = "\(posting.title) needs a decision before \(deadline.formatted(date: .omitted, time: .shortened))."
        await LocalNotify.schedule(
            id: Identifier.deadline(posting.id),
            title: "Overtime Response Deadline",
            body: body,
            at: deadline
        )
    }

    static func notifyEscalationNeeded(posting: RotationOvertimePostingDTO) async {
        await LocalNotify.schedule(
            id: Identifier.escalation(posting.id),
            title: "Escalate Overtime",
            body: "\(posting.title) is still open. Review and escalate.",
            at: Date().addingTimeInterval(2)
        )
        LocalNotify.cancel(ids: [Identifier.deadline(posting.id)])
    }

    static func cancelEscalationReminder(postingId: String) {
        LocalNotify.cancel(ids: [Identifier.escalation(postingId)])
    }

    static func notifyForceAssignment(posting: RotationOvertimePostingDTO, officer: OfficerAssignmentDTO) async {
        let name = officer.displayName
        let body = "\(name) assigned to \(posting.title)."
        await LocalNotify.schedule(
            id: Identifier.forceAssignment("\(posting.id).\(officer.badgeNumber)"),
            title: "Force Assignment Logged",
            body: body,
            at: Date().addingTimeInterval(2)
        )
    }
}
