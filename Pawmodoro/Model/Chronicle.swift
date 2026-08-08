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
        /// A field-recording card finished — all four circadian grades of one
        /// ambience loop heard. The subject is the `Ambience.rawValue`.
        ///
        /// The *episodic* half only. The authority on which grades have been
        /// heard is `FieldNotes`, which has a key of its own for the reason
        /// `StorageKeys.clockRing` gives: this log is capped and drops its
        /// oldest rows, and a shelf of cards read back out of it would quietly
        /// empty again after a few years. What belongs here is the day a card
        /// was finished — which is what the weekly letter and the year ring
        /// want and what nothing else keeps.
        ///
        /// Capped by the thing that writes it at eighteen rows in a lifetime,
        /// one per loop, because a card can only be finished once.
        case recording
    }
}

/// The letters the seasons write, and the year, kept.
///
/// Stardew's Grandpa is remembered with love only because of the love —
/// the candles were judgment, and they die here. Spotify Wrapped is the
/// same loop annualized. So: when a real season ends, a letter arrives
/// recounting it — counts as memory, never as comparison, and a
/// near-empty season gets a shorter, warmer letter. And once a year, on
/// the anniversary of the first session ever, a small sequence of cards:
/// the year, kept. Presented whenever the year rolls past, so it cannot
/// be missed — nothing here knows how to be late.
struct SeasonLetter: Codable, Equatable, Identifiable {
    var id: String { "\(year).\(season)" }
    let season: String
    let year: Int
    let date: Date
    let text: String

    var title: String {
        Season(rawValue: season).map(\.name) ?? "A season"
    }
}

/// The world's memory, in two halves that answer to one name.
///
/// **The log** is append-only, capped, and the raw material: every episode as
/// it happened, with a date and a subject and no opinion about any of it.
///
/// **The almanac** is what gets read back out loud: the letter a season
/// leaves behind when it turns, and the year kept on the anniversary of the
/// very first session. Those are compositions over the *other* stores — the
/// session log, the journal, the mailbox, the photographs — rather than over
/// the events, which is why they are a separate half rather than a view onto
/// one. Neither half knows about the other; they share a class because
/// everything in the app already calls the thing that remembers `chronicle`,
/// and two objects with that name would only ever be confused for each other.
///
/// They do *not* share a defaults key. `StorageKeys.chronicle` holds a bare
/// `[ChronicleEvent]` array and nothing else, because `LaunchOptions`' debug
/// seeders decode it, append to it and write it straight back — a combined
/// blob there would make `-PawmodoroSeedChronicle` silently eat the letters.
@Observable
final class Chronicle {

    // MARK: The log

    private(set) var events: [ChronicleEvent] = []

    // MARK: The almanac

    private(set) var letters: [SeasonLetter] = []
    /// The just-composed letter, for the caption to announce once.
    private(set) var freshLetter: SeasonLetter?
    /// The anniversary sequence waiting to be shown: years together.
    private(set) var yearDue: Int?

    @ObservationIgnored private var lastSeenKey: String?
    @ObservationIgnored private var yearShown: Int?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    private static let storageKey = StorageKeys.chronicle

    /// The almanac half's own key, beside the log's rather than inside it.
    ///
    /// It is in `StorageKeys.all`, which is what stops `-PawmodoroResetState`
    /// leaving last autumn's letter sitting in a freshly reset world. It is
    /// also in `check_crossing.py`'s `NEEDS_NO_MERGE`, with the reason: the
    /// letters are a *reading* of stores that are merged, and the two markers
    /// beside them are this device's own place in that reading.
    private static let almanacKey = StorageKeys.chronicleAlmanac

    /// Roughly a decade of enthusiastic use. Events are ~100 bytes encoded,
    /// so the ceiling is a few hundred kilobytes — but a ceiling there must
    /// be, because this is the one structure in the app designed to grow
    /// forever. Oldest go first.
    private static let limit = 4000

    private static let keepLetters = 12

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = WorldCalendar.calendar
    ) {
        self.defaults = defaults
        self.calendar = calendar
        loadEvents()
        loadAlmanac()
    }

    // MARK: Writing

    func add(_ kind: ChronicleEvent.Kind, _ subject: String, at date: Date = WorldCalendar.now) {
        events.append(ChronicleEvent(at: date, kind: kind, subject: subject))
        if events.count > Self.limit {
            events.removeFirst(events.count - Self.limit)
        }
        saveEvents()
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

    /// Forget everything, both halves. The world has no way to ask for this;
    /// it exists so that a test or a reset has one door rather than two.
    func clear() {
        events = []
        letters = []
        freshLetter = nil
        yearDue = nil
        lastSeenKey = nil
        yearShown = nil
        saveEvents()
        saveAlmanac()
    }

    // MARK: The check, on launch and foregrounding

    func check(
        log: SessionLog, journal: Journal, travels: Travels,
        photos: PhotoAlbum, now: Date = WorldCalendar.now
    ) {
        let year = calendar.component(.year, from: now)
        let currentKey = Season.current().map { "\(year).\($0.rawValue)" } ?? "none"

        // A season we were inside last look, and aren't anymore: it turned.
        if let last = lastSeenKey, last != currentKey, last != "none" {
            let parts = last.split(separator: ".").map(String.init)
            if parts.count == 2, let lastYear = Int(parts[0]),
               let season = Season(rawValue: parts[1]),
               !letters.contains(where: { $0.id == last }) {
                let letter = SeasonLetter(
                    season: season.rawValue, year: lastYear, date: now,
                    text: Self.compose(
                        season: season, year: lastYear, log: log,
                        journal: journal, travels: travels, photos: photos,
                        calendar: calendar
                    )
                )
                letters.append(letter)
                if letters.count > Self.keepLetters {
                    letters.removeFirst(letters.count - Self.keepLetters)
                }
                freshLetter = letter
            }
        }
        lastSeenKey = currentKey

        // The anniversary: due from the day the year completes, standing
        // until seen. Never missable, never mentioned twice.
        if let first = log.firstSessionDate {
            let years = (calendar.dateComponents(
                [.day], from: first, to: now
            ).day ?? 0) / 365
            if years >= 1, yearShown ?? 0 < years {
                yearDue = years
            }
        }
        saveAlmanac()
    }

    func claimFreshLetter() -> SeasonLetter? {
        defer { freshLetter = nil }
        return freshLetter
    }

    func yearPresented() {
        yearShown = yearDue ?? yearShown
        yearDue = nil
        saveAlmanac()
    }

    // MARK: Composition

    /// The recounting. Counts appear as memory ("forty-one quiet hours"),
    /// never as comparison — no season is ever measured against another,
    /// and absence is structurally invisible.
    static func compose(
        season: Season, year: Int, log: SessionLog, journal: Journal,
        travels: Travels, photos: PhotoAlbum, calendar: Calendar
    ) -> String {
        guard let interval = Self.interval(of: season, year: year, calendar: calendar)
        else { return "A season came and went, the way they do." }

        let sessions = log.records.filter { interval.contains($0.endedAt) }
        let minutes = sessions.reduce(0) { $0 + $1.minutes }
        let hours = minutes / 60

        var lines: [String] = []
        if sessions.isEmpty {
            lines.append("A quiet \(season.name.lowercased()). "
                + "The garden waited with you, and the sill kept its view.")
            return lines.joined(separator: " ")
        }
        if hours >= 1 {
            lines.append("This \(season.name.lowercased()): "
                + "\(spell(hours)) quiet hour\(hours == 1 ? "" : "s"), kept.")
        } else {
            lines.append("This \(season.name.lowercased()): "
                + "a handful of quiet minutes, kept anyway.")
        }

        let met = journal.records.compactMap { key, record -> String? in
            guard interval.contains(record.firstSeen) else { return nil }
            return Species(rawValue: key)?.name.lowercased()
        }
        if let firstMet = met.first {
            lines.append(met.count == 1
                ? "You met the \(firstMet)."
                : "You met the \(firstMet), and \(met.count - 1) other"
                    + "\(met.count == 2 ? "" : "s") besides.")
        }

        let nights = log.nightRecords.filter { interval.contains($0.endedAt) }.count
        if nights > 0 {
            lines.append("\(spell(nights).capitalized) star"
                + "\(nights == 1 ? "" : "s") went up after dark.")
        }

        let arrived = travels.mailbox.filter { interval.contains($0.date) }.count
        if arrived > 0 {
            lines.append("\(spell(arrived).capitalized) letter"
                + "\(arrived == 1 ? "" : "s") came home.")
        }

        let shots = photos.photos.filter { interval.contains($0.date) }.count
        if shots > 0 {
            lines.append("The camera kept \(spell(shots)) morning"
                + "\(shots == 1 ? "" : "s")' worth of light.")
        }

        lines.append("Noted, all of it. — the almanac")
        return lines.joined(separator: " ")
    }

    /// The season's real dates in a given year.
    static func interval(
        of season: Season, year: Int, calendar: Calendar
    ) -> ClosedRange<Date>? {
        let window = season.window
        var fromParts = DateComponents()
        fromParts.year = year
        fromParts.month = window.from.month
        fromParts.day = window.from.day
        var toParts = DateComponents()
        toParts.year = year
        toParts.month = window.to.month
        toParts.day = window.to.day
        toParts.hour = 23
        toParts.minute = 59
        guard let from = calendar.date(from: fromParts),
              let to = calendar.date(from: toParts), from <= to
        else { return nil }
        return from...to
    }

    private static func spell(_ n: Int) -> String {
        let words = [
            "zero", "one", "two", "three", "four", "five", "six", "seven",
            "eight", "nine", "ten", "eleven", "twelve",
        ]
        return n < words.count ? words[n] : "\(n)"
    }

    // MARK: Debug

    /// `-PawmodoroSeasonLetter <season>` — compose it now.
    func composeForDebug(
        season: Season, log: SessionLog, journal: Journal,
        travels: Travels, photos: PhotoAlbum, now: Date = WorldCalendar.now
    ) {
        let year = calendar.component(.year, from: now)
        let letter = SeasonLetter(
            season: season.rawValue, year: year, date: now,
            text: Self.compose(
                season: season, year: year, log: log, journal: journal,
                travels: travels, photos: photos, calendar: calendar
            )
        )
        // Replaced where it stands rather than removed and re-appended.
        // A debug reseed is the one path in this class that can write a
        // season twice, and dropping the old row to push the new one on the
        // end is a store getting smaller — which is the shape
        // `check_crossing.py` walks this file looking for, and it cannot
        // tell a debug flag's shrink from a decaying feature's.
        if let index = letters.firstIndex(where: { $0.id == letter.id }) {
            letters[index] = letter
        } else {
            letters.append(letter)
        }
        freshLetter = letter
        saveAlmanac()
    }

    /// `-PawmodoroYearCard` — the sequence, now.
    func forceYearForDebug() {
        yearDue = max(1, (yearShown ?? 0) + 1)
    }

    // MARK: Persistence

    /// The log is stored as a bare array under `StorageKeys.chronicle` and
    /// must stay that way: `LaunchOptions.seedChronicleEvents` and
    /// `seedFoundTapes` both decode `[ChronicleEvent]` from that key, append,
    /// and write it back. Wrapping it in anything would leave those flags
    /// quietly seeding nothing.
    private func loadEvents() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ChronicleEvent].self, from: data)
        else { return }
        events = decoded
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct AlmanacState: Codable {
        var letters: [SeasonLetter]
        var lastSeenKey: String?
        var yearShown: Int?
    }

    private func loadAlmanac() {
        guard let data = defaults.data(forKey: Self.almanacKey),
              let state = try? JSONDecoder().decode(AlmanacState.self, from: data)
        else { return }
        letters = state.letters
        lastSeenKey = state.lastSeenKey
        yearShown = state.yearShown
    }

    private func saveAlmanac() {
        let state = AlmanacState(
            letters: letters, lastSeenKey: lastSeenKey, yearShown: yearShown
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.almanacKey)
    }
}
