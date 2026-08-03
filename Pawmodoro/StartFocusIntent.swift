import AppIntents
import Foundation
import Observation

/// The one thing outside the app that can reach into it.
///
/// Nothing is passed and nothing is returned — the intent's whole job is to
/// say "start", which is why it can be this small. It writes a flag that
/// `ContentView` picks up once the app is on screen, rather than touching the
/// engine directly: the engine is built by the app's `init`, and an intent can
/// fire before that has happened on a cold launch.
@Observable
final class IntentBridge {
    static let shared = IntentBridge()

    /// Set by the intent, cleared by whoever acts on it.
    var wantsFocus = false

    private init() {}
}

/// "Press the side button and the boat sails."
///
/// `openAppWhenRun` because the whole product is the thing on screen — a timer
/// that ran invisibly in the background would be a different, worse app.
struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a focus session"
    static var description = IntentDescription(
        "Starts a Pawmodoro focus session, and your buddy settles down for it."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.shared.wantsFocus = true
        return .result()
    }
}

/// What puts it on the Action Button, in Shortcuts, and in Siri.
///
/// Every phrase has to contain `\(.applicationName)` — Apple rejects the
/// shortcut outright otherwise, and the failure is a runtime one, so it is
/// worth being careful about here rather than finding out on a device.
struct PawmodoroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start a focus session in \(.applicationName)",
                "Start focusing with \(.applicationName)",
                "Begin a \(.applicationName) session",
            ],
            shortTitle: "Start focus",
            systemImageName: "play.fill"
        )
    }
}
