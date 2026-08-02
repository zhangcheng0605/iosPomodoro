import Foundation

/// How a track or a mixtape is earned.
///
/// The interesting case is `arrival`. Most of the free catalogue isn't given
/// away on day one — it's handed over as you travel, one mixtape per place on
/// the Home Waters route. It needs no new persistence: the thresholds are the
/// journey's own, so `TimerEngine.hasReached(_:)` already answers the question.
enum MusicGate: Equatable, Hashable {
    /// Yours from the first launch.
    case free
    /// Yours once you've reached this place — no purchase involved.
    case arrival(Place)
    /// Pawmodoro Plus.
    case plus

    var requiresPlus: Bool { self == .plus }
}

/// A mixtape: five tracks and a reason to have them.
struct MusicCollection: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let gate: MusicGate

    var tracks: [MusicTrack] { MusicCatalog.tracks(in: id) }
}

extension MusicCatalog {
    /// Every collection in the order the shelf shows them: free first, then
    /// the journey in travel order, then the Plus sets.
    static var shelf: [MusicCollection] {
        collections.sorted { left, right in
            rank(left.gate) < rank(right.gate)
        }
    }

    private static func rank(_ gate: MusicGate) -> Int {
        switch gate {
        case .free: 0
        case .arrival(let place): 1 + place.requiredSessions
        case .plus: 10_000
        }
    }
}
