import SwiftUI

@main
struct PawmodoroApp: App {
    @State private var engine = TimerEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engine)
                .fontDesign(.rounded)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-sync the countdown after the app was suspended in the background.
            if newPhase == .active {
                engine.syncAfterWake()
            }
        }
    }
}
