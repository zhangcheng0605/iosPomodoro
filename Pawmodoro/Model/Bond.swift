import Foundation

/// How well the two of you know each other.
///
/// A reason to come back tomorrow that isn't guilt: nothing is lost by not
/// showing up, the number only ever goes forwards, and it is never phrased as
/// a target. "Inseparable" is something you notice having become, not a goal
/// with a progress bar attached.
///
/// Derived from `SessionLog.totalSessions` rather than stored — the same trick
/// the journey unlocks and the star atlas use. There is no bond to corrupt,
/// migrate, or reset out of step with the history that earned it.
enum Bond: Int, CaseIterable, Comparable, Identifiable {
    case justMet = 0
    case acquainted = 1
    case friendly = 2
    case close = 3
    case devoted = 4
    case inseparable = 5

    var id: Int { rawValue }

    static func < (lhs: Bond, rhs: Bond) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Completed focus sessions this level begins at.
    var sessions: Int {
        switch self {
        case .justMet: 0
        case .acquainted: 10
        case .friendly: 30
        case .close: 75
        case .devoted: 150
        case .inseparable: 300
        }
    }

    var name: String {
        switch self {
        case .justMet: "Just met"
        case .acquainted: "Acquainted"
        case .friendly: "Friendly"
        case .close: "Close"
        case .devoted: "Devoted"
        case .inseparable: "Inseparable"
        }
    }

    /// What the level means, in the buddy's terms rather than the app's.
    func blurb(buddy: String) -> String {
        switch self {
        case .justMet: "\(buddy) is still working you out."
        case .acquainted: "\(buddy) knows your footsteps now."
        case .friendly: "\(buddy) settles the moment you sit down."
        case .close: "\(buddy) waits by the door before you've decided."
        case .devoted: "\(buddy) has picked a side of the desk."
        case .inseparable: "\(buddy) wouldn't go anywhere without you."
        }
    }

    /// Filled hearts out of five, for the meter.
    var hearts: Int { rawValue }

    static func level(at sessions: Int) -> Bond {
        allCases.last { sessions >= $0.sessions } ?? .justMet
    }

    /// Sessions still to go before the next level, or nil at the top. Shown as
    /// a quiet line rather than a bar: it is a thing to notice, not to chase.
    static func sessionsToNext(from sessions: Int) -> Int? {
        guard let next = allCases.first(where: { sessions < $0.sessions }) else { return nil }
        return next.sessions - sessions
    }

    /// The level a just-finished session has newly reached, if any.
    ///
    /// Both counts come from the log either side of the write, so this can
    /// only ever fire on the session that actually crossed the line.
    static func justReached(before: Int, after: Int) -> Bond? {
        let was = level(at: before)
        let now = level(at: after)
        return now > was ? now : nil
    }
}
