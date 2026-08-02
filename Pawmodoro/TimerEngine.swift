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

    let log: SessionLog
    let journal: Journal

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    /// Which whole second the closing heartbeat last fired on.
    @ObservationIgnored private var lastHeartbeatSecond: Int?

    init(
        settings: PomodoroSettings? = nil,
        log: SessionLog = SessionLog(),
        journal: Journal = Journal()
    ) {
        let resolved = settings ?? PomodoroSettings.load()
        self.settings = resolved
        self.log = log
        self.journal = journal
        self.remaining = resolved.duration(for: .focus)
        ThemeManager.shared.theme = resolved.theme
        HapticsDirector.shared.isEnabled = resolved.hapticsEnabled
        if let forced = LaunchOptions.forcedPlace {
            self.settings.place = forced
        }
        if let forced = LaunchOptions.forcedBuddy {
            self.settings.buddy = forced
        }
        if LaunchOptions.fillJournal {
            journal.fillForDebug()
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

    // MARK: Controls

    func start() {
        guard runState != .running else { return }
        if runState == .idle || remaining <= 0 {
            remaining = phaseDuration
        }
        // Rolled once per fresh focus phase — resuming from a pause keeps
        // whatever was already scheduled rather than buying another ticket.
        if runState == .idle { rollSighting() }

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
            $0.isEligible(place: settings.place, dayPart: part, focusMinutes: settings.focusMinutes)
        }
        guard !eligible.isEmpty else { return }

        // The first session somewhere new always shows you something: the
        // whole system is invisible until it has happened once.
        if !journal.hasSeenAnything(at: settings.place),
           let welcome = eligible.filter({ $0.rarity == .common }).randomElement() {
            sighting = Sighting(species: welcome)
            return
        }

        for species in eligible.shuffled() where Double.random(in: 0..<1) < species.rarity.chance {
            sighting = Sighting(species: species)
            return
        }
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
