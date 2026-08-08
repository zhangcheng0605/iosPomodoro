import SwiftUI

@main
struct PawmodoroApp: App {
    @State private var engine: TimerEngine
    @State private var store: StoreManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Before the engine and the store are built, since both read
        // UserDefaults on init and the debug launch options rewrite it.
        LaunchOptions.applyAtLaunch()
        let engine = TimerEngine()
        let store = StoreManager()
        // The two roads to the same door, introduced. `isUnlocked(_:)` stays
        // the single place that decides; it just knows about both now.
        store.pouch = engine.pouch
        _engine = State(initialValue: engine)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(engine)
                .environment(store)
                .fontDesign(.rounded)
                .task {
                    // Before the store, so `-PawmodoroDrift` lands on the
                    // first frame rather than after a network round trip.
                    engine.applyDebugDrift()
                    await store.loadProducts()
                    engine.storeHasPlus = store.hasPlus
                    engine.applyEntitlement(hasPlus: store.hasPlus)
                }
                #if os(macOS)
                // Two things a phone never had to say out loud.
                //
                // **The size.** `.defaultSize` on its own is a suggestion the
                // window ignores under `.contentSize` resizability, because
                // the content has no size opinion to resize to: this opened at
                // 400×1134 — half again as tall as any phone — and then
                // refused to be dragged back. Stating the frame is what makes
                // the window obey, and the bounds are the rule in
                // `Platform.swift` enforced rather than hoped for. The art is
                // phone-shaped, so the window stays phone-shaped.
                //
                // **The backing.** On macOS a window is only as opaque as the
                // view inside it. The bottom layer of this app is
                // `Theme.background(for:)`, whose top stop is
                // `blush.opacity(0.6)` — four-tenths see-through — and the
                // only thing covering it is the scene image. A window whose
                // opacity depends on an image having loaded is a window that
                // shows the desktop on the day it hasn't. On iOS nobody could
                // ever have noticed: there is nothing behind a full-screen app.
                .frame(
                    minWidth: Platform.macWindowMinimum.width,
                    idealWidth: Platform.macWindow.width,
                    maxWidth: Platform.macWindowMaximum.width,
                    minHeight: Platform.macWindowMinimum.height,
                    idealHeight: Platform.macWindow.height
                )
                .background(Theme.cream)
                #endif
        }
        #if os(macOS)
        .defaultSize(Platform.macWindow)
        .windowResizability(.contentSize)
        .commands { sessionCommands }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // The app may have been suspended for hours; recompute from the
                // stored end date and finish the phase if it already elapsed.
                engine.syncAfterWake()
                engine.refreshAmbience()
                MusicPlayer.shared.resumeIfNeeded()
                AmbienceLoop.shared.resumeIfNeeded()
            case .background, .inactive:
                // iOS tears the audio engine down anyway; letting it idle in
                // the background is what gets an app looked at twice.
                MusicPlayer.shared.suspend()
                AmbienceLoop.shared.suspend()
            @unknown default:
                break
            }
        }

        #if os(macOS)
        menuBar
        #endif
    }

    #if os(macOS)
    /// The three things you do to a running session, on the keyboard.
    ///
    /// The same three the menu bar extra offers, calling the same methods —
    /// a Mac gets extra *ways in*, never a second implementation. Notably
    /// `SceneShake.shared.shake()`, which is the snow globe: there is no
    /// accelerometer here, and this is where the gesture lands instead.
    ///
    /// No Space bar. It is the obvious shortcut and it is wrong: the buddy can
    /// be renamed from Settings, and a menu command on a bare Space swallows
    /// the space bar inside that text field.
    @CommandsBuilder
    private var sessionCommands: some Commands {
        // "New Window" is deliberately left alone. Emptying that group takes
        // the whole File menu with it, and File is where ⌘W lives — a Mac
        // window that cannot be closed from the keyboard is a worse trade
        // than a second window. A second window is harmless anyway: the
        // engine is one object held by the app, so both show the same
        // countdown rather than two.
        CommandMenu("Session") {
            Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
                .keyboardShortcut(.return, modifiers: .command)

            Button("Skip This Phase") { engine.skipPhase() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!engine.isRunning)

            Divider()

            Button("Give It a Shake") { SceneShake.shared.shake() }
                .keyboardShortcut("k", modifiers: .command)
        }
    }

    /// The Mac's actual reason to exist: the window can be closed entirely and
    /// the session keeps running.
    ///
    /// `.menuBarExtraStyle(.menu)` rather than `.window`, because this is a
    /// glance and a keystroke — a second floating copy of the app would be a
    /// worse version of the window that is already one click away.
    @SceneBuilder
    private var menuBar: some Scene {
        MenuBarExtra {
            MenuBarControls()
                .environment(engine)
                .environment(store)
        } label: {
            MenuBarBuddy()
                .environment(engine)
        }
        .menuBarExtraStyle(.menu)
    }
    #endif
}
