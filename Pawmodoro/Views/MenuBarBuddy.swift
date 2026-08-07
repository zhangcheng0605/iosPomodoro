#if os(macOS)
import SwiftUI

/// The Mac's whole pitch: the buddy lives in your menu bar while you work.
///
/// A phone app you can also run on a laptop is not worth shipping. What makes
/// this worth a second platform is that the window can be closed entirely and
/// the session keeps going — the countdown is in the menu bar, the buddy is
/// asleep beside it, and you get on with whatever you opened the Mac to do.
///
/// This costs nothing to keep accurate, because of a law written for a
/// completely different reason: the countdown derives from an absolute end
/// `Date`, so **App Nap cannot break it**. A tick-counting timer would drift
/// or stall the moment macOS throttled the app, exactly as it would when iOS
/// suspends a backgrounded one.
struct MenuBarBuddy: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        HStack(spacing: 4) {
            // Asleep while you focus, up and about on a break — the same
            // fiction as the phone, at sixteen points.
            BuddySprite(
                buddy: engine.settings.buddy,
                sleeping: engine.isRunning && !engine.phase.isBreak,
                size: 16,
                outfit: engine.settings.outfit(for: engine.settings.buddy)
            )
            if engine.isRunning {
                Text(engine.remainingText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
        .accessibilityLabel(label)
    }

    private var label: String {
        let name = engine.settings.displayName(for: engine.settings.buddy)
        guard engine.isRunning else { return "Pawmodoro. \(name) is waiting." }
        return engine.phase.isBreak
            ? "Break, \(engine.remainingText) left."
            : "Focus, \(engine.remainingText) left. \(name) is asleep."
    }
}

/// What the menu opens to: the controls, and nothing else.
///
/// Deliberately four items. A menu bar extra is a glance and a keystroke, not
/// a second copy of the app — everything else stays in the window, which is
/// one click away and where it belongs.
struct MenuBarControls: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(engine.isRunning ? "Pause" : "Start") {
            engine.toggle()
        }
        .keyboardShortcut(.space, modifiers: [])

        Button("Skip this phase") { engine.skipPhase() }
            .disabled(!engine.isRunning)

        Divider()

        // The snow globe's replacement. There is no accelerometer in a Mac, so
        // the shake gesture has nowhere to live; it becomes a menu item rather
        // than being dropped, because the thing it does is worth keeping and
        // only the *gesture* was ever iPhone-shaped.
        Button("Give it a shake") { SceneShake.shared.shake() }

        Divider()

        Button("Open Pawmodoro") { openWindow(id: "main") }
            .keyboardShortcut("0", modifiers: .command)

        Divider()

        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
#endif
