import SwiftUI

struct SettingsView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var engine = engine

        NavigationStack {
            Form {
                Section("Your buddy") {
                    Picker("Buddy", selection: $engine.settings.buddy) {
                        ForEach(Buddy.allCases) { buddy in
                            Text(buddy.pickerLabel).tag(buddy)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Durations") {
                    Stepper(
                        "Focus: \(engine.settings.focusMinutes) min",
                        value: $engine.settings.focusMinutes, in: 5...90, step: 5
                    )
                    Stepper(
                        "Short break: \(engine.settings.shortBreakMinutes) min",
                        value: $engine.settings.shortBreakMinutes, in: 1...30
                    )
                    Stepper(
                        "Long break: \(engine.settings.longBreakMinutes) min",
                        value: $engine.settings.longBreakMinutes, in: 5...60, step: 5
                    )
                    Stepper(
                        "Long break every \(engine.settings.sessionsPerLongBreak) sessions",
                        value: $engine.settings.sessionsPerLongBreak, in: 2...8
                    )
                }

                Section {
                    Picker("Ambience", selection: $engine.settings.ambience) {
                        ForEach(Ambience.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }
                } footer: {
                    Text("Ambient sound plays while the timer is running, and pauses when the app is closed.")
                }

                Section("Behaviour") {
                    Toggle("Auto-start next phase", isOn: $engine.settings.autoStartNextPhase)
                    Toggle("Haptics", isOn: $engine.settings.hapticsEnabled)
                }

                Section {
                    Button("Restart cycle", systemImage: "arrow.triangle.2.circlepath") {
                        engine.resetCycle()
                        dismiss()
                    }
                } footer: {
                    Text("Duration changes take effect on the next session. Pawmodoro keeps everything on your device — no account, no tracking, version \(appVersion).")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .environment(TimerEngine())
}
