import Foundation
import Amplify

/// Many of the Amplify generated enums are used to drive picker UIs in the
/// app.  The generated code only conforms to `RawRepresentable`, so the UI
/// could not iterate over them directly.  These extensions add the
/// conveniences we rely on throughout the locker and squad features.

private protocol LockerEnum: CaseIterable, Identifiable, RawRepresentable where RawValue == String { }

extension NotificationCategory: LockerEnum {
    public static var allCases: [NotificationCategory] = [
        .overtimePosted,
        .overtimeReminder,
        .overtimeForceAssign,
        .squadAlert,
        .taskAlert,
        .bulletin,
    ]

    public var id: String { rawValue }
}

extension NotificationPlatform: LockerEnum {
    public static var allCases: [NotificationPlatform] = [.ios, .android]
    public var id: String { rawValue }
}

extension OvertimeScenario: LockerEnum {
    public static var allCases: [OvertimeScenario] = [
        .patrolShortShift,
        .sergeantShortShift,
        .specialEvent,
        .otherOvertime,
    ]

    public var id: String { rawValue }
}

extension OvertimeSelectionPolicy: LockerEnum {
    public static var allCases: [OvertimeSelectionPolicy] = [
        .rotation,
        .seniority,
        .firstCome,
    ]

    public var id: String { rawValue }
}

extension OvertimePostingState: LockerEnum {
    public static var allCases: [OvertimePostingState] = [
        .open,
        .filled,
        .closed,
    ]

    public var id: String { rawValue }
}

extension OvertimeInviteStatus: LockerEnum {
    public static var allCases: [OvertimeInviteStatus] = [
        .pending,
        .accepted,
        .declined,
        .ordered,
        .expired,
    ]

    public var id: String { rawValue }
}

extension SquadRole: LockerEnum {
    public static var allCases: [SquadRole] = [.supervisor, .officer]
    public var id: String { rawValue }
}
