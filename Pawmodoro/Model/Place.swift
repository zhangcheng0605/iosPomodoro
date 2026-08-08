import Foundation

/// Somewhere the journey goes.
///
/// Deliberately not called `Scene` — SwiftUI already owns that name, and a
/// place is the better word anyway: these are destinations you arrive at, not
/// backdrops you pick.
///
/// The `id` matches the asset prefix emitted by `tools/generate_scenes.py`;
/// each place ships four images, one per time of day.
enum Place: String, Codable, CaseIterable, Identifiable, PlusLockable {
    // The Home Waters — the free route.
    case meadow
    case woods
    case harbor
    case blossom
    // The Far Isles — Pawmodoro Plus.
    case keep
    case cloudspire
    case peaks
    case onsen

    var id: String { rawValue }

    var name: String {
        switch self {
        case .meadow: "Meadow Home"
        case .woods: "Whispering Woods"
        case .harbor: "Harbor Isle"
        case .blossom: "Blossom Village"
        case .keep: "Sunstone Keep"
        case .cloudspire: "Cloudspire"
        case .peaks: "Starfall Peaks"
        case .onsen: "Moonlit Onsen"
        }
    }

    var blurb: String {
        switch self {
        case .meadow: "Where your buddy lives"
        case .woods: "Pines, a stream, and quiet"
        case .harbor: "Open water and a small tower"
        case .blossom: "Terraced flowers under a waterfall"
        case .keep: "White stone and teal domes"
        case .cloudspire: "An island that forgot to land"
        case .peaks: "Cold air and a long viaduct"
        case .onsen: "Steam, stone, and a warm soak"
        }
    }

    /// Completed focus sessions needed before this place opens up.
    ///
    /// Derived from `SessionLog.totalSessions` rather than stored, so there is
    /// no new state to persist, corrupt, or reset.
    var requiredSessions: Int {
        switch self {
        case .meadow: 0
        case .woods: 6
        case .harbor: 16
        case .blossom: 30
        case .keep: 45
        case .cloudspire: 65
        case .peaks: 90
        case .onsen: 120
        }
    }

    /// The Far Isles need Pawmodoro Plus *as well as* the sessions.
    var isPlus: Bool {
        switch self {
        case .meadow, .woods, .harbor, .blossom: false
        case .keep, .cloudspire, .peaks, .onsen: true
        }
    }

    /// Whether the stray turns up here.
    ///
    /// She walks, so she needs ground under her, and these two places have
    /// none where she sits: Harbor Isle is open water from the near edge to
    /// the horizon, and Cloudspire is an island that forgot to land and
    /// narrows to nothing well short of the screen edges. Rather than float a
    /// cat over either, she just doesn't follow you out there.
    ///
    /// Nothing is lost by it — her arc counts days you focused, not places she
    /// was seen in, so a fortnight at the Harbor still brings her all the way
    /// in. `tools/check_stray.py` is what found both.
    var strayVisits: Bool {
        switch self {
        case .harbor, .cloudspire: false
        default: true
        }
    }

    /// Where something standing in this place has a surface under its feet,
    /// as fractions of the *artwork* — across, then down.
    ///
    /// Six places are ground from edge to edge at the one line the app already
    /// agrees about, so they all say the same thing: the middle, at
    /// `Stray.groundLine`. The two that don't are the two `strayVisits`
    /// excludes, for exactly the reason written up there — and a postcard found
    /// it the hard way. The stray's answer was to stay away; a postcard cannot
    /// take that answer, because the card is *of* the place you reached and the
    /// buddy standing in it is what makes it a postcard rather than a
    /// screenshot. So instead of moving the creature out of the picture, this
    /// moves it onto the one thing in each of those two that has a top:
    ///
    ///   - **Harbor Isle** is open water down the whole centre column, at every
    ///     height, so no crop and no vertical nudge could ever have fixed it —
    ///     the island and its jetty sit right of centre. The jetty is the
    ///     surface, and it is the better picture anyway: a cat on a jetty.
    ///   - **Cloudspire** is a wedge of rock hanging in clear air. Its grassy
    ///     cap is the only top, and the buddy goes left of the spire, which is
    ///     the one thing on that card that may not be stood in front of — the
    ///     place is named after it.
    ///
    /// Measured against the artwork rather than the screen, which is what lets
    /// `tools/check_postcard.py` take these two numbers and go and look at the
    /// pixel underneath them in `generate_scenes.py`'s own grid. Hand-placing a
    /// sprite on a surface another tool draws is the mistake the residents and
    /// the stray both made; the answer both times was a checker.
    struct Footing: Equatable {
        /// Across the artwork: 0 at the left edge, 1 at the right.
        let x: Double
        /// Down the artwork — the line the soles rest on, not the sprite's
        /// middle, for the reason `Stray.groundLine` paid for.
        let y: Double
    }

    var footing: Footing {
        switch self {
        // The jetty: planks along scene row 210 of 286, running x 70-127.
        // Left of the isle's slope, so the lighthouse and both houses stay in
        // the picture behind the buddy.
        case .harbor: Footing(x: 0.62, y: 0.736)
        // The grassy cap, scene row 198, west of the spire. One row lower
        // than the cap's crown at that column, because the crown itself has a
        // four-pixel notch of sky in it between the tree and the near house,
        // and the buddy's left foot was over it.
        case .cloudspire: Footing(x: 0.36, y: 0.694)
        default: Footing(x: 0.5, y: Stray.groundLine)
        }
    }

    /// What crosses this place while a focus session runs, if anything.
    var vignette: Vignette? {
        switch self {
        case .harbor: .sailboat
        case .cloudspire: .balloon
        case .peaks: .train
        default: nil
        }
    }

    func assetName(for part: DayPart) -> String {
        "scene_\(rawValue)_\(part.rawValue)"
    }

    /// The places on the free route, in order — used by the picker and by the
    /// arrival check.
    static var journey: [Place] { allCases.sorted { $0.requiredSessions < $1.requiredSessions } }

    /// The furthest place reached with `sessions` completed, ignoring
    /// entitlement. Plus-gating is applied separately so a lapsed purchase
    /// never rewrites progress.
    static func lastReached(at sessions: Int) -> Place {
        journey.last { sessions >= $0.requiredSessions } ?? .meadow
    }
}

/// The little traveller whose position across a place *is* the countdown.
enum Vignette: String {
    case sailboat
    case balloon
    case train

    var assetName: String { "vignette_\(rawValue)" }

    /// Where it crosses, as a fraction of screen height.
    var altitude: Double {
        switch self {
        case .sailboat: 0.635
        case .balloon: 0.30
        case .train: 0.795
        }
    }

    var size: CGSize {
        switch self {
        case .sailboat: CGSize(width: 30, height: 30)
        case .balloon: CGSize(width: 26, height: 32)
        case .train: CGSize(width: 50, height: 25)
        }
    }
}
