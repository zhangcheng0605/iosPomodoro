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
