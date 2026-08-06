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
        WindowGroup {
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
    }
}
