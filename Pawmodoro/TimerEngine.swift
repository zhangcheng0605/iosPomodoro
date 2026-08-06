import Foundation
import Observation
import UIKit

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

    let log: SessionLog
    let journal: Journal
    let album: Album
    let stray: Stray
    let dreams: DreamDiary
    /// Written to, never read from — yet. See `Chronicle`.
    let chronicle: Chronicle
    /// What has been traded for. The balance is not in here — see `Acorns`.
    let pouch: Pouch

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    /// Which whole second the closing heartbeat last fired on.
    @ObservationIgnored private var lastHeartbeatSecond: Int?
    /// Seconds of this phase spent with rain playing — the rainbow's condition.
    @ObservationIgnored private var rainSeconds: TimeInterval = 0
    /// Which lap the drift last rolled a sighting for, so each lap rolls once.
    @ObservationIgnored private var lastLapRolled = 0

    init(
        settings: PomodoroSettings? = nil,
        log: SessionLog = SessionLog(),
        journal: Journal = Journal(),
        album: Album = Album(),
        stray: Stray = Stray(),
        dreams: DreamDiary = DreamDiary(),
        chronicle: Chronicle = Chronicle(),
        pouch: Pouch = Pouch()
    ) {
        let resolved = settings ?? PomodoroSettings.load()
        self.settings = resolved
        self.log = log
        self.journal = journal
        self.album = album
        self.stray = stray
        self.dreams = dreams
        self.chronicle = chronicle
        self.pouch = pouch
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
            // the system.
            residentArrived = nil
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

        let here = available.filter { $0.collection == settings.place.rawValue }
        let pool = here.isEmpty ? available : here
        let matched = pool.filter { wanted.contains($0.energy) }
        let choices = (matched.isEmpty ? pool : matched)
            .filter { $0.id != MusicPlayer.shared.current?.id }
        return (choices.isEmpty ? pool : choices).randomElement()
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
        let eligible = Species.allCases.filter {
            $0.isEligible(
                place: settings.place,
                dayPart: part,
                focusMinutes: settings.focusMinutes,
                moonIsFull: MoonPhase.isFull(),
                weather: sky
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
        let shelf = ShelfOfHours.build(from: log.records)
        for hour in Dream.Hour.allCases
        where ShelfOfHours.isLit(hour.reachedAt, in: shelf) {
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
        // Her cart is one tap inside Settings and always has been open, so
        // the gate is having sat at all rather than having traded — a dream
        // you can only have after spending would be the app rewarding the
        // spending, which is the one thing the fences forbid.
        if log.totalSessions > 0 {
            pool.append(contentsOf: Dream.Magpie.allCases.map(Dream.magpie))
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
             .wood, .yours, .surreal:
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
        SoundPlayer.shared.setAmbience(runState == .running ? settings.ambience : .off)
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
                sighting: seen?.rawValue
            ))
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
