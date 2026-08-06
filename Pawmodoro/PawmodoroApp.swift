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
        }
        #if os(macOS)
        // Phone-proportioned, and resizable only within bounds that keep the
        // art honest: every scene is exported at a phone's aspect, and the
        // buddy, the stray and the snail are placed by fractions of the
        // screen. A wide window would slide the ground line out from under
        // the cat — `check_stray.py` carries this aspect as a fixture row.
        .defaultSize(Platform.macWindow)
        .windowResizability(.contentSize)
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // The app may have been suspended for hours; recompute from the
                // stored end date and finish the phase if it already elapsed.
                engine.syncAfterWake()
                engine.refreshAmbience()
                MusicPlayer.shared.resumeIfNeeded()
            case .background, .inactive:
                // iOS tears the audio engine down anyway; letting it idle in
                // the background is what gets an app looked at twice.
                MusicPlayer.shared.suspend()
            @unknown default:
                break
            }
        }

        #if os(macOS)
        menuBar
        #endif
    }

    #if os(macOS)
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
