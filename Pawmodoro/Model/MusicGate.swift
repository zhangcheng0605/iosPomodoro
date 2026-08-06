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
    /// Found, by having played a certain way. Not for sale at any price.
    case found(MusicFinding)

    var requiresPlus: Bool { self == .plus }
}

/// The three tapes that are earned by a *way of playing* rather than by paying
/// or by travelling.
///
/// `arrival` was already the generous gate — you get a mixtape for going
/// somewhere — but going somewhere is still a count of sessions, and Plus
/// short-circuits none of it only because the journey is the journey. These
/// three are the next step out: they cannot be bought, cannot be reached by
/// grinding a number, and each one is the record of a particular *kind* of
/// hour. Plus owners earn them on exactly the same terms as everybody else,
/// which is the rule `Ambience.isFound` set for sound and this keeps for music.
///
/// None of the three needs a store of its own. The rain tally is the only
/// thing the app did not already know, and it is kept where every other
/// "has this happened" is kept — the chronicle. See `TimerEngine.hasFound`.
enum MusicFinding: String, CaseIterable, Equatable, Hashable {
    /// Five sessions finished with rain in the room.
    case rainyday
    /// The after-dark counter the crickets and the star atlas already run on.
    case nightshift
    /// The stray's trust arc, completed. The one hidden story in the app, and
    /// the one ending you can hear.
    case soot

    /// How many qualifying sessions with rain running earn the tapes. Only the
    /// rainy tally is counted here; the other two ask the log and the stray,
    /// which have counted for years already.
    static let rainSessions = 5

    /// Sessions finished after dark before the night set turns up. Ten rather
    /// than the crickets' five, so the two finds are separate evenings —
    /// arriving together would make one of them invisible.
    static let nightSessions = 10

    /// What has to happen, in the app's own voice. Never a progress number:
    /// these say what *kind* of hour finds the tape, not how many are left.
    /// The stray's line is deliberately not a hint at all.
    var findingLine: String {
        switch self {
        case .rainyday: "Sit through the rain a few times, with it playing."
        case .nightshift: "Keep finishing sessions after dark."
        case .soot: "Hers. She will hand it over when she is ready."
        }
    }

    /// Whether the shelf shows it before it is found.
    ///
    /// Soot's tape is the app's second exception to "locked content is shown
    /// with a padlock, never hidden", and it is the same exception, for the
    /// same reason: she is not for sale, and a greyed-out row called *Soot's
    /// Tape* on day one tells somebody there is a cat coming. That is a
    /// two-week story spoiled to advertise nothing.
    var isHidden: Bool {
        switch self {
        case .rainyday, .nightshift: false
        case .soot: true
        }
    }

    /// The chronicle subject written once, the day the tape turns up.
    ///
    /// Distinct from `rawValue`, which is the subject of the rainy tally's
    /// progress rows — the same trick `.bell` uses for `"ring"`. It is a note
    /// for the letter and the year ring, never the authority: `hasFound` reads
    /// the world, not this.
    var foundSubject: String { "\(rawValue).found" }

    init?(foundSubject: String) {
        guard foundSubject.hasSuffix(".found") else { return nil }
        self.init(rawValue: String(foundSubject.dropLast(6)))
    }

    /// What the Sunday Post says the week it arrived.
    var postLine: String {
        switch self {
        case .rainyday:
            "There is a tape of wet-afternoon music in the studio now. "
                + "I do not know who left it there."
        case .nightshift:
            "Somebody made us a tape for the late hours. It suits them."
        case .soot:
            "The cat had a tape of her own the whole time, apparently."
        }
    }

    /// What the year ring writes on the rim for the day it arrived.
    var rimLabel: String {
        switch self {
        case .rainyday: "a tape for the rain"
        case .nightshift: "a tape for the small hours"
        case .soot: "the cat's own tape"
        }
    }

    /// Where the shelf puts it: after everywhere you can travel to, before
    /// anything with a price on it.
    var shelfOrder: Int {
        switch self {
        case .rainyday: 0
        case .nightshift: 1
        case .soot: 2
        }
    }
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
        // Distinct ranks rather than one shared number: `sorted(by:)` is not a
        // stable sort, so equal keys are free to swap places between runs and
        // a shelf that reorders itself on relaunch is the app moving your
        // furniture.
        case .found(let finding): 5_000 + finding.shelfOrder
        case .plus: 10_000
        }
    }
}
