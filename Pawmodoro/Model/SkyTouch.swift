import CoreGraphics
import Foundation
import Observation

/// Where the sky's things actually are.
///
/// One opinion, for the same reason `WorldCalendar` is one opinion about
/// today: the layer that *draws* the moon and the layer that *listens* for a
/// finger on it are different views, and a moon drawn at 0.86 of the width but
/// hit-tested at 0.84 is a bug nobody can see — it just feels like the app
/// ignoring you. Everything positional that both layers need lives here and
/// nowhere else.
enum SkyGeometry {

    // MARK: The moon

    /// The moon's centre. In the sky band's top-right, in the slot between The
    /// Ferry and The Whale — a full atlas grazes it at the edges and no more.
    static func moonCenter(in size: CGSize) -> CGPoint {
        let band = ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop
        return CGPoint(
            x: 0.86 * size.width,
            y: (ConstellationAtlas.skyTop + 0.42 * band) * size.height
        )
    }

    static func moonRadius(in size: CGSize) -> Double {
        min(size.width, size.height) * 0.055
    }

    /// How close a finger has to land to count as touching the moon.
    ///
    /// Generous — the disc itself is about eighteen points across on a phone,
    /// which is half of Apple's minimum target. A moon you have to hit
    /// precisely is a moon nobody discovers answers at all.
    static func moonTouchRadius(in size: CGSize) -> Double {
        max(moonRadius(in: size) * 2.1, 26)
    }

    // MARK: The stars

    /// Sky-band space (0...1 on both axes) to a point on screen.
    static func point(_ position: CGPoint, in size: CGSize) -> CGPoint {
        let band = ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop
        return CGPoint(
            x: position.x * size.width,
            y: (ConstellationAtlas.skyTop + position.y * band) * size.height
        )
    }

    static func star(_ figure: Constellation, _ index: Int, in size: CGSize) -> CGPoint {
        point(figure.position(of: index), in: size)
    }

    /// How close a finger has to land to count as touching a star.
    ///
    /// Fixed points rather than a fraction of the screen: a fingertip is the
    /// same size on an SE as on a Pro Max, and the figures are laid out in
    /// fractions, so the *gaps* shrink on a small phone but the finger does
    /// not. 24 keeps every neighbouring pair in all seven figures separable on
    /// the narrowest screen the app supports.
    static let starTouchRadius = 24.0

    /// The background scatter — the stars that were always here.
    ///
    /// Lives here rather than in `StarfieldView` because the new moon's answer
    /// brightens exactly these, and it is drawn by a different view: two
    /// copies of this arithmetic would put the swell next to the stars instead
    /// of on them.
    static let scatterCount = 12

    static func scatter(in size: CGSize) -> [CGPoint] {
        (0..<scatterCount).map { index in
            let n = Double(index)
            return CGPoint(
                x: ((n * 0.6180339887).truncatingRemainder(dividingBy: 1)) * size.width,
                // Kept to the upper third: that's the part of the screen that
                // reads as sky, and the only part with no text over it.
                y: ((n * 0.7548776662).truncatingRemainder(dividingBy: 1))
                    * size.height * 0.34
            )
        }
    }

    /// One loose star per five nights once the atlas is full.
    static func wanderers(count: Int, in size: CGSize) -> [CGPoint] {
        (0..<max(0, count)).map { index in
            let n = Double(index) + 0.5
            let band = ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop
            return CGPoint(
                x: ((n * 0.3819660113).truncatingRemainder(dividingBy: 1)) * size.width,
                y: (ConstellationAtlas.skyTop
                    + ((n * 0.2360679775).truncatingRemainder(dividingBy: 1)) * band)
                    * size.height
            )
        }
    }
}

/// One join between two stars of one figure.
///
/// Normalised on the way in, so the same join drawn right-to-left is the same
/// join. That is the whole reason this is a type rather than a pair of `Int`s:
/// a set keyed on unordered pairs would otherwise hold both, and a figure you
/// had joined completely could report itself unfinished forever.
struct SkyLink: Hashable {
    let figure: String
    let a: Int
    let b: Int

    init(figure: String, _ first: Int, _ second: Int) {
        self.figure = figure
        self.a = min(first, second)
        self.b = max(first, second)
    }

    /// What goes in storage. Human-readable on purpose — a defaults dump that
    /// says `littlepaw.0-4` can be read by whoever is holding the phone.
    var key: String { "\(figure).\(a)-\(b)" }
}

/// The joins you have drawn between stars with a finger, kept forever.
///
/// **The atlas is still earned by nights, and this cannot hurry it.** One star
/// goes up per focus session finished after dark and that is untouched: this
/// is not a second way to fill the sky, it is the only way to *join* it. What
/// a finger buys is seeing the figure — and being told its name — one or two
/// nights before the last star lands, on the strength of having recognised it
/// yourself.
///
/// A link may only be drawn once at least one of its two stars is lit, so the
/// earliest a figure can be found by hand is a night or two before it finishes
/// on its own. There is no arrangement of taps that reaches a figure you have
/// not been most of the way to already.
///
/// Monotonic, like everything else in this app: joins are added and never
/// removed, so merging two devices' skies is `union` and nothing else.
@Observable
final class SkyTouches {
    /// A singleton for the same reason `TouchTracker` is one: the layer that
    /// draws the sky and the layer that listens to it are siblings in
    /// `ContentView`'s stack and neither owns the other.
    static let shared = SkyTouches()

    /// Joins drawn, as `SkyLink.key`.
    private(set) var joins: Set<String> = []

    /// Which moons have been asked, as `MoonPhase.name` values. A set, so
    /// asking the same moon twice is the same as asking it once — see the
    /// merge rule.
    private(set) var moonsAsked: Set<String> = []

    @ObservationIgnored private let defaults: UserDefaults

    private static let storageKey = StorageKeys.skyTouches

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: Asking

    func hasJoined(_ link: SkyLink) -> Bool { joins.contains(link.key) }

    var hasJoinedAnything: Bool { !joins.isEmpty }

    var hasAskedTheMoon: Bool { !moonsAsked.isEmpty }

    /// Whether this pair may be joined yet.
    ///
    /// True when the pair really is one of the figure's links and at least one
    /// of its ends is lit. One end rather than both: The Little Paw's four
    /// links all meet at its pad, which is its *last* star — requiring both
    /// would leave the first figure anybody builds with nothing to draw until
    /// the night it finished on its own, which is to say with nothing to draw.
    static func isReachable(
        _ link: SkyLink, figureIndex: Int, nightSessions: Int
    ) -> Bool {
        guard ConstellationAtlas.all.indices.contains(figureIndex) else { return false }
        let figure = ConstellationAtlas.all[figureIndex]
        guard figure.id == link.figure else { return false }
        guard figure.links.contains(where: { SkyLink(figure: figure.id, $0.0, $0.1) == link })
        else { return false }
        let lit = ConstellationAtlas.litStars(of: figureIndex, nightSessions: nightSessions)
        return link.a < lit || link.b < lit
    }

    /// Every link of this figure that could be drawn tonight.
    static func reachableLinks(
        of figureIndex: Int, nightSessions: Int
    ) -> [SkyLink] {
        guard ConstellationAtlas.all.indices.contains(figureIndex) else { return [] }
        let figure = ConstellationAtlas.all[figureIndex]
        return figure.links
            .map { SkyLink(figure: figure.id, $0.0, $0.1) }
            .filter { isReachable($0, figureIndex: figureIndex, nightSessions: nightSessions) }
    }

    /// A figure is *found* once every one of its links has been drawn by hand.
    ///
    /// Derived rather than stored: the joins only ever grow, so this only ever
    /// turns on, and there is no second flag that could disagree with the set
    /// it was computed from.
    func hasFound(_ figure: Constellation) -> Bool {
        figure.links.allSatisfy {
            joins.contains(SkyLink(figure: figure.id, $0.0, $0.1).key)
        }
    }

    /// The joins drawn on this figure, as index pairs, for drawing.
    func drawnLinks(of figure: Constellation) -> [(Int, Int)] {
        figure.links.filter {
            joins.contains(SkyLink(figure: figure.id, $0.0, $0.1).key)
        }
    }

    /// Every figure found by hand, oldest first. The atlas asks this to know
    /// which of its unfinished rows already has a name.
    func foundFigures() -> [Constellation] {
        ConstellationAtlas.all.filter(hasFound)
    }

    // MARK: Writing

    /// Draws one join. Returns true only the first time — the caller uses that
    /// to decide whether to congratulate, so a second stroke over a line you
    /// already have is silent rather than repeatedly celebratory.
    @discardableResult
    func join(_ link: SkyLink) -> Bool {
        guard !joins.contains(link.key) else { return false }
        joins.insert(link.key)
        save()
        return true
    }

    /// Records that tonight's moon was asked. Returns true the first time this
    /// *phase* has ever been asked, which is what makes the diary's line about
    /// it possible without storing a second thing.
    @discardableResult
    func askMoon(named phase: String) -> Bool {
        guard !moonsAsked.contains(phase) else { return false }
        moonsAsked.insert(phase)
        save()
        return true
    }

    /// Debug only. Draws every link that could be drawn tonight, in the
    /// figures given — the honest route is a finger and a fortnight.
    func joinForDebug(figures: Range<Int>, nightSessions: Int) {
        for index in figures where ConstellationAtlas.all.indices.contains(index) {
            for link in Self.reachableLinks(of: index, nightSessions: nightSessions) {
                joins.insert(link.key)
            }
        }
        save()
    }

    // MARK: Storage

    private struct Stored: Codable {
        var joins: [String]
        var moonsAsked: [String]
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(Stored.self, from: data)
        else { return }
        joins = Set(decoded.joins)
        moonsAsked = Set(decoded.moonsAsked)
    }

    private func save() {
        let stored = Stored(joins: joins.sorted(), moonsAsked: moonsAsked.sorted())
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// What the moon does when you ask it.
///
/// Every moon answers — an app that ignores three weeks in four would teach
/// people to stop touching it — but they do not answer the same. The full moon
/// is the only one with a rabbit on it, and the new moon is the only one that
/// can give the sky back, because it is the only one with no light of its own
/// to be in the way. Between them the moon just says what it is called, which
/// is the almanac's own sentence, arriving where you are looking.
enum MoonAnswer: Equatable {
    /// Full: the shadow on the disc turns out to be somebody.
    case rabbit
    /// New: no moon to speak of, and every other star the brighter for it.
    case starsGiven
    /// Anything between: light runs along the lit limb and it names itself.
    case limb

    static func tonight(on date: Date = WorldCalendar.now) -> MoonAnswer {
        if MoonPhase.isFull(on: date) { return .rabbit }
        if MoonPhase.isNew(on: date) { return .starsGiven }
        return .limb
    }

    /// The line under the moon. Never congratulates, never instructs — the
    /// Sunday Post's voice rules are the house voice, and this is the app
    /// speaking to the reader too.
    func caption(on date: Date = WorldCalendar.now) -> String {
        switch self {
        case .rabbit: "\(MoonPhase.name(on: date)) — somebody is up there"
        case .starsGiven: "\(MoonPhase.name(on: date)) — the stars have it all tonight"
        case .limb: MoonPhase.name(on: date)
        }
    }

    /// What VoiceOver hears. Longer than the caption on purpose: the caption
    /// is read beside a picture of a moon, and this is read instead of one.
    func spoken(on date: Date = WorldCalendar.now) -> String {
        switch self {
        case .rabbit:
            "\(MoonPhase.name(on: date)). There is a rabbit-shaped shadow on it."
        case .starsGiven:
            "\(MoonPhase.name(on: date)). No moon to speak of, and every star brighter for it."
        case .limb:
            "\(MoonPhase.name(on: date)). Light runs along the lit edge and settles."
        }
    }
}
