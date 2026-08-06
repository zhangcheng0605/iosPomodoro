import Foundation

/// The Cabinet of Clocks: six ways of rendering the same sacred interval.
///
/// Every one of these is a **pure view over `engine.progress`**. `TimerEngine`
/// knows nothing about them and never will — a clock face cannot start, stop,
/// pause, or know anything the ring does not. That constraint is what makes
/// six faces cost one enum and a folder of sprites instead of six state
/// machines, and it is the reason the cabinet can grow later without anybody
/// having to think about the timer again.
///
/// Faces are **earned by counters the app already keeps**: nights, arrivals, a
/// finished constellation. Nothing new is recorded to unlock one, and nothing
/// is ever for sale. Locked faces are shown with a padlock rather than hidden,
/// per the app's rule — the single exception to that rule is Soot, and she is
/// not a clock.
enum ClockFace: String, CaseIterable, Identifiable, Codable {
    /// The one the app has always had, drawn in SwiftUI rather than sprites.
    case ring
    case sand
    case candle
    case water
    case incense
    case shadow

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ring: "The ring"
        case .sand: "Sand glass"
        case .candle: "Candle clock"
        case .water: "Water clock"
        case .incense: "Incense clock"
        case .shadow: "Shadow clock"
        }
    }

    /// One line about what it is, in the world's voice. None of these says
    /// how to unlock anything — that is the padlock's job, and a description
    /// that doubles as a quest is a description that has stopped describing.
    var blurb: String {
        switch self {
        case .ring: "The one you know."
        case .sand: "The oldest of them, and still the clearest."
        case .candle: "Marked in hours, and it does not give them back."
        case .water: "Harbor Isle keeps time this way."
        case .incense: "A coal, coming down a carved stick. The Onsen's own."
        case .shadow: "A gnomon, and the ground its shadow has crossed."
        }
    }

    /// Frames in the strip, matching `FRAMES` in `tools/generate_clocks.py`.
    /// The ring has none: it is drawn, not played.
    static let frames = 12

    var isDrawn: Bool { self == .ring }

    /// Which frame shows at a given progress.
    ///
    /// Clamped at both ends, and `progress` of exactly 1 lands on the last
    /// frame rather than one past it — which is the ordinary off-by-one here
    /// and would be an index crash on the chime, once per session, for
    /// everybody.
    func frame(at progress: Double) -> String {
        let clamped = min(max(progress, 0), 1)
        let index = min(Self.frames - 1, Int(clamped * Double(Self.frames)))
        return "clock_\(rawValue)_\(index)"
    }

    // MARK: What earns it

    /// What has to have happened. Every one of these is a counter the app was
    /// already keeping for its own reasons.
    enum Requirement: Equatable {
        case always
        case sessions(Int)
        case nights(Int)
        case reached(Place)
        case anyConstellation
    }

    var requirement: Requirement {
        switch self {
        case .ring: .always
        case .sand: .sessions(10)
        case .candle: .nights(20)
        case .water: .reached(.harbor)
        case .incense: .reached(.onsen)
        case .shadow: .anyConstellation
        }
    }

    /// The padlock's caption. Says what earns it and nothing else — no "only
    /// 4 to go", no progress, nothing that turns a face into a target.
    var lockedLine: String {
        switch requirement {
        case .always: ""
        case .sessions(let count): "After \(count) sessions."
        case .nights(let count): "After \(count) sessions finished after dark."
        case .reached(let place): "Somewhere out past \(place.name)."
        case .anyConstellation: "When a figure in the sky is finished."
        }
    }
}
