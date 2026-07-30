import Foundation
import Observation
import UIKit

/// The Pomodoro state machine. Time is always derived from an absolute end
/// `Date`, never from accumulated ticks — iOS suspends backgrounded apps, so
/// counting ticks would drift. `syncAfterWake()` recomputes on foreground.
@Observable
final class TimerEngine {

    enum Phase: String {
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
    }

    enum State {
        case idle      // not started, or finished a phase and waiting
        case running
        case paused
    }

    private(set) var phase: Phase = .focus
    private(set) var state: State = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var completedFocusSessions = 0

    // MARK: Settings (persisted)

    var focusMinutes: Int {
        didSet { defaults.set(focusMinutes, forKey: Keys.focus); resetIfIdle() }
    }
    var shortBreakMinutes: Int {
        didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreak); resetIfIdle() }
    }
    var longBreakMinutes: Int {
        didSet { defaults.set(longBreakMinutes, forKey: Keys.longBreak); resetIfIdle() }
    }
    var sessionsPerLongBreak: Int {
        didSet { defaults.set(sessionsPerLongBreak, forKey: Keys.cycle) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    private enum Keys {
        static let focus = "focusMinutes"
        static let shortBreak = "shortBreakMinutes"
        static let longBreak = "longBreakMinutes"
        static let cycle = "sessionsPerLongBreak"
        static let haptics = "hapticsEnabled"
    }

    private let defaults = UserDefaults.standard
    private var endDate: Date?
    private var ticker: Timer?

    init() {
        focusMinutes = defaults.object(forKey: Keys.focus) as? Int ?? 25
        shortBreakMinutes = defaults.object(forKey: Keys.shortBreak) as? Int ?? 5
        longBreakMinutes = defaults.object(forKey: Keys.longBreak) as? Int ?? 15
        sessionsPerLongBreak = defaults.object(forKey: Keys.cycle) as? Int ?? 4
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        remaining = phaseDuration
    }

    var phaseDuration: TimeInterval {
        switch phase {
        case .focus: TimeInterval(focusMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }

    /// 0 → just started, 1 → phase complete.
    var progress: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / phaseDuration))
    }

    var remainingText: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: Controls

    func start() {
        guard state != .running else { return }
        if state == .idle { remaining = phaseDuration }
        let end = Date().addingTimeInterval(remaining)
        endDate = end
        state = .running
        NotificationManager.shared.schedulePhaseEnd(for: phase, at: end)
        startTicker()
    }

    func pause() {
        guard state == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        state = .paused
        endDate = nil
        stopTicker()
        NotificationManager.shared.cancelPending()
    }

    func reset() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        endDate = nil
        state = .idle
        remaining = phaseDuration
    }

    func skipPhase() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        endDate = nil
        advance(countCompletion: false)
    }

    /// Called when the app returns to the foreground.
    func syncAfterWake() {
        guard state == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining == 0 {
            completePhase()
        }
    }

    // MARK: Internals

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
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
        if remaining == 0 {
            completePhase()
        }
    }

    private func completePhase() {
        stopTicker()
        endDate = nil
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        advance(countCompletion: true)
    }

    private func advance(countCompletion: Bool) {
        switch phase {
        case .focus:
            if countCompletion { completedFocusSessions += 1 }
            let dueLongBreak = completedFocusSessions > 0
                && completedFocusSessions % sessionsPerLongBreak == 0
            phase = dueLongBreak ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }
        state = .idle
        remaining = phaseDuration
    }

    private func resetIfIdle() {
        if state == .idle { remaining = phaseDuration }
    }
}
