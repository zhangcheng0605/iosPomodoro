import Foundation

/// A named length of crossing.
///
/// Three recipes on the dial rather than a preferences screen: most people
/// want one of these three and will never touch a stepper, and the ones who do
/// still have the dial. Naming them is the point — "Deep Dive" is a decision
/// you make about the afternoon, "50" is a number you type.
enum Expedition: String, CaseIterable, Identifiable {
    case sprint
    case classic
    case deepDive

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sprint: "Sprint"
        case .classic: "Classic"
        case .deepDive: "Deep Dive"
        }
    }

    var focusMinutes: Int {
        switch self {
        case .sprint: 15
        case .classic: 25
        case .deepDive: 50
        }
    }

    var shortBreakMinutes: Int {
        switch self {
        case .sprint: 3
        case .classic: 5
        case .deepDive: 10
        }
    }

    var longBreakMinutes: Int {
        switch self {
        case .sprint: 10
        case .classic: 15
        case .deepDive: 30
        }
    }

    var summary: String { "\(focusMinutes)/\(shortBreakMinutes)" }

    /// What the buddy says about the crossing you just chose. A preset nobody
    /// remarks on is a settings change; a preset the cat notices is a decision.
    var remark: String {
        switch self {
        case .sprint: "a quick hop, then"
        case .classic: "the usual crossing"
        case .deepDive: "a long crossing, then"
        }
    }

    func apply(to settings: inout PomodoroSettings) {
        settings.focusMinutes = focusMinutes
        settings.shortBreakMinutes = shortBreakMinutes
        settings.longBreakMinutes = longBreakMinutes
    }

    /// Which preset these settings currently *are*, if any. The dial still
    /// fine-tunes, and the moment it does no chip is selected — which is
    /// honest, and stops a chip claiming credit for 27 minutes.
    static func matching(_ settings: PomodoroSettings) -> Expedition? {
        allCases.first {
            $0.focusMinutes == settings.focusMinutes
                && $0.shortBreakMinutes == settings.shortBreakMinutes
                && $0.longBreakMinutes == settings.longBreakMinutes
        }
    }
}
