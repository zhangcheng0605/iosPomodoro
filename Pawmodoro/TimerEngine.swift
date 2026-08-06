import Foundation
import Observation

/// The Pomodoro state machine.
///
/// Remaining time is always derived from an absolute end `Date`, never from
/// accumulated ticks: iOS suspends backgrounded apps, so a tick-based countdown
/// drifts or stalls entirely. `syncAfterWake()` recomputes on foreground and
/// finishes the phase if it elapsed while the app was away.
@Observable
final class TimerEngine {

    enum Phase: String, Codable, CaseIterable {
        case focus
        case shortBreak
        case longBreak

        var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }

        var isBreak: Bool {
            switch self {
            case .focus: false
            case .shortBreak, .longBreak: true
            }
        }
    }

    enum RunState {
        case idle      // nothing started, or a phase just finished
        case running
        case paused
    }

    var settings: PomodoroSettings
    private(set) var phase: Phase = .focus
    private(set) var runState: RunState = .idle
    private(set) var remaining: TimeInterval
    /// Focus sessions finished inside the current cycle, reset after a long break.
    private(set) var focusInCycle: Int = 0

    /// Set when a phase runs out on its own, and left set until something
    /// clears it. The engine stays free of any UI: views watch this and put on
    /// whatever celebration they like.
    var completion: PhaseCompletion?

    /// The wildlife appearance scheduled for this focus phase, if the roll went
    /// that way. Cleared whenever the phase stops for any reason.
    private(set) var sighting: Sighting?

    /// Whether Soot is doing her rounds this phase.
    ///
    /// Her one quirk, and the only one that shows while somebody else is the
    /// buddy: a cat who spent a fortnight deciding to come in doesn't stop
    /// being a cat afterwards. Rolled once per phase for the same reason a
    /// sighting is — a per-frame decision would have her flicker.
    private(set) var strayCameo = false

    /// What the buddy is dreaming this focus phase, if the roll went that way.
    /// A session gets a dream *or* a sighting, never both competing for the
    /// same quiet middle stretch.
    private(set) var dream: Dream?

    /// The moment you cast off, or nil if this is an ordinary countdown.
    ///
    /// One `Date` is the whole of the Drift's state. Elapsed, laps, the ring
    /// and what gets banked are all functions of it and the wall clock — see
    /// `Drift`. Nothing here counts ticks, for the same reason the countdown
    /// doesn't: iOS suspends backgrounded apps.
    private(set) var driftStart: Date?

    /// Set when a drift comes back from the dead — the app was away long
    /// enough that counting it silently would be a lie. The view asks; the
    /// engine waits. It is the only question the Drift ever puts to anybody.
    var driftNeedsAsking = false

    /// Who moved into the homestead on the session just finished.
    ///
    /// The whole announcement. A resident gets no card, no confetti and no
    /// notification — the buddy's caption mentions it through the break that
    /// follows, and then the caption goes back to normal and the thing is
    /// simply part of the garden. Deliberately not persisted: if you were
    /// away when it landed you find the pond yourself, which is a better way
    /// to find a pond than being told about one.
    private(set) var residentArrived: Resident?

    /// The hello the buddy owes today, or nil once it has been said.
    ///
    /// Set at most once a day, cleared by whoever showed it. Not persisted
    /// beyond `GreetingLog`'s single date: a greeting half-shown when the app
    /// was killed is a greeting that simply happens again, which is the right
    /// failure for a hello.
    private(set) var greeting: Greeting.Warmth?

    /// Say hello, if today has not had one.
    ///
    /// Called on launch and on every foreground — both, because the common
    /// case is an app that was never actually killed, only backgrounded
    /// overnight, and a greeting that only fired on a cold launch would be
    /// missed by exactly the people who use the app every day.
    ///
    /// Never during a running phase. Interrupting a focus session to say good
    /// morning would be the app talking over the thing it exists to protect.
    func greetIfOwed() {
        guard runState == .idle else { return }
        if LaunchOptions.forceGreeting {
            greeting = LaunchOptions.forcedGreeting ?? .daily
            return
        }
        guard greetings.isOwed() else { return }
        greeting = Greeting.for(daysAway: daysSinceLastSession,
                                hasSat: !log.records.isEmpty)
        greetings.noteGreeted()
    }

    func endGreeting() { greeting = nil }

    /// Whole days since the last completed session, through `WorldCalendar` so
    /// `-PawmodoroDate` moves it with everything else.
    private var daysSinceLastSession: Int {
        guard let last = log.records.map(\.endedAt).max() else { return 0 }
        return max(0, WorldCalendar.days(from: WorldCalendar.startOfDay(last),
                                         to: WorldCalendar.today))
    }

    /// Set for one caption's worth of time when something is worn for the
    /// first time ever.
    ///
    /// Not persisted and not per-buddy-per-slot: it is a remark, not a record.
    /// `firstWorn` below is the record, and it is what stops the same line
    /// being said twice about the same hat.
    private(set) var justWore: Accessory?

    /// Accessories that have been worn at least once, so the caption fires
    /// exactly once each. Lives in `Pouch` rather than here because it must
    /// survive a relaunch — a hat you put on last week is not news.
    func wear(_ accessory: Accessory?, in slot: Accessory.Slot) {
        settings.wear(accessory, on: settings.buddy, in: slot)
        settingsDidChange()
        guard let accessory, !pouch.hasWorn(accessory) else {
            justWore = nil
            return
        }
        pouch.noteWorn(accessory)
        justWore = accessory
    }

    let log: SessionLog
    let journal: Journal
    let album: Album
    let stray: Stray
    let dreams: DreamDiary
    /// Written to, never read from — yet. See `Chronicle`.
    let chronicle: Chronicle
    /// Which hours of the clock you have been sitting for. See `ClockRing`.
    let clockRing: ClockRing
    /// What has been traded for. The balance is not in here — see `Acorns`.
    let pouch: Pouch
    /// What the buddy has left on the desk.
    let shelf: Shelf
    /// Photographs of where you actually were.
    let scrapbook: Scrapbook
    /// One date: the last day the buddy said hello.
    @ObservationIgnored let greetings = GreetingLog()

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    /// Which whole second the closing heartbeat last fired on.
    @ObservationIgnored private var lastHeartbeatSecond: Int?
    /// Seconds of this phase spent with rain playing — the rainbow's condition.
    @ObservationIgnored private var rainSeconds: TimeInterval = 0
    /// Which lap the drift last rolled a sighting for, so each lap rolls once.
    @ObservationIgnored private var lastLapRolled = 0
    /// The top of the hour the bell last dealt with — rung or missed. Nil
    /// until the first tick of the first phase, which is what stops a session
    /// started at 9:00:02 from claiming the nine o'clock strike.
    @ObservationIgnored private var lastStruckHour: Date?
    /// When this engine was built, which is when the app launched. Debug only,
    /// and only `-PawmodoroBell` reads it.
    @ObservationIgnored private let bornAt = Date()
    @ObservationIgnored private var firedDebugBell = false

    init(
        settings: PomodoroSettings? = nil,
        log: SessionLog = SessionLog(),
        journal: Journal = Journal(),
        album: Album = Album(),
        stray: Stray = Stray(),
        dreams: DreamDiary = DreamDiary(),
        chronicle: Chronicle = Chronicle(),
        clockRing: ClockRing = ClockRing(),
        pouch: Pouch = Pouch(),
        shelf: Shelf = Shelf(),
        scrapbook: Scrapbook = Scrapbook()
    ) {
        let resolved = settings ?? PomodoroSettings.load()
        self.settings = resolved
        self.log = log
        self.journal = journal
        self.album = album
        self.stray = stray
        self.dreams = dreams
        self.chronicle = chronicle
        self.clockRing = clockRing
        self.pouch = pouch
        self.shelf = shelf
        self.scrapbook = scrapbook
        self.remaining = resolved.duration(for: .focus)
        ThemeManager.shared.theme = resolved.theme
        HapticsDirector.shared.isEnabled = resolved.hapticsEnabled
        if let forced = LaunchOptions.forcedPlace {
            self.settings.place = forced
        }
        if let forced = LaunchOptions.forcedBuddy {
            self.settings.buddy = forced
        }
        if let forced = LaunchOptions.forcedTheme {
            self.settings.theme = forced
            ThemeManager.shared.theme = forced
        }
        if LaunchOptions.fillJournal {
            journal.fillForDebug(count: LaunchOptions.fillJournalCount)
        }
        if LaunchOptions.fillDreams {
            dreams.fillForDebug()
        }
        stray.seedForDebug()
        if let forced = LaunchOptions.forcedTrack, MusicCatalog.track(id: forced) != nil {
            self.settings.music = forced
        }
        // A den belongs to a species, so showing one means being that buddy.
        if let den = LaunchOptions.forcedDen {
            self.settings.buddy = den.buddy
        }
        // A file left behind by a crash between writing the JPEG and saving
        // its row is storage nobody can reach. One directory listing.
        scrapbook.prune()
        // `SnapshotSeed` is compiled out of Release entirely, so the call
        // has to be too — `seedScrapbook` being a `false` constant there
        // stops the branch running, not the symbol being looked up.
        #if DEBUG
        if LaunchOptions.seedScrapbook { SnapshotSeed.fill(scrapbook) }
        #endif
        for accessory in LaunchOptions.forcedWear {
            self.settings.wear(accessory, on: self.settings.buddy, in: accessory.slot)
        }
    }

    /// `-PawmodoroDrift` and `-PawmodoroLaps`, applied once the engine exists.
    ///
    /// Backdates the cast-off rather than fast-forwarding anything: the whole
    /// feature is a function of one `Date`, so moving that `Date` reaches the
    /// same state the honest two hours reach, and every derived number — laps,
    /// ring, banking, the six-hour question — agrees without being told.
    func applyDebugDrift() {
        guard LaunchOptions.drift || LaunchOptions.driftLaps != nil else { return }
        castOff()
        if let laps = LaunchOptions.driftLaps {
            driftStart = Date().addingTimeInterval(-Double(laps) * lapSeconds - 1)
            lastLapRolled = laps
        }
    }

    // MARK: Derived values

    var phaseDuration: TimeInterval { settings.duration(for: phase) }

    /// 0 at the start of a phase, 1 when it completes.
    ///
    /// While drifting this is the progress round the *current lap* instead.
    /// That one substitution is what lets the whole scenery layer carry over
    /// untouched: the sighting's appearance window, the dream's 0.40–0.70
    /// slice and the vignette's position were already pure functions of
    /// `progress`, and none of them needs to know the ring changed direction.
    var progress: Double {
        if isDrifting {
            return Drift.lapProgress(elapsed: driftElapsed, lapSeconds: lapSeconds)
        }
        let duration = phaseDuration
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    // MARK: The open hour

    var isDrifting: Bool { driftStart != nil }

    /// How long this drift has been going. Derived from the start `Date`, so
    /// it survives being backgrounded, killed and relaunched.
    var driftElapsed: TimeInterval {
        guard let driftStart else { return 0 }
        return max(0, Date().timeIntervalSince(driftStart))
    }

    var lapSeconds: TimeInterval {
        Drift.lapSeconds(focusMinutes: settings.focusMinutes)
    }

    /// Whole laps so far — one tree ring each.
    var driftLaps: Int {
        Drift.laps(elapsed: driftElapsed, lapSeconds: lapSeconds)
    }

    var remainingText: String {
        if isDrifting { return Drift.text(elapsed: driftElapsed) }
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var isRunning: Bool { runState == .running }

    var pawsPerCycle: Int { max(1, settings.sessionsPerLongBreak) }

    /// What the current buddy is called — the user's name for it, if any.
    var buddyName: String { settings.displayName(for: settings.buddy) }

    /// Paw prints to show as earned in the current cycle.
    var filledPaws: Int { min(focusInCycle, pawsPerCycle) }

    /// How well you and your buddy know each other, counted out of the log.
    var bond: Bond { Bond.level(at: log.totalSessions) }

    /// What is in the pouch right now.
    ///
    /// Derived here rather than stored anywhere, which is the whole design —
    /// see `Acorns`. `-PawmodoroAcorns` overrides the *earned* side only, so
    /// what you own still costs what it costs and the sums keep adding up.
    var acorns: Int {
        if let forced = LaunchOptions.forcedAcorns {
            return max(0, forced - pouch.spent)
        }
        return Acorns.balance(minutes: log.totalMinutes, spent: pouch.spent)
    }

    /// Keep a photograph, stamped with everything the world already knew.
    ///
    /// Nothing here is asked for and there is nowhere to type: the date, the
    /// place, the buddy, the sky and the length all come from state the app is
    /// already holding. A memory feature that opens a text box has become a
    /// journal, and this app has one of those.
    func keepSnapshot(file: String) {
        scrapbook.add(Snapshot(
            date: WorldCalendar.now,
            file: file,
            place: settings.place.rawValue,
            buddy: settings.buddy.rawValue,
            weather: weather.rawValue,
            minutes: settings.focusMinutes
        ))
        chronicle.add(.snapshot, settings.place.rawValue)
    }

    /// Where you last touched the buddy, and what it made of it.
    ///
    /// Set for one caption's turn, like `justWore` and `residentArrived`.
    /// Nothing about it is stored: petting is not counted anywhere, does not
    /// feed the bond, and leaves no record. A stroke you could grind would be
    /// a chore with fur on it.
    private(set) var touchedSpot: TouchSpot?
    /// True when that touch found the buddy's favourite place.
    private(set) var foundFavourite = false

    /// Somebody put a hand on the buddy, there.
    func touched(_ spot: TouchSpot?) {
        touchedSpot = spot
        foundFavourite = spot != nil && spot == settings.buddy.favouriteSpot
    }

    /// The treat just offered and how it went, for one caption's worth of
    /// time. Not persisted: it is a remark about a thing that happened five
    /// seconds ago, and `Pouch.hasFedFavourite` is the only part worth
    /// remembering.
    /// A struct rather than the labelled tuple this started as. `@Observable`
    /// did not publish changes to the tuple: feeding a treat wrote through to
    /// `Pouch` exactly as it should and the caption never moved, because the
    /// view was never told anything had changed. Same three fields, same
    /// member names, so every reader is untouched.
    struct Offering: Equatable {
        let treat: Treat
        let reception: Treat.Reception
        let isFirstFavourite: Bool
    }

    private(set) var offered: Offering?

    /// Offer a treat. Nothing is spent, nothing is counted, nothing is
    /// unlocked — see the fences on `Treat`.
    func offer(_ treat: Treat) {
        let buddy = settings.buddy
        let reception = buddy.reception(of: treat)
        let first = reception == .favourite && !pouch.hasFedFavourite(buddy)
        if first { pouch.noteFedFavourite(buddy) }
        offered = Offering(treat: treat, reception: reception,
                           isFirstFavourite: first)
        // The delighted one gets the purr the favourite touch spot already
        // uses; the other two get the same soft detent as any other tap.
        // Deliberately not `complete()` — a treat is not an achievement.
        if reception.isDelighted {
            HapticsDirector.shared.purr()
        } else {
            HapticsDirector.shared.detent()
        }
    }

    func clearOffer() { offered = nil }

    func clearTouch() {
        touchedSpot = nil
        foundFavourite = false
    }

    /// Whether this den is standing in the homestead.
    ///
    /// Soot's is never for sale and arrives with her — asked of `isForSale`
    /// rather than special-cased here, so there is one opinion about it.
    func ownsDen(_ den: Den) -> Bool {
        guard den.isForSale else { return stray.hasJoined }
        return storeHasPlus || pouch.owns(.den(den))
    }

    /// The den standing in the homestead right now, if any. One at a time:
    /// the current buddy's.
    var visibleDen: Den? {
        guard let den = Den.forBuddy(settings.buddy), ownsDen(den) else { return nil }
        return den
    }

    /// Minutes of focus until `count` acorns are in hand, or nil if they
    /// already are. The unlock sheet turns this into a distance.
    func minutesUntil(_ count: Int) -> Int? {
        guard acorns < count else { return nil }
        return (count - acorns) * Acorns.minutesPerAcorn
    }

    /// Take something from the cart.
    ///
    /// The engine does it rather than the view, for the same reason the
    /// journal's writes live here: this is the only place that knows the log,
    /// the pouch and the chronicle at once, and a trade has to touch all
    /// three or none. The debug override is handled honestly — with
    /// `-PawmodoroAcorns` the pouch cannot do its own arithmetic, so the
    /// affordability check happens here against the same balance the sheet
    /// showed, and the pouch is told to keep the item either way.
    @discardableResult
    func trade(_ item: CatalogItem) -> Bool {
        guard !pouch.owns(item) else { return true }
        guard acorns >= item.price else { return false }
        pouch.take(item)
        // Written down and never mentioned again: the Sunday Post keeps this
        // kind silent on purpose — the one surface addressed *to* the reader
        // is not going to double as a receipt.
        chronicle.add(.trade, item.id)
        return true
    }

    /// What the sky is doing where you are, today.
    ///
    /// Derived, never stored: a function of the calendar day and the place,
    /// through `WorldCalendar`. So it survives a reinstall, agrees with itself
    /// across every screen that asks, costs nothing to keep, and moves with
    /// `-PawmodoroDate` along with the season and the moon.
    var weather: Weather { Weather.at(settings.place) }

    /// Where the old snail has got to here today, or nil if she is crossing
    /// somewhere else this month. See `Snail` — she is six months across.
    var snailX: Double? {
        if let forced = LaunchOptions.forcedSnail {
            guard forced >= 0, settings.place.snailVisits else { return nil }
            return 0.04 + forced * 0.92
        }
        return Snail.x(at: settings.place)
    }

    /// Whether a clock face has been earned.
    ///
    /// Every requirement is a counter the app was already keeping for its own
    /// reasons, so nothing new is recorded to unlock one and there is no
    /// separate progression to migrate or corrupt.
    func hasEarned(_ face: ClockFace) -> Bool {
        switch face.requirement {
        case .always:
            return true
        case .sessions(let count):
            return log.totalSessions >= count
        case .nights(let count):
            return log.nightSessions >= count
        case .reached(let place):
            return hasReached(place)
        case .anyConstellation:
            return ConstellationAtlas.completedCount(
                nightSessions: log.nightSessions
            ) > 0
        }
    }

    /// The face to actually draw. Falls back to the ring if the chosen one is
    /// no longer earned — which cannot happen today, because nothing in this
    /// app goes backwards, but the fallback costs one line and means a future
    /// change to a counter can never leave somebody staring at a blank dial.
    var clockFace: ClockFace {
        if let forced = LaunchOptions.forcedClockFace { return forced }
        return hasEarned(settings.clockFace) ? settings.clockFace : .ring
    }

    /// How far the stray has come. Counted out of the log every time it's read
    /// rather than stored, which is what makes it impossible to get out of step
    /// with the history it describes.
    var strayStage: Stray.Stage { stray.stage(log: log) }

    // MARK: Controls

    func start() {
        guard runState != .running else { return }
        if runState == .idle || remaining <= 0 {
            remaining = phaseDuration
        }
        // Rolled once per fresh focus phase — resuming from a pause keeps
        // whatever was already scheduled rather than buying another ticket.
        if runState == .idle {
            rainSeconds = 0
            rollSighting()
            rollDream()
            rollHeard()
            rollEncounter()
            rollStrayCameo()
            // The neighbour has been mentioned for a whole break by now. Once
            // you sit back down it is furniture, which is the entire point of
            // the system. The same goes for a new hat.
            residentArrived = nil
            justWore = nil
            clearTouch()
            clearOffer()
        }

        let end = Date().addingTimeInterval(remaining)
        endDate = end
        runState = .running
        lastHeartbeatSecond = nil
        NotificationManager.shared.schedulePhaseEnd(
            for: phase, buddyName: buddyName, at: end
        )
        // Started fresh or moved on in place: one card per run, not one per
        // phase. A no-op until the widget extension exists.
        if settings.liveActivityEnabled {
            LiveActivityController.shared.startOrUpdate(
                phase: phase, buddyName: buddyName, endDate: end
            )
        }
        HapticsDirector.shared.start()
        refreshAmbience()
        startTicker()
    }

    /// Cast off: an open hour, with no end time and no alarm.
    ///
    /// Deliberately *not* `start()` with a very long duration. Nothing is
    /// scheduled here — no notification, no Live Activity countdown — because
    /// there is nothing to announce: the app does not know when this ends and
    /// will never be the one to say so.
    ///
    /// The Drift **is** focus. The scenery is deaf to a finger exactly as it
    /// is during a countdown, dreams and encounters roll once at cast-off, and
    /// sightings roll again at every lap — so a long drift can meet two
    /// animals, which is the reward for staying.
    func castOff() {
        guard runState == .idle else { return }
        phase = .focus
        rainSeconds = 0
        rollSighting()
        rollDream()
        rollHeard()
        rollEncounter()
        rollStrayCameo()

        let now = Date()
        driftStart = now
        lastLapRolled = 0
        driftNeedsAsking = false
        endDate = nil
        remaining = 0
        runState = .running
        lastHeartbeatSecond = nil
        HapticsDirector.shared.start()
        refreshAmbience()
        startTicker()
    }

    /// Come back in. Banks whatever was earned and returns to an ordinary
    /// idle focus phase.
    ///
    /// `keep: false` is the answer to the six-hour question and to nothing
    /// else — it puts the drift down without recording it, which is the same
    /// thing abandoning a countdown does.
    func endDrift(keep: Bool = true) {
        guard let start = driftStart else { return }
        let elapsed = max(0, Date().timeIntervalSince(start))
        stopTicker()
        driftStart = nil
        driftNeedsAsking = false
        endDate = nil
        runState = .idle
        remaining = phaseDuration
        refreshAmbience()

        guard keep else {
            sighting = nil
            dream = nil
            scheduledSound = nil
            encounter = nil
            return
        }
        bankDrift(from: start, elapsed: elapsed)
    }

    /// Writes a finished drift into the log, then runs the ordinary completion
    /// path once — so the journey, the bond, the constellations, the stray and
    /// the celebration card all behave exactly as they would have after the
    /// countdowns this replaced.
    private func bankDrift(from start: Date, elapsed: TimeInterval) {
        let banking = Drift.banking(elapsed: elapsed, focusMinutes: settings.focusMinutes)
        let dates = Drift.endDates(
            from: start, elapsed: elapsed, focusMinutes: settings.focusMinutes
        )
        guard !banking.isEmpty, banking.minutes.count == dates.count else {
            // Under one lap. Nothing is kept and nothing is said about it —
            // the same rule as leaving a countdown early.
            sighting = nil
            dream = nil
            encounter = nil
            return
        }

        let nightsBefore = log.nightSessions
        let sessionsBefore = log.totalSessions
        let strayBefore = stray.stage(log: log)
        for (minutes, endedAt) in zip(banking.minutes, dates) {
            log.add(minutes: minutes, endedAt: endedAt)
        }
        focusInCycle += banking.laps

        let bond = Bond.justReached(before: sessionsBefore, after: log.totalSessions)
        residentArrived = Resident.justArrived(
            before: sessionsBefore, after: log.totalSessions
        )
        let figure = ConstellationAtlas.justCompleted(
            before: nightsBefore, after: log.nightSessions
        )
        stray.noticeIfReady(log: log)

        var seen: Species?
        if let sighting {
            seen = sighting.species
            journal.add(
                sighting.species, at: settings.place,
                dayPart: LaunchOptions.forcedDayPart ?? DayPart.current(),
                weather: weather
            )
        }
        if let dream {
            dreams.add(dream, daysAfter: daysSinceMeeting(dream))
        }
        let arrival = newlyReachedPlace()
        recordToChronicle(seen: seen, dream: dream, bond: bond, figure: figure,
                          arrival: arrival, strayBefore: strayBefore)
        if let arrival, !arrival.isPlus {
            settings.place = arrival
            settingsDidChange()
        }
        log.recordLongestDrift(seconds: elapsed)

        HapticsDirector.shared.complete()
        SoundPlayer.shared.playChime()
        completion = PhaseCompletion(
            finished: .focus,
            pawsEarned: filledPaws,
            pawsPerCycle: pawsPerCycle,
            isCycleComplete: false,
            arrivedAt: arrival,
            saw: seen,
            completedFigure: figure,
            dreamed: dream,
            bondReached: bond,
            driftLaps: banking.laps
        )
        sighting = nil
        dream = nil
        encounter = nil
    }

    func pause() {
        guard runState == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        runState = .paused
        endDate = nil
        stopTicker()
        NotificationManager.shared.cancelPending()
        LiveActivityController.shared.end()
        refreshAmbience()
    }

    func toggle() {
        if runState == .running {
            pause()
        } else {
            NotificationManager.shared.requestPermissionIfNeeded()
            start()
        }
    }

    /// Restart the current phase from the top.
    func reset() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        LiveActivityController.shared.end()
        endDate = nil
        sighting = nil
        dream = nil
        scheduledSound = nil
        encounter = nil
        runState = .idle
        remaining = phaseDuration
        refreshAmbience()
    }

    /// Jump to the next phase without earning credit for this one.
    func skipPhase() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        LiveActivityController.shared.end()
        endDate = nil
        // Whatever was out there simply leaves, and whatever was being dreamed
        // is not kept. Nothing is logged and nothing is said about it —
        // abandoning a session is not punished here.
        sighting = nil
        dream = nil
        scheduledSound = nil
        encounter = nil
        advance(natural: false)
    }

    /// Start the whole cycle over, clearing earned paw prints.
    func resetCycle() {
        focusInCycle = 0
        phase = .focus
        reset()
    }

    /// Call when the app returns to the foreground.
    func syncAfterWake() {
        // A drift has no end to arrive at, so nothing has to be caught up —
        // its elapsed time is a subtraction against the wall clock and was
        // already right. The one thing to notice is that it may have been
        // going for a very long time.
        if isDrifting {
            driftNeedsAsking = Drift.needsAsking(elapsed: driftElapsed)
            return
        }
        // Backgrounded overnight and brought back is the ordinary way a day
        // starts for somebody who uses this every morning, so the greeting
        // has to live here as well as at launch.
        greetIfOwed()
        guard runState == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            completePhase()
        }
    }

    /// Persist settings and apply anything that takes effect immediately.
    func settingsDidChange() {
        settings.save()
        ThemeManager.shared.theme = settings.theme
        HapticsDirector.shared.isEnabled = settings.hapticsEnabled
        if runState == .idle {
            remaining = phaseDuration
        }
        refreshAmbience()
    }

    /// Falls back to the free content if Pawmodoro Plus isn't (or is no longer)
    /// owned — a refund or a family-sharing change can revoke it after the fact,
    /// and the app should never be left playing a sound the user can't pick again.
    func applyEntitlement(hasPlus: Bool) {
        // `storeHasPlus` is the engine's one record of this and predates the
        // Hearth era — the dream pool and `ownsDen` read it rather than a
        // second copy. Set here as well as at the two call sites, so an
        // entitlement change that arrives through this path is not missed.
        storeHasPlus = hasPlus
        guard !hasPlus else { return }
        var changed = false
        if settings.buddy.isPlus {
            settings.buddy = .cat
            changed = true
        }
        if settings.ambience.isPlus {
            settings.ambience = .off
            changed = true
        }
        if settings.theme.isPlus {
            settings.theme = .sakura
            changed = true
        }
        if let track = currentTrack, track.gate.requiresPlus {
            // A Plus track falls back to the opener rather than to silence:
            // losing Plus shouldn't leave the app quieter than a fresh install.
            settings.music = MusicCatalog.opener.id
            changed = true
        }
        if settings.place.isPlus {
            // Back to the furthest free place already earned, not all the way
            // home: losing Plus shouldn't undo the journey.
            settings.place = furthestFreePlace
            changed = true
        }
        if changed {
            settingsDidChange()
        }
    }

    // MARK: Music

    /// Whether a mixtape (or a single track) has been earned. Arrival gates ask
    /// the journey, which is already tracked — the almanac adds no new state.
    func isUnlocked(_ gate: MusicGate, hasPlus: Bool) -> Bool {
        if LaunchOptions.unlockMusic { return true }
        switch gate {
        case .free: return true
        case .arrival(let place): return hasReached(place)
        case .plus: return hasPlus
        case .found(let finding): return hasFound(finding)
        }
    }

    /// Whether a found mixtape has turned up.
    ///
    /// Deliberately *not* short-circuited by `-PawmodoroUnlockMusic` — that
    /// belongs one level up, in `isUnlocked`, so this stays a pure question
    /// about the world. `recordFoundTapes` writes chronicle rows off the back
    /// of it, and a debug flag that made this true would have the flag
    /// permanently rewrite somebody's history the first time they used it.
    ///
    /// Two of the three ask a counter the app has kept for years. Only the
    /// rain had to be remembered, and it is remembered in the chronicle for
    /// the same reasons `hasFound(_ ambience:)` gives.
    func hasFound(_ finding: MusicFinding) -> Bool {
        switch finding {
        case .rainyday:
            return chronicle.count(of: .tape, subject: finding.rawValue)
                >= MusicFinding.rainSessions
        case .nightshift:
            return log.nightSessions >= MusicFinding.nightSessions
        case .soot:
            return stray.hasJoined
        }
    }

    /// The track currently chosen, if it still exists in the catalogue.
    var currentTrack: MusicTrack? {
        settings.music.flatMap { MusicCatalog.track(id: $0) }
    }

    /// Music follows the timer the same way ambience does: it plays while a
    /// phase is running and rests otherwise, so a forgotten app is silent.
    func refreshMusic(hasPlus: Bool = true) {
        MusicPlayer.shared.volume = Float(settings.musicVolume)
        let radio = settings.radioMode && (hasPlus || LaunchOptions.unlockMusic)
        MusicPlayer.shared.nextForRadio = radio ? { [weak self] in self?.radioPick() } : nil

        guard runState == .running else {
            MusicPlayer.shared.stop()
            return
        }
        if radio {
            MusicPlayer.shared.play(MusicPlayer.shared.current ?? radioPick() ?? MusicCatalog.opener)
        } else if let track = currentTrack {
            MusicPlayer.shared.play(track)
        } else {
            MusicPlayer.shared.stop()
        }
    }

    /// The auto-DJ. Prefers tracks belonging to where you are, and matches
    /// energy to the hour — brighter by day, quieter after dark.
    private func radioPick() -> MusicTrack? {
        let hasPlus = LaunchOptions.unlockMusic || storeHasPlus
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()
        let wanted: ClosedRange<Int> = (part == .dawn || part == .day) ? 2...3 : 1...2

        let available = MusicCatalog.tracks.filter { isUnlocked($0.gate, hasPlus: hasPlus) }
        guard !available.isEmpty else { return nil }

        // A found tape belongs to an *occasion*, not to a place, so place
        // affinity alone would have hidden all fifteen of them forever:
        // `here` is non-empty at seven of the eight places, and the pool is
        // `here` whenever it is. They join the pool when the occasion is on —
        // which makes radio the surface where a find is most audible, because
        // the app starts playing it back to you unprompted.
        let occasion = available.filter { suitsNow($0.gate, part: part) }
        let here = available.filter { $0.collection == settings.place.rawValue }
        let preferred = here + occasion
        let pool = preferred.isEmpty ? available : preferred
        let matched = pool.filter { wanted.contains($0.energy) }
        let choices = (matched.isEmpty ? pool : matched)
            .filter { $0.id != MusicPlayer.shared.current?.id }
        return (choices.isEmpty ? pool : choices).randomElement()
    }

    /// Whether a found tape's occasion is happening right now.
    ///
    /// The third input the plan asked radio to learn — place, hour, and now
    /// the sky. Everything that is not a found tape answers false: a Plus set
    /// or an arrival set reaches the pool through `here`, and letting them
    /// through here as well would just weight them twice.
    private func suitsNow(_ gate: MusicGate, part: DayPart) -> Bool {
        guard case .found(let finding) = gate else { return false }
        switch finding {
        // The sky or the speaker — either one is a wet afternoon.
        case .rainyday: return weather.isRain || settings.ambience.isRain
        case .nightshift: return part == .night || part == .dusk
        // Always. Hers is the only tape with no occasion but her.
        case .soot: return true
        }
    }

    /// Radio needs to know the entitlement without owning a StoreManager.
    var storeHasPlus: Bool = false

    // MARK: Sightings

    /// Decide whether anything turns up during this focus phase, and when.
    ///
    /// Rolled up front rather than moment to moment so the whole appearance is
    /// a pure function of `progress` afterwards — no timer, no state machine,
    /// and the animal is guaranteed to be gone before the chime.
    private func rollSighting() {
        sighting = nil
        guard phase == .focus else { return }

        // A forced dream must actually appear: a rolled sighting would
        // preempt it (the two are exclusive by design), which made the debug
        // flag lose a coin toss in any place with common wildlife about.
        if LaunchOptions.forcedDream != nil, LaunchOptions.forcedSighting == nil {
            return
        }

        let part = LaunchOptions.forcedDayPart ?? DayPart.current()

        if let forced = LaunchOptions.forcedSighting {
            sighting = Sighting(species: forced)
            return
        }

        let sky = weather
        // How deep the open hour is, or zero in an ordinary countdown. This
        // is the only place in the app that passes a non-zero lap count, so
        // the deep-drift roster is unreachable everywhere else by
        // construction rather than by remembering to exclude it.
        let deep = driftStart == nil ? 0 : driftLaps
        let eligible = Species.allCases.filter {
            $0.isEligible(
                place: settings.place,
                dayPart: part,
                focusMinutes: settings.focusMinutes,
                moonIsFull: MoonPhase.isFull(),
                weather: sky,
                laps: deep
            )
        }
        guard !eligible.isEmpty else { return }

        // The first session somewhere new always shows you something: the
        // whole system is invisible until it has happened once.
        if !journal.hasSeenAnything(at: settings.place),
           let welcome = eligible.filter({ $0.rarity == .common }).randomElement() {
            sighting = Sighting(species: welcome)
            return
        }

        // A mythic's conditions are its rarity — if one is eligible at all,
        // the night is already unusual, so it goes to the front of the queue.
        let ordered = eligible.filter { $0.rarity == .mythic }.shuffled()
            + eligible.filter { $0.rarity != .mythic }.shuffled()
        for species in ordered where Double.random(in: 0..<1) < species.rarity.chance {
            sighting = Sighting(species: species)
            return
        }
    }

    /// The phenomenon this session earned, if any.
    ///
    /// Everything here depends on what the session *did* rather than on what
    /// was true when it started, which is why none of it can go through
    /// `rollSighting`. A rainbow needs the rain to have run and stopped; the
    /// first thunder of a year needs to know it is the first.
    ///
    /// Order is rarest-first, and at most one is ever handed out: two
    /// phenomena in one sitting would make both of them ordinary.
    private func lateAward() -> Species? {
        let sky = weather
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()

        func fits(_ species: Species) -> Bool {
            species.spec.places.contains(settings.place)
                && (species.spec.dayParts.isEmpty
                    || species.spec.dayParts.contains(part))
                && species.spec.weathers.contains(sky)
        }

        // Once a year, and only if you were sitting down for it. The journal
        // is the record of whether it has already happened — there is no
        // second flag to keep in step, and clearing history honestly gives it
        // back, because clearing history is somebody saying they want to start
        // again.
        if fits(.firstthunder), isSpring(), !journal.hasSeenThisYear(.firstthunder) {
            return .firstthunder
        }
        // The rainbow's own rule, unchanged and deliberately different from
        // the others: it is earned by having *listened* to rain for half the
        // session, not by the world's sky. That shipped, people have them,
        // and a rainbow you got by choosing the rain loop is a fair rainbow.
        if rainSeconds >= phaseDuration / 2, part == .day,
           Species.rainbow.spec.places.contains(settings.place) {
            return .rainbow
        }
        if fits(.fogbow) { return .fogbow }
        if fits(.sunshower) { return .sunshower }
        return nil
    }

    /// Spring, in the world's one hemisphere. `WorldCalendar.hemisphere` owns
    /// the policy; this asks it rather than assuming March.
    private func isSpring() -> Bool {
        let month = WorldCalendar.calendar.component(.month, from: WorldCalendar.now)
        switch WorldCalendar.hemisphere {
        case .northern: return (3...5).contains(month)
        case .southern: return (9...11).contains(month)
        }
    }

    // MARK: Micro-encounters

    /// The tiny thing visiting this phase, if one is. Never recorded anywhere:
    /// it happens, and then it has happened.
    private(set) var encounter: MicroEncounter?

    /// On screen right now, or nil.
    var visibleEncounter: (encounter: MicroEncounter, phase: Double)? {
        guard isRunning, phase == .focus, let encounter else { return nil }
        let window = encounter.window
        guard window.contains(progress) else { return nil }
        let span = window.upperBound - window.lowerBound
        guard span > 0 else { return nil }
        return (encounter, (progress - window.lowerBound) / span)
    }

    private func rollEncounter() {
        encounter = nil
        guard phase == .focus else { return }

        if let forced = LaunchOptions.forcedEncounter {
            encounter = forced
            return
        }

        let part = LaunchOptions.forcedDayPart ?? DayPart.current()
        let season = Season.current()

        let possible = MicroEncounter.allCases.filter {
            $0.isPossible(place: settings.place, dayPart: part, season: season)
        }
        guard let candidate = possible.randomElement(),
              Double.random(in: 0..<1) < MicroEncounter.chance
        else { return }
        encounter = candidate
    }

    // MARK: Things heard

    /// A sound scheduled for this phase, and the point in it where it lands.
    ///
    /// Stored as a progress fraction for the same reason a sighting is: the
    /// tick already knows how far through the phase it is, so this needs no
    /// timer of its own and cannot drift.
    @ObservationIgnored private var scheduledSound: (sound: Heard, at: Double)?

    /// Decide whether anything is audible this phase, and when.
    ///
    /// Rolled independently of the sighting and the dream — a sound isn't
    /// competing for the screen, and hearing a whale while watching a stag is
    /// a better session, not a busier one.
    private func rollHeard() {
        scheduledSound = nil
        guard phase == .focus else { return }
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()

        // Somewhere in the middle: the opening belongs to settling in and the
        // last stretch belongs to the countdown.
        let at = Double.random(in: 0.25...0.75)
        if let forced = LaunchOptions.forcedHeard {
            scheduledSound = (forced, at)
            return
        }
        let eligible = Heard.allCases.filter {
            $0.isEligible(place: settings.place, dayPart: part, weather: weather)
        }
        guard let sound = eligible.randomElement(),
              Double.random(in: 0..<1) < sound.spec.chance
        else { return }
        scheduledSound = (sound, at)
    }

    /// Fires once, when the phase reaches the scheduled point.
    private func playHeardIfDue() {
        guard let scheduled = scheduledSound, progress >= scheduled.at else { return }
        scheduledSound = nil
        SoundPlayer.shared.playHeard(scheduled.sound)
        // Logged on play, not on completion: unlike a sighting there is
        // nothing to stay for. You either heard it or you didn't.
        journal.addHeard(scheduled.sound)
        chronicle.add(.heard, scheduled.sound.rawValue)
    }

    // MARK: Dreams

    /// The slice of a focus phase a dream is on screen for. Overlaps nothing:
    /// a sighting owns 0.32–0.70 and the two are mutually exclusive anyway.
    static let dreamWindow: ClosedRange<Double> = 0.40...0.70

    /// The dream on screen right now, if there is one. `BuddyView` adds the
    /// last condition — the buddy has to actually be asleep — which is what
    /// makes Luna dream through her daytime naps rather than her night watch,
    /// with no special case anywhere.
    var visibleDream: Dream? {
        guard isRunning, phase == .focus, let dream else { return nil }
        return Self.dreamWindow.contains(progress) ? dream : nil
    }

    /// Decide whether the buddy dreams this phase, and of what.
    ///
    /// Only when nothing else is turning up: a dream and a sighting in the same
    /// session would be two quiet things competing, and the sighting is the
    /// rarer one.
    private func rollDream() {
        dream = nil
        guard phase == .focus, sighting == nil else { return }

        // Luna keeps watch through a night focus — awake creatures don't
        // dream. Without this, the roll still happened and the diary quietly
        // recorded dreams she never showed: the display was gated on the
        // napping pose, but the keep wasn't.
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()
        if settings.buddy.isNocturnal, part == .night { return }

        if let forced = LaunchOptions.forcedDream {
            dream = Dream.from(id: forced) ?? pool().first { $0.id.hasPrefix(forced) }
            return
        }
        guard Double.random(in: 0..<1) < 0.25 else { return }
        dream = pool().randomElement()
    }

    /// Weighted by simple repetition — a species you actually saw is three
    /// times likelier than a fish holding a balloon. The surreal six are always
    /// in the pool so that a brand-new buddy, whose journal is empty, still has
    /// something to dream about.
    ///
    /// Every other entry is gated on the thing it is about, so the pool is a
    /// readout of the life you have actually had here: nothing can be dreamed
    /// by somebody who hasn't met it. That is also why nothing needs a second
    /// unlock table — the journal, the bond, the stray's arc and the calendar
    /// already know, and this asks them.
    private func pool() -> [Dream] {
        var pool: [Dream] = []
        for species in Species.allCases where journal.hasSeen(species) {
            pool.append(contentsOf: repeatElement(.memory(species), count: 3))
            // The one you keep running into goes in *on top of* the species
            // rather than instead of it: a regular ends up twice as likely as
            // anything seen once, which is the whole argument for regulars.
            if journal.isRegular(species) {
                pool.append(contentsOf: repeatElement(.regular(species), count: 3))
            }
        }
        for place in Place.journey where hasReached(place) {
            if let vignette = place.vignette {
                pool.append(contentsOf: repeatElement(.travel(vignette), count: 2))
            }
        }
        // The household, gated on the bond rather than simply on the roster:
        // on day one "Mochi dreamed of the dog" is a dream about a stranger.
        if bond >= .acquainted {
            for buddy in household {
                pool.append(contentsOf: repeatElement(.companion(buddy), count: 2))
            }
        }
        // The cat outside, while she is still outside. Once she has come in
        // she is dreamed about as one of the household instead — the two
        // sources never overlap, and the diary keeps whatever it already had.
        //
        // Gated on `hasJoined` rather than on the stage: she reaches `.home`
        // when she is ready to be named, not when she is named, and a player
        // who leaves the naming sheet for a week would otherwise fall into a
        // hole where she is dreamed about neither way.
        let stage = strayStage
        if !stray.hasJoined {
            for visitor in Dream.Visitor.allCases where stage >= visitor.reachedAt {
                pool.append(contentsOf: repeatElement(.visitor(visitor), count: 2))
            }
        }
        for sound in Heard.allCases where journal.hasHeard(sound) {
            pool.append(contentsOf: repeatElement(.sound(sound), count: 2))
        }
        // Only while it is that time of year. A dream of snow in July would
        // say the seasons mean nothing, which is the opposite of the point of
        // having any. Weighted 3, because the window is a fortnight.
        if let season = Season.current() {
            pool.append(contentsOf: repeatElement(.season(season), count: 3))
        }
        // What today's sky leaves behind. Weighted 3 for the same reason the
        // season is: a storm is one day in thirty and golden only ever follows
        // one, so a low weight would make these unreachable rather than rare.
        let today = weather
        for sky in Dream.Sky.allCases where sky.reachedAt.contains(today) {
            pool.append(contentsOf: repeatElement(.sky(sky), count: 3))
        }
        // The open hour, once you have actually sat one. Counted in laps
        // rather than minutes so it is reachable under fast timers too.
        let longestLaps = Drift.laps(elapsed: log.longestDrift, lapSeconds: lapSeconds)
        for adrift in Dream.Adrift.allCases where longestLaps >= adrift.reachedAt {
            pool.append(contentsOf: repeatElement(.adrift(adrift), count: 2))
        }
        // The hours you have actually been awake in, off the shelf.
        // Named `candles`, not `shelf`: the engine already has a `shelf` and
        // it is a different thing entirely — the desk, not the hours.
        let candles = ShelfOfHours.build(from: log.records)
        for hour in Dream.Hour.allCases
        where ShelfOfHours.isLit(hour.reachedAt, in: candles) {
            pool.append(contentsOf: repeatElement(.hour(hour), count: 2))
        }
        // The wood behind the house, once trees are actually standing in it.
        let trees = Grove.trees(forMinutes: log.totalMinutes).count
        for wood in Dream.Wood.allCases where trees >= wood.reachedAt {
            pool.append(contentsOf: repeatElement(.wood(wood), count: 2))
        }
        // The neighbours, once they have actually moved in. Asked of
        // `Resident.settled` rather than of a threshold copied into `Dream`,
        // so the gate can never disagree with the thing it gates.
        let neighbours = Resident.settled(sessions: log.totalSessions)
        for neighbour in Dream.Neighbour.allCases
        where neighbours.contains(neighbour.reachedAt) {
            pool.append(contentsOf: repeatElement(.neighbour(neighbour), count: 2))
        }
        // The flyway, once you have actually been under it. Gated on the
        // journal rather than on the date, which is the whole difference
        // between this and the season: a season dream is available *while* it
        // is that season and a flight dream is available for the year after
        // the passage, because the fortnight is over and remembering it is
        // the only thing left to do with it.
        for flight in Dream.Flight.allCases {
            guard let species = flight.reachedAt.species,
                  journal.hasSeen(species) else { continue }
            pool.append(contentsOf: repeatElement(.flight(flight), count: 2))
        }
        // The sea, and only for somebody who has actually sat beside it.
        // Gated on having reached Harbor Isle and on the water being in that
        // state *now* — the same shape as the season and the sky, because a
        // tide is the weather of the sea and a dream about low water on a day
        // it never went out would say the tide means nothing.
        if hasReached(.harbor) {
            let water = Tide.state()
            for tidal in Dream.Tidal.allCases where tidal.reachedAt == water {
                pool.append(contentsOf: repeatElement(.tidal(tidal), count: 3))
            }
        }
        // Her cart is one tap inside Settings and always has been open, so
        // the gate is having sat at all rather than having traded — a dream
        // you can only have after spending would be the app rewarding the
        // spending, which is the one thing the fences forbid.
        if log.totalSessions > 0 {
            pool.append(contentsOf: Dream.Magpie.allCases.map(Dream.magpie))
        }
        // Dressed up, once you actually own the thing. Asked of the pouch
        // rather than of a second unlock table, so the gate can never
        // disagree with what is in the wardrobe.
        // A place you sat once, once there is a picture of one.
        if !scrapbook.isEmpty {
            pool.append(contentsOf: Dream.Snapshot.allCases.map(Dream.snapshot))
        }
        // The things it brought you, once it actually has. Asked of the
        // shelf rather than of a threshold, so the gate cannot disagree with
        // what is on the desk.
        for brought in Dream.Brought.allCases where shelf.has(brought.reachedAt) {
            pool.append(contentsOf: repeatElement(.brought(brought), count: 2))
        }
        // Home, from the inside, once there is one to be inside of.
        if visibleDen != nil {
            pool.append(contentsOf: Dream.Home.allCases.map(Dream.den))
        }
        for finery in Dream.Finery.allCases
        where pouch.owns(.accessory(finery.reachedAt)) || storeHasPlus {
            pool.append(contentsOf: repeatElement(.finery(finery), count: 2))
        }
        for yours in Dream.Yours.allCases where bond >= yours.reachedAt {
            pool.append(contentsOf: repeatElement(.yours(yours), count: 2))
        }
        pool.append(contentsOf: Dream.Surreal.allCases.map(Dream.surreal))
        return pool
    }

    /// The others in the household: everything owned, minus whoever is on
    /// duty. A buddy dreaming about itself is not a dream.
    ///
    /// Entitlement is checked here rather than trusted from `settings`,
    /// because a Plus buddy nobody owns has never been in the house.
    private var household: [Buddy] {
        Buddy.roster(strayJoined: stray.hasJoined).filter {
            $0 != settings.buddy && (!$0.isPlus || storeHasPlus)
        }
    }

    /// How long ago you met the thing being dreamed about, so the diary can
    /// write the relationship rather than just the fact.
    ///
    /// Sounds count too: the night you first heard the whale is a meeting, and
    /// "eleven days after you met it" is the most a sound you never saw can be
    /// given. Days come from `WorldCalendar` so the answer agrees with the sky
    /// under `-PawmodoroDate`.
    private func daysSinceMeeting(_ dream: Dream) -> Int? {
        let met: Date?
        switch dream {
        case .memory(let species), .regular(let species):
            met = journal.record(for: species)?.firstSeen
        case .sound(let sound):
            met = journal.firstHeard(sound)
        case .travel, .companion, .visitor, .season, .sky, .adrift, .hour,
             .wood, .yours, .surreal, .neighbour, .flight, .tidal, .magpie,
             .finery, .den, .brought, .snapshot:
            met = nil
        }
        guard let met else { return nil }
        return WorldCalendar.days(from: met, to: WorldCalendar.now)
    }

    /// Roughly one phase in four, once she lives here and somebody else is on
    /// duty. Never while she *is* the buddy — she can't do her rounds and keep
    /// you company at the same time.
    private func rollStrayCameo() {
        strayCameo = stray.hasJoined
            && settings.buddy != .stray
            && Double.random(in: 0..<1) < 0.25
    }

    // MARK: The journey

    /// Whether a place has been reached, ignoring Plus. Entitlement is checked
    /// separately so progress and purchase stay independent.
    func hasReached(_ place: Place) -> Bool {
        LaunchOptions.unlockPlaces || log.totalSessions >= place.requiredSessions
    }

    /// Sessions still to go before this place opens.
    func sessionsRemaining(to place: Place) -> Int {
        max(0, place.requiredSessions - log.totalSessions)
    }

    private var furthestFreePlace: Place {
        Place.journey.last { !$0.isPlus && hasReached($0) } ?? .meadow
    }

    /// The place a just-finished session has newly opened up, if any.
    ///
    /// Called after the log has been written, so `totalSessions` already counts
    /// the session being celebrated. Returns nil for the very first place,
    /// which is where everyone starts.
    func newlyReachedPlace() -> Place? {
        guard let reached = Place.journey.last(where: { hasReached($0) }),
              reached.requiredSessions > 0,
              log.totalSessions == reached.requiredSessions
        else { return nil }
        return reached
    }

    /// Ambience follows the timer: it plays while running and rests otherwise.
    func refreshAmbience() {
        SoundPlayer.shared.setAmbience(runState == .running ? settings.ambience : .off,
                                      place: settings.place)
        SoundPlayer.shared.ambienceVolume = Float(settings.ambienceVolume)
        refreshMusic()
    }

    // MARK: Ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        // .common keeps the countdown updating while the user scrolls a sheet.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        // Before the drift branch, because an open hour is still an hour and
        // the person sitting through it was just as present for the strike.
        strikeHourIfDue()
        strikeDebugBellIfDue()
        if isDrifting { return tickDrift() }
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if settings.ambience == .rain { rainSeconds += 0.25 }
        playHeardIfDue()
        pulseIfClosing()
        if remaining <= 0 {
            completePhase()
        }
    }

    /// A drift has nothing to count down to, so this does three things and
    /// stops: keeps the rainbow's rain clock, plays anything scheduled, and
    /// rolls a fresh sighting at the top of every lap.
    private func tickDrift() {
        if settings.ambience == .rain { rainSeconds += 0.25 }
        playHeardIfDue()
        let lap = driftLaps
        guard lap > lastLapRolled else { return }
        lastLapRolled = lap
        // A new lap, so the meadow gets another go. `progress` has just
        // wrapped to zero, which is exactly what a fresh sighting expects.
        rollSighting()
        HapticsDirector.shared.start()
    }

    // MARK: The bell of hours

    /// How late a tick may be and still count as having been there for the
    /// strike.
    ///
    /// The ticker runs at 0.25s with 0.1s of tolerance, so five seconds is
    /// enormously generous for an app that is awake — and it is the whole
    /// mechanism for the rule that matters: an app suspended in the
    /// background comes back to its first tick minutes or hours after the
    /// hour turned, lands outside this window, and neither rings nor records.
    /// You were not there.
    private static let strikeWindow: TimeInterval = 5

    /// One strike at the top of each real hour, while a phase is running.
    ///
    /// Derived from an absolute `Date` and the hour it falls in, never from a
    /// count of ticks — same rule as the countdown, and for the same reason.
    private func strikeHourIfDue() {
        guard runState == .running, settings.hourBellEnabled else { return }
        let now = WorldCalendar.now
        guard let top = WorldCalendar.calendar.dateInterval(of: .hour, for: now)?.start,
              top != lastStruckHour
        else { return }

        // Recorded whether or not it rings, so an hour that was missed is
        // missed exactly once and cannot ring late on the next tick.
        let hadSeenAnHour = lastStruckHour != nil
        lastStruckHour = top
        guard hadSeenAnHour, now.timeIntervalSince(top) < Self.strikeWindow else { return }

        strike(hour: WorldCalendar.calendar.component(.hour, from: top), at: now)
    }

    /// Ring it, and remember having been here for it.
    ///
    /// The hour decides the voice's grade rather than `DayPart.current()`: a
    /// strike belongs to the hour it strikes, and at 16:59:59 those are two
    /// different answers.
    private func strike(hour: Int, at date: Date) {
        SoundPlayer.shared.playBell(
            BellVoice.at(settings.place),
            part: LaunchOptions.forcedDayPart ?? DayPart.from(hour: hour)
        )
        // Only the first time an hour is ever filled reaches the chronicle —
        // one row per position, twenty-four in a lifetime, rather than one an
        // hour forever in a log that is capped and drops its oldest.
        guard clockRing.note(hour: hour, at: date) else { return }
        chronicle.add(.bell, String(hour), at: date)
        mintBellTowerCardIfDue(at: date)
    }

    /// The one card the dial mints, the session it closes.
    ///
    /// The album is searched rather than a flag being stored, exactly as the
    /// panorama does it: the album already *is* the record of what has been
    /// sent, and a second opinion about it is a second thing to keep in step.
    private func mintBellTowerCardIfDue(at date: Date) {
        guard clockRing.isComplete,
              !album.cards.contains(where: { $0.occasion == .belltower })
        else { return }
        album.add(Postcard(
            id: UUID(),
            date: date,
            place: settings.place.rawValue,
            dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
            buddy: settings.buddy.rawValue,
            occasion: .belltower,
            sessions: log.todaySessions,
            sighting: nil,
            minutes: nil
        ))
        chronicle.add(.bell, "ring", at: date)
    }

    /// `-PawmodoroBell`: one strike, five seconds after launch, once
    /// something is actually running.
    ///
    /// Deliberately not routed through `strikeHourIfDue` — that function's
    /// whole job is refusing to ring at the wrong moment, and a debug flag
    /// that had to be threaded through it would be testing the wrong code.
    /// Compiled away in Release, where `LaunchOptions.bell` is a `false`
    /// constant.
    private func strikeDebugBellIfDue() {
        guard LaunchOptions.bell, !firedDebugBell, runState == .running,
              Date().timeIntervalSince(bornAt) >= 5
        else { return }
        firedDebugBell = true
        let hour = LaunchOptions.bellHour
            ?? WorldCalendar.calendar.component(.hour, from: WorldCalendar.now)
        strike(hour: hour, at: WorldCalendar.now)
    }

    /// One soft heartbeat per second over the last ten, tightening as the phase
    /// closes. Driven off the existing ticker rather than a timer of its own.
    private func pulseIfClosing() {
        let window: TimeInterval = 10
        guard remaining > 0, remaining <= window else { return }
        let second = Int(remaining.rounded(.up))
        guard second != lastHeartbeatSecond else { return }
        lastHeartbeatSecond = second
        HapticsDirector.shared.heartbeat(progress: 1 - remaining / window)
    }

    private func completePhase() {
        stopTicker()
        LiveActivityController.shared.end()
        endDate = nil
        remaining = 0
        lastHeartbeatSecond = nil

        let finished = phase
        HapticsDirector.shared.complete()
        SoundPlayer.shared.playChime()

        var arrival: Place?
        var seen: Species?
        var figure: Constellation?
        var bond: Bond?
        if finished == .focus {
            // Read either side of the write, so a figure can only be announced
            // by the one session that actually finished it.
            let nightsBefore = log.nightSessions
            let sessionsBefore = log.totalSessions
            let strayBefore = stray.stage(log: log)
            log.add(minutes: settings.focusMinutes)
            bond = Bond.justReached(before: sessionsBefore, after: log.totalSessions)
            residentArrived = Resident.justArrived(
                before: sessionsBefore, after: log.totalSessions
            )
            figure = ConstellationAtlas.justCompleted(
                before: nightsBefore, after: log.nightSessions
            )
            // Checked after the log is written, so the session that just
            // finished counts toward the week she is deciding about. She only
            // ever starts watching off the back of a session you completed.
            stray.noticeIfReady(log: log)
            // The phenomena are not rolled: they are earned by what the
            // session actually did, which is only knowable now.
            if sighting == nil, let earned = lateAward() {
                sighting = Sighting(species: earned)
            }
            // Same rule as a sighting: leave early and the dream just fades,
            // unrecorded. Dreams are like that.
            if let dream {
                dreams.add(dream, daysAfter: daysSinceMeeting(dream))
            }
            // You only keep what you stayed for.
            if let sighting {
                seen = sighting.species
                journal.add(
                    sighting.species,
                    at: settings.place,
                    dayPart: LaunchOptions.forcedDayPart ?? DayPart.current(),
                    weather: weather
                )
            }
            // Checked after the log is written, so this session counts toward
            // the threshold it might have just crossed.
            arrival = newlyReachedPlace()
            recordFoundSounds()
            recordFoundTapes()
            recordToChronicle(seen: seen, dream: dream, bond: bond, figure: figure,
                              arrival: arrival, strayBefore: strayBefore)
            if let arrival, !arrival.isPlus {
                // Free arrivals move you there; the Far Isles wait behind the
                // paywall rather than switching to a place you can't keep.
                settings.place = arrival
            }
        }
        advance(natural: true)

        // Published after `advance`, so the paw count and the phase it reports
        // are the ones the UI is about to draw.
        // A card for the two moments worth keeping: getting somewhere new,
        // and closing a cycle. Both are rare enough that the album stays a
        // record rather than a feed.
        if finished == .focus, arrival != nil || (phase == .longBreak) {
            album.add(Postcard(
                id: UUID(),
                date: Date(),
                place: settings.place.rawValue,
                dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
                buddy: settings.buddy.rawValue,
                occasion: arrival != nil ? .arrival : .cycle,
                sessions: log.todaySessions,
                sighting: seen?.rawValue,
                minutes: nil
            ))
        }

        // A hundred hours. The one card in the album that takes four months of
        // daily sitting to reach, minted the session it is crossed and never
        // again — the album is searched rather than a flag being stored,
        // because the album is already the record of what has been sent and a
        // second opinion about it is a second thing to keep in step.
        if finished == .focus,
           log.totalMinutes >= Grove.panoramaHours * Grove.minutesPerTree,
           !album.cards.contains(where: { $0.occasion == .panorama }) {
            album.add(Postcard(
                id: UUID(),
                date: Date(),
                place: settings.place.rawValue,
                dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
                buddy: settings.buddy.rawValue,
                occasion: .panorama,
                sessions: log.todaySessions,
                sighting: seen?.rawValue,
                minutes: log.totalMinutes
            ))
            chronicle.add(.panorama, String(Grove.panoramaHours))
        }

        completion = PhaseCompletion(
            finished: finished,
            pawsEarned: filledPaws,
            pawsPerCycle: pawsPerCycle,
            isCycleComplete: finished == .focus && phase == .longBreak,
            arrivedAt: arrival,
            saw: seen,
            completedFigure: figure,
            dreamed: finished == .focus ? dream : nil,
            bondReached: bond
        )
        sighting = nil
        dream = nil
    }

    /// Writes this session's episodes to the chronicle.
    ///
    /// Everything here is already known by the time it is called — this adds
    /// no rolls and no decisions, it only remembers. Deliberately the last
    /// thing to touch the stores, so a chronicle entry can never exist for
    /// something the journal or diary refused to keep.
    /// Whether the buddy has recorded a found loop for you.
    ///
    /// Asked of the chronicle rather than of a store of its own: the
    /// chronicle already exists, already survives a reinstall's worth of
    /// backup, and is already cleared by `-PawmodoroResetState`. A second
    /// place to keep "has this happened" is a second place for it to
    /// disagree with itself.
    func hasFound(_ ambience: Ambience) -> Bool {
        guard ambience.isFound else { return true }
        if LaunchOptions.unlockSounds { return true }
        return chronicle.firstTime(.sound, subject: ambience.rawValue) != nil
    }

    /// Records any found loop this session just earned.
    ///
    /// Weather is asked of the sky the session actually ran under, and the
    /// night count of the log *after* this session is written — so the fifth
    /// night session is the one that finds the crickets, not the sixth.
    private func recordFoundSounds() {
        var earned: [Ambience] = []
        switch weather {
        case .storm: earned.append(.storm)
        case .snow: earned.append(.snowhush)
        case .clear, .overcast, .breeze, .drizzle, .rain, .mist, .golden:
            break
        }
        if log.nightSessions >= 5 { earned.append(.crickets) }
        for sound in earned where !hasFound(sound) {
            chronicle.add(.sound, sound.rawValue)
        }
    }

    /// Records progress toward the mixtapes you play your way into, and the
    /// day each one arrives.
    ///
    /// Runs immediately after `recordFoundSounds()` and on the same terms: the
    /// session is already over, the log is already written, and nothing here
    /// rolls or decides anything.
    private func recordFoundTapes() {
        // The rain tally. One row per session finished with rain playing, and
        // only while the tape is still out there — so five rows exist forever
        // after and never a sixth. `settings.ambience` rather than the sky:
        // the tapes are written to duet with the loop, so the thing that earns
        // them is having had the loop on, not having been rained on.
        if !hasFound(.rainyday), settings.ambience.isRain {
            chronicle.add(.tape, MusicFinding.rainyday.rawValue)
        }
        // The arrivals. Written once each, after the tally above, so the
        // fifth rainy session finds the tape and says so in the same breath.
        for finding in MusicFinding.allCases where hasFound(finding) {
            guard chronicle.firstTime(.tape, subject: finding.foundSubject) == nil
            else { continue }
            chronicle.add(.tape, finding.foundSubject)
        }
    }

    private func recordToChronicle(
        seen: Species?,
        dream: Dream?,
        bond: Bond?,
        figure: Constellation?,
        arrival: Place?,
        strayBefore: Stray.Stage
    ) {
        if let seen { chronicle.add(.sighting, seen.rawValue) }
        if let dream { chronicle.add(.dream, dream.id) }
        // Bond and stage are Int-raw; their numbers are the stable key.
        if let bond { chronicle.add(.bond, String(bond.rawValue)) }
        if let figure { chronicle.add(.figure, figure.id) }
        if let arrival { chronicle.add(.arrival, arrival.rawValue) }
        // Nothing is shown and nothing is unlocked. It is written down, and in
        // a year the Sunday Post will be able to say you were both out.
        if snailX != nil { chronicle.add(.snail, settings.place.rawValue) }
        // Read off the engine rather than passed in: both completion paths
        // set it immediately after the log write, and there is exactly one
        // session it can be true for.
        if let resident = residentArrived {
            chronicle.add(.resident, resident.rawValue)
        }
        // Something left on the desk. One roll per completed session at long
        // odds, against the session rather than against anything done in it —
        // there is no way to make a keepsake likelier and nothing to
        // optimise, which is what keeps a stick a gift rather than a drop.
        // `bond` the parameter is the level *just crossed* and is usually
        // nil; the gate wants the level you are actually at.
        if self.bond >= Keepsake.reachedAt,
           Double.random(in: 0..<1) < Keepsake.chance {
            let keepsake = Keepsake.next(after: shelf.count)
            shelf.add(keepsake)
            chronicle.add(.keepsake, keepsake.rawValue)
        }
        // The first night actually spent in a new den. Recorded here rather
        // than by the homestead view, for the same reason every other episode
        // is: a view should never write to the log, and this is the one place
        // that knows the hour, the buddy and the pouch at once.
        if let den = Den.forBuddy(settings.buddy),
           ownsDen(den),
           den.isOccupied(at: LaunchOptions.forcedDayPart ?? DayPart.current(),
                          buddy: settings.buddy),
           !pouch.hasSettled(in: den) {
            pouch.noteSettled(in: den)
            chronicle.add(.settledIn, den.rawValue)
        }
        let strayAfter = stray.stage(log: log)
        if strayAfter != strayBefore {
            chronicle.add(.stray, String(strayAfter.rawValue))
        }
    }

    private func advance(natural: Bool) {
        switch phase {
        case .focus:
            if natural {
                focusInCycle += 1
            }
            phase = focusInCycle >= pawsPerCycle ? .longBreak : .shortBreak
        case .shortBreak:
            phase = .focus
        case .longBreak:
            focusInCycle = 0
            phase = .focus
        }

        runState = .idle
        remaining = phaseDuration
        refreshAmbience()

        if natural && settings.autoStartNextPhase {
            start()
        }
    }
}
