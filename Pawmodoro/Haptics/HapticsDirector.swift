import CoreHaptics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Every haptic the app plays, in one place.
///
/// Uses Core Haptics where the hardware has it, so the purr can be a real
/// continuous rumble rather than a burst of taps, and falls back to the UIKit
/// generators everywhere else. Both paths are no-ops in a simulator — these
/// have to be checked on a device.
///
/// The engine is started lazily and restarted on demand: iOS stops it when the
/// app is backgrounded, and a stopped engine throws on every subsequent play.
final class HapticsDirector {
    static let shared = HapticsDirector()

    /// Mirrors `PomodoroSettings.hapticsEnabled`; every method returns early
    /// when this is off, so call sites don't each have to check.
    var isEnabled = true

    private var engine: CHHapticEngine?
    private var engineIsRunning = false
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() {}

    // MARK: The score

    /// A firm thump as a phase starts.
    func start() {
        transient(intensity: 0.9, sharpness: 0.4, fallback: .medium)
    }

    /// A light tick for each detent while dragging the ring, and for pickers.
    func detent() {
        guard isEnabled else { return }
        if supportsHaptics {
            transient(intensity: 0.45, sharpness: 0.8, fallback: .light)
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    /// A soft refusal — used when a control can't act right now.
    func nudge() {
        transient(intensity: 0.3, sharpness: 0.2, fallback: .soft)
    }

    /// One beat of the final-ten-seconds countdown. `progress` runs 0...1 across
    /// those seconds so the heartbeat can tighten as the phase closes.
    func heartbeat(progress: Double) {
        guard isEnabled else { return }
        let eased = 0.35 + 0.45 * max(0, min(1, progress))
        guard supportsHaptics else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: eased)
            #endif
            return
        }
        // Two taps, close together: a heartbeat, not a metronome.
        play(events: [
            transientEvent(at: 0, intensity: Float(eased), sharpness: 0.3),
            transientEvent(at: 0.14, intensity: Float(eased) * 0.7, sharpness: 0.25),
        ])
    }

    /// The phase-complete flourish.
    func complete() {
        guard isEnabled else { return }
        guard supportsHaptics else {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            return
        }
        play(events: [
            transientEvent(at: 0, intensity: 0.7, sharpness: 0.5),
            transientEvent(at: 0.11, intensity: 0.85, sharpness: 0.6),
            transientEvent(at: 0.24, intensity: 1.0, sharpness: 0.7),
        ])
    }

    /// The purr: a continuous rumble whose intensity rolls, so it feels like
    /// breathing rather than a buzz. This is the one that sells the petting.
    func purr(duration: TimeInterval = 1.3) {
        guard isEnabled else { return }
        guard supportsHaptics, let engine = runningEngine() else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
            #endif
            return
        }

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12),
            ],
            relativeTime: 0,
            duration: duration
        )

        // Swell in, roll twice, fade out.
        let points: [(TimeInterval, Float)] = [
            (0, 0.0), (0.12, 0.8), (0.35, 0.5),
            (0.55, 0.9), (0.78, 0.5), (1.0, 0.0),
        ].map { (duration * $0.0, $0.1) }

        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points.map {
                CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1)
            },
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [curve])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
            #endif
        }
    }

    // MARK: Plumbing

    private func transient(
        intensity: Float,
        sharpness: Float,
        fallback: FeedbackStyle
    ) {
        guard isEnabled else { return }
        guard supportsHaptics else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
            #endif
            return
        }
        play(events: [transientEvent(at: 0, intensity: intensity, sharpness: sharpness)])
    }

    private func transientEvent(
        at time: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func play(events: [CHHapticEvent]) {
        guard let engine = runningEngine() else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // A haptic is never worth surfacing an error for.
        }
    }

    /// Builds the engine on first use and restarts it if the system stopped it.
    private func runningEngine() -> CHHapticEngine? {
        guard supportsHaptics else { return nil }

        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.stoppedHandler = { [weak self] _ in
                self?.engineIsRunning = false
            }
            engine?.resetHandler = { [weak self] in
                self?.engineIsRunning = false
            }
        }
        guard let engine else { return nil }

        if !engineIsRunning {
            do {
                try engine.start()
                engineIsRunning = true
            } catch {
                return nil
            }
        }
        return engine
    }
}
