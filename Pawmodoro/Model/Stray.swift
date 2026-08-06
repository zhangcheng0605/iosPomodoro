import CoreGraphics
import Foundation
import Observation

/// The cat who decides, over about two weeks, that you are safe.
///
/// One day there are eyes in the hedge while you focus. Come back tomorrow and
/// she's on the fence. Keep showing up — not perfectly, just *actually* — and
/// eventually she walks up and joins your buddies, free.
///
/// This is how you befriend a real stray: repeated, calm, undemanding presence.
/// Which is also exactly what a focus practice is, so the mechanic *is* the
/// fiction and there is nothing to explain to the player.
///
/// Two rules keep it that way, and both are load-bearing:
///
/// - **Never a meter.** Her position is the progress. A percentage anywhere
///   would turn a relationship back into a chore, which is the one thing this
///   app doesn't do.
/// - **Never consecutive days.** Miss a week and she is still there, waiting
///   exactly where you left her. Nothing about her can be lost.
@Observable
final class Stray {

    /// Where her feet go, as a fraction of screen height.
    ///
    /// Her *feet*, not her middle: a sprite is positioned by its centre, so
    /// anchoring the centre puts a taller sprite's paws further down than a
    /// short one's. That is how an earlier version of this had her sitting in
    /// the Onsen's hot spring — she was fine at two stages and in the water at
    /// the third, purely because that sprite is bigger.
    ///
    /// One line for every stage and every place, because they are all standing
    /// on the same ground. This is the only value that is solid ground at both
    /// edges of all six places she visits, on a tall phone and a short one
    /// alike; `tools/check_stray.py` is what found it, and what will say so if
    /// a scene is ever redrawn underneath it.
    static let groundLine: Double = 0.79

    /// How far she has come. The raw values are the stage numbers used by
    /// `-PawmodoroStray`, so the debug flag reads the way the plan does.
    enum Stage: Int, Comparable, CaseIterable {
        /// Hasn't turned up yet — the habit is still forming.
        case away = 0
        /// Two eye-glints in the foreground shrubs, while a session runs.
        case eyes = 1
        /// A small dark shape at the edge of the scene. Spooks if touched.
        case edge = 2
        /// Mid-ground, sitting, watching. An occasional tail flick.
        case watching = 3
        /// Close enough to sit beside your buddy through a break.
        case beside = 4
        /// She's still here. Name her, and she's yours.
        case home = 5

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Qualifying days needed to reach this stage.
        var qualifyingDays: Int {
            switch self {
            case .away: 0
            case .eyes: 1
            case .edge: 3
            case .watching: 5
            case .beside: 8
            case .home: 12
            }
        }

        /// Which stage's sprite she is drawn as out in the scene.
        ///
        /// The arc is cumulative. Earning the stage where she'll sit beside
        /// your buddy on a break doesn't stop her watching from the grass while
        /// you focus — she got closer, she didn't get replaced.
        var scenePresence: Stage? {
            switch self {
            case .away: nil
            case .eyes, .edge, .watching: self
            case .beside, .home: .watching
            }
        }

        /// The sprite she is drawn as out in the scene. Only ever asked of the
        /// three stages `scenePresence` can return.
        var sceneFrames: [String]? {
            switch self {
            case .away, .beside, .home: nil
            case .eyes: ["stray_eyes"]
            case .edge: ["stray_distant"]
            case .watching: ["stray_watch_0", "stray_watch_1"]
            }
        }

        /// How far across the screen she is.
        ///
        /// She turns up on one side and is on the other next time — the "eyes
        /// in the hedge on Monday, on the fence on Tuesday" of it. Distance is
        /// carried by how big she is drawn and how long she stays, not by how
        /// high up the screen she sits: in this art style everything from the
        /// treeline down is the same ground, so height reads as nothing.
        ///
        /// Deliberately well outside 0.16...0.84, which is the ambience row and
        /// the transport controls. The margin has to cover the narrowest phone
        /// — on a 375pt screen the ambience row alone is 252pt wide, leaving
        /// very little either side of it.
        var x: Double {
            switch self {
            case .eyes: 0.105
            case .edge, .watching: 0.900
            case .away, .beside, .home: 0.5
            }
        }

        /// Where she is when it is raining.
        ///
        /// She comes in tight against the near side and waits it out — a cat
        /// in the rain is a cat under something, and the side she picks is the
        /// one she is not usually on. It costs no new position: both values
        /// are already in `x` above, and `check_stray.py` now cross-tests
        /// every stage at every column rather than each at its own, so the
        /// swap cannot put her on the open sea at Harbor.
        ///
        /// Nothing shrinks. Her dwell window *widens* in the wet, because she
        /// is there for the shelter rather than for you and leaving means
        /// getting wet. There is no weather that makes her come less.
        func x(in weather: Weather) -> Double {
            guard Self.shelters(from: weather) else { return x }
            switch self {
            case .eyes: 0.900
            case .edge, .watching: 0.105
            case .away, .beside, .home: 0.5
            }
        }

        /// Rain she would rather be out of. Mist and snow do not count: a cat
        /// in snow sits in the snow, and everybody has seen one do it.
        static func shelters(from weather: Weather) -> Bool {
            switch weather {
            case .drizzle, .rain, .storm: true
            case .clear, .overcast, .breeze, .mist, .golden, .snow: false
            }
        }

        /// The slice of a focus phase she is present for, in a given sky.
        func window(in weather: Weather) -> ClosedRange<Double> {
            guard Self.shelters(from: weather), self <= .watching else {
                return window
            }
            // Widened at the front only: she is already there when you sit
            // down, having arrived for the porch rather than for you.
            return max(0, window.lowerBound - 0.15)...window.upperBound
        }

        /// Must match the aspect the sprite is drawn at in
        /// tools/generate_sprites.py, or `scaledToFit` letterboxes her.
        var size: CGSize {
            switch self {
            case .eyes: CGSize(width: 20, height: 10)
            case .edge: CGSize(width: 26, height: 23)
            case .watching: CGSize(width: 44, height: 40)
            case .away, .beside, .home: .zero
            }
        }

        /// The slice of a focus phase she is present for, as fractions of
        /// progress. Dwell time is the other half of the trust arc: at first
        /// she looks in for a moment in the middle of a session, and by the
        /// time she's watching she stays for nearly all of it.
        var window: ClosedRange<Double> {
            switch self {
            case .eyes: 0.30...0.62
            case .edge: 0.20...0.80
            case .watching: 0.08...0.97
            case .away, .beside, .home: 0...1
            }
        }

        /// Whether she waits around between sessions. Until she is sitting and
        /// watching she is only ever there while you are actually focusing.
        var showsWhenIdle: Bool { self >= .watching }

        /// Whether touching her sends her away. She is still wild at the edge
        /// of the scene; by the time she is sitting and watching, a hand near
        /// her gets a tail flick instead, which is the trust made visible.
        var spooks: Bool { self == .edge }
    }

    /// The day she first showed up. The only thing about the arc that is
    /// stored — every stage after it is counted back out of the session log,
    /// so there is no progress number anywhere to corrupt or to display.
    private(set) var firstSeen: Date?

    /// The day she came inside, once the naming moment has happened. Separate
    /// from her name because accepting the default name stores nothing:
    /// `PomodoroSettings.setName` clears an override that equals the original,
    /// so "did she join?" cannot be read off `buddyNames`.
    private(set) var joined: Date?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        firstSeen = defaults.object(forKey: StorageKeys.strayFirstSeen) as? Date
        joined = defaults.object(forKey: StorageKeys.strayJoined) as? Date
    }

    // MARK: Reading

    var hasJoined: Bool { joined != nil }

    /// How many separate days have had a focus session on them since she first
    /// appeared, the day she appeared included.
    ///
    /// Counting distinct days cumulatively — rather than over a trailing
    /// window — is what makes the arc impossible to lose. It is also why the
    /// stage can never regress: the set of days that already happened only
    /// ever grows.
    func qualifyingDays(log: SessionLog) -> Int {
        guard let firstSeen else { return 0 }
        let start = calendar.startOfDay(for: firstSeen)
        let days = log.records
            .map { calendar.startOfDay(for: $0.endedAt) }
            .filter { $0 >= start }
        return Set(days).count
    }

    func stage(log: SessionLog) -> Stage {
        if let forced = LaunchOptions.forcedStrayStage {
            return Stage(rawValue: forced) ?? .away
        }
        guard firstSeen != nil else { return .away }
        let days = qualifyingDays(log: log)
        return Stage.allCases.last { days >= $0.qualifyingDays && $0 != .away } ?? .away
    }

    // MARK: Writing

    /// Focus-days needed in the trailing week before she turns up at all.
    ///
    /// She arrives *after* the habit exists rather than competing with forming
    /// one: a stray who appears on day one is a tutorial, and a stray who
    /// appears once you already come back is a reward.
    private static let noticeThreshold = 3
    private static let noticeWindow = 7

    /// Called when a focus session completes. Sets her start date the first
    /// time the trailing week is busy enough, and does nothing ever after.
    func noticeIfReady(log: SessionLog, on date: Date = Date()) {
        guard firstSeen == nil else { return }
        guard let cutoff = calendar.date(
            byAdding: .day, value: -(Self.noticeWindow - 1),
            to: calendar.startOfDay(for: date)
        ) else { return }

        let recentDays = Set(
            log.records
                .map { calendar.startOfDay(for: $0.endedAt) }
                .filter { $0 >= cutoff }
        )
        guard recentDays.count >= Self.noticeThreshold else { return }

        firstSeen = date
        defaults.set(date, forKey: StorageKeys.strayFirstSeen)
    }

    /// She comes inside. Free, and the only thing in the app earned purely by
    /// turning up rather than by paying or by finishing anything.
    func join(on date: Date = Date()) {
        guard joined == nil else { return }
        joined = date
        defaults.set(date, forKey: StorageKeys.strayJoined)
    }

    /// Debug only — puts her at a stage without waiting a fortnight for her.
    /// `-PawmodoroStray` needs a start date to exist so everything downstream
    /// behaves as it would in a real run.
    ///
    /// This writes, like `-PawmodoroSeedStats` does, so a later launch without
    /// the flag will still find her started. `-PawmodoroResetState` clears it.
    func seedForDebug(on date: Date = Date()) {
        guard LaunchOptions.forcedStrayStage != nil, firstSeen == nil else { return }
        firstSeen = date
        defaults.set(date, forKey: StorageKeys.strayFirstSeen)
    }
}
