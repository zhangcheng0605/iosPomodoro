import Foundation
import Observation

/// Everything that happened, in the order it happened.
///
/// This file records and shows nothing. That is the point of it.
///
/// The app already stores plenty: the session log keeps every completed focus
/// session with its full `endedAt` date, so per-day counts, hour-of-day
/// histograms and night sessions can all be worked out backwards to somebody's
/// very first session, whenever the screen that wants them gets built. Those
/// need no help from here.
///
/// What is being lost, right now, every week, is the *episodic* half. The
/// journal keeps a first-seen and a last-seen per species — so "you have seen
/// a heron" survives forever, and "you saw a heron on Tuesday, in the rain,
/// at the harbour" is gone the moment you see the next one. The dream diary
/// works the same way. A weekly letter, a year ring with events pinned on the
/// rim, an anniversary that knows what it is the anniversary *of* — all of
/// them need the episodes, and none of them can be backfilled after the fact.
///
/// So this ships before the features that read it, empty, costing a few
/// kilobytes a year, and starts filling up. A month from now it will be worth
/// something. That is the whole design.
struct ChronicleEvent: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var at: Date
    var kind: Kind
    /// Which thing it was, in the vocabulary of whatever kind this is: a
    /// species id, a dream id, a place id, a bond level's raw value. Kept as
    /// a plain string so that retiring a species can never make an old
    /// chronicle undecodable.
    var subject: String

    enum Kind: String, Codable, CaseIterable {
        /// A species kept — you stayed to the end of the session.
        case sighting
        /// A dream kept.
        case dream
        /// Something heard and never seen.
        case heard
        /// Somewhere new reached.
        case arrival
        /// A bond level reached.
        case bond
        /// A constellation completed.
        case figure
        /// The stray moved a stage closer.
        case stray
        /// A found sound — reserved for Phase W, recorded from the day the
        /// first one is findable.
        case sound
        /// A session finished while the old snail was crossing. The subject is
        /// the place, because where you were standing is the whole of what
        /// there is to say about it.
        case snail
        /// Somebody moved into the homestead.
        case resident
        /// Something taken from the Magpie's Cart. The subject is a
        /// `CatalogItem.id`.
        case trade
        /// The first night a buddy actually slept in a new den. The subject is
        /// the den — deliberately a different event from the `.trade` that
        /// bought it, because buying a bed and going to sleep in it are two
        /// different days and only the second one is worth a sentence.
        case settledIn
        /// Something the buddy left on the desk.
        case keepsake
        /// A picture kept of where you were. The subject is the place the
        /// *world* was at the time, which is the joke the whole feature runs
        /// on: a photo of a kitchen table, filed under Harbor Isle.
        case snapshot
        /// A hundred hours of focus, and the panoramic card of the wood it
        /// grew. The subject is the number of hours, so a later milestone —
        /// if there is ever one, and there does not have to be — reuses the
        /// kind rather than needing another.
        case panorama
        /// An hour of the clock struck while you were sitting for it, written
        /// **only the first time** that hour is filled — so this kind can add
        /// at most twenty-five rows to the log in a lifetime, not one an hour.
        /// The subject is the hour as a number, or `"ring"` for the day the
        /// dial closed.
        ///
        /// Its own kind rather than borrowing `.heard`: that kind's subject is
        /// a `Heard` id and its one reader turns subjects back into `Heard`
        /// values, so an hour number in it would be a row that every consumer
        /// silently drops — a lie that reads perfectly well. The cost of the
        /// new case is two switch arms, both of which the checkers demand.
        case bell
        /// A mixtape you play your way into, rather than buying or travelling
        /// to. Two subjects share the kind, the way `.bell` shares one between
        /// an hour number and `"ring"`:
        ///
        /// - a `MusicFinding.rawValue` — one session that counted toward the
        ///   rainy-day tapes. Written **only while that tape is still
        ///   unfound**, so the kind is capped by the tape's own threshold at
        ///   five rows in a lifetime rather than one a session.
        /// - a `MusicFinding.foundSubject` (`"soot.found"`) — the day a tape
        ///   turned up, written once each. A note for the letter and the year
        ///   ring, never the authority: `TimerEngine.hasFound(_:)` reads the
        ///   world — the tally, the night counter, the stray — and never this.
        ///
        /// The rainy tally lives here rather than in a store of its own for
        /// the reason `hasFound(_ ambience:)` gives: the chronicle already
        /// survives a reinstall, is already cleared by `-PawmodoroResetState`,
        /// and is already merged across devices by union. A second place to
        /// keep "has this happened" is a second place for it to disagree.
        case tape
    }
}

/// The log itself: append-only, capped, and never shown to anybody yet.
@Observable
final class Chronicle {
    private(set) var events: [ChronicleEvent] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.chronicle

    /// Roughly a decade of enthusiastic use. Events are ~100 bytes encoded,
    /// so the ceiling is a few hundred kilobytes — but a ceiling there must
    /// be, because this is the one structure in the app designed to grow
    /// forever. Oldest go first.
    private static let limit = 4000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: Writing

    func add(_ kind: ChronicleEvent.Kind, _ subject: String, at date: Date = WorldCalendar.now) {
        events.append(ChronicleEvent(at: date, kind: kind, subject: subject))
        if events.count > Self.limit {
            events.removeFirst(events.count - Self.limit)
        }
        save()
    }

    // MARK: Reading
    //
    // Nothing in the app calls these yet. They exist so that the shape of the
    // log is settled now, while it is cheap to change, rather than being
    // designed around whatever the first reader happens to need.

    /// Everything since a moment, oldest first.
    func events(since: Date) -> [ChronicleEvent] {
        events.filter { $0.at >= since }
    }

    /// Everything on one calendar day.
    func events(on day: Date) -> [ChronicleEvent] {
        let start = WorldCalendar.startOfDay(day)
        guard let end = WorldCalendar.calendar.date(byAdding: .day, value: 1, to: start)
        else { return [] }
        return events.filter { $0.at >= start && $0.at < end }
    }

    /// The last seven days — the Sunday Post's raw material.
    func thisWeek(ending: Date = WorldCalendar.now) -> [ChronicleEvent] {
        guard let from = WorldCalendar.calendar.date(
            byAdding: .day, value: -7, to: WorldCalendar.startOfDay(ending)
        ) else { return [] }
        return events(since: from)
    }

    /// The first time something happened, which is what an anniversary is.
    func firstTime(_ kind: ChronicleEvent.Kind, subject: String) -> Date? {
        events.first { $0.kind == kind && $0.subject == subject }?.at
    }

    func count(of kind: ChronicleEvent.Kind) -> Int {
        events.count { $0.kind == kind }
    }

    /// How many times one particular thing has been written down.
    ///
    /// Only ever asked of kinds whose rows are capped by the thing that writes
    /// them — a count over an append-only log that drops its oldest at 4000
    /// would otherwise be a number that can go *down*, which is the one shape
    /// this app does not allow.
    func count(of kind: ChronicleEvent.Kind, subject: String) -> Int {
        events.count { $0.kind == kind && $0.subject == subject }
    }

    func clear() {
        events = []
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ChronicleEvent].self, from: data)
        else { return }
        events = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
