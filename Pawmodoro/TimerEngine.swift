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

    let log: SessionLog
    let journal: Journal
    let album: Album
    let stray: Stray

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    /// Which whole second the closing heartbeat last fired on.
    @ObservationIgnored private var lastHeartbeatSecond: Int?
    /// Seconds of this phase spent with rain playing — the rainbow's condition.
    @ObservationIgnored private var rainSeconds: TimeInterval = 0

    init(
        settings: PomodoroSettings? = nil,
        log: SessionLog = SessionLog(),
        journal: Journal = Journal(),
        album: Album = Album(),
        stray: Stray = Stray()
    ) {
        let resolved = settings ?? PomodoroSettings.load()
        self.settings = resolved
        self.log = log
        self.journal = journal
        self.album = album
        self.stray = stray
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
            journal.fillForDebug()
        }
        stray.seedForDebug()
        if let forced = LaunchOptions.forcedTrack, MusicCatalog.track(id: forced) != nil {
            self.settings.music = forced
        }
    }

    // MARK: Derived values

    var phaseDuration: TimeInterval { settings.duration(for: phase) }

    /// 0 at the start of a phase, 1 when it completes.
    var progress: Double {
        let duration = phaseDuration
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    var remainingText: String {
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var isRunning: Bool { runState == .running }

    var pawsPerCycle: Int { max(1, settings.sessionsPerLongBreak) }

    /// What the current buddy is called — the user's name for it, if any.
    var buddyName: String { settings.displayName(for: settings.buddy) }

    /// Paw prints to show as earned in the current cycle.
    var filledPaws: Int { min(focusInCycle, pawsPerCycle) }

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
            rollStrayCameo()
        }

        let end = Date().addingTimeInterval(remaining)
        endDate = end
        runState = .running
        lastHeartbeatSecond = nil
        NotificationManager.shared.schedulePhaseEnd(
            for: phase, buddyName: buddyName, at: end
        )
        HapticsDirector.shared.start()
        refreshAmbience()
        startTicker()
    }

    func pause() {
        guard runState == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        runState = .paused
        endDate = nil
        stopTicker()
        NotificationManager.shared.cancelPending()
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
        endDate = nil
        sighting = nil
        runState = .idle
        remaining = phaseDuration
        refreshAmbience()
    }

    /// Jump to the next phase without earning credit for this one.
    func skipPhase() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        endDate = nil
        // Whatever was out there simply leaves. Nothing is logged and nothing
        // is said about it — abandoning a session is not punished here.
        sighting = nil
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

        let part = LaunchOptions.forcedDayPart ?? DayPart.current()

        if let forced = LaunchOptions.forcedSighting {
            sighting = Sighting(species: forced)
            return
        }

        let eligible = Species.allCases.filter {
            $0.isEligible(
                place: settings.place,
                dayPart: part,
                focusMinutes: settings.focusMinutes,
                moonIsFull: MoonPhase.isFull()
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
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if settings.ambience == .rain { rainSeconds += 0.25 }
        pulseIfClosing()
        if remaining <= 0 {
            completePhase()
        }
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
        endDate = nil
        remaining = 0
        lastHeartbeatSecond = nil

        let finished = phase
        HapticsDirector.shared.complete()
        SoundPlayer.shared.playChime()

        var arrival: Place?
        var seen: Species?
        if finished == .focus {
            log.add(minutes: settings.focusMinutes)
            // Checked after the log is written, so the session that just
            // finished counts toward the week she is deciding about. She only
            // ever starts watching off the back of a session you completed.
            stray.noticeIfReady(log: log)
            // A rainbow is not rolled: it is earned by a session that
            // actually ran rain for at least half its length, which is only
            // knowable now. Deterministic, so it feels given rather than won.
            if sighting == nil,
               rainSeconds >= phaseDuration / 2,
               (LaunchOptions.forcedDayPart ?? DayPart.current()) == .day,
               Species.rainbow.spec.places.contains(settings.place) {
                sighting = Sighting(species: .rainbow)
            }
            // You only keep what you stayed for.
            if let sighting {
                seen = sighting.species
                journal.add(
                    sighting.species,
                    at: settings.place,
                    dayPart: LaunchOptions.forcedDayPart ?? DayPart.current()
                )
            }
            // Checked after the log is written, so this session counts toward
            // the threshold it might have just crossed.
            arrival = newlyReachedPlace()
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
            saw: seen
        )
        sighting = nil
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
