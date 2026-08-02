import Foundation

/// A phase that ran out on its own, published by `TimerEngine` for the UI to
/// celebrate. Skipping or resetting a phase deliberately produces nothing:
/// there's no reward for abandoning a session.
struct PhaseCompletion: Identifiable, Equatable {
    let id = UUID()
    /// The phase that just ended, not the one starting next.
    let finished: TimerEngine.Phase
    let pawsEarned: Int
    let pawsPerCycle: Int
    /// True when the fourth focus session of a cycle just landed.
    let isCycleComplete: Bool
    /// Set when this session was the one that opened up somewhere new.
    var arrivedAt: Place?

    /// Only finishing focus earns confetti; breaks get a quieter beat, so the
    /// big moment stays rare enough to keep meaning something.
    var deservesConfetti: Bool { finished == .focus }

    /// Arriving somewhere is worth a card even mid-cycle.
    var showsCard: Bool { isCycleComplete || arrivedAt != nil }
}
