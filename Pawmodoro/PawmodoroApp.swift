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
        _engine = State(initialValue: TimerEngine())
        _store = State(initialValue: StoreManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engine)
                .environment(store)
                .fontDesign(.rounded)
                .task {
                    await store.loadProducts()
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
            case .background, .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
