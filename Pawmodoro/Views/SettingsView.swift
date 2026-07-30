import SwiftUI

struct SettingsView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @AppStorage("buddy") private var buddyRawValue = Buddy.cat.rawValue

    var body: some View {
        @Bindable var engine = engine

        NavigationStack {
            Form {
                Section("Your buddy") {
                    Picker("Buddy", selection: $buddyRawValue) {
                        ForEach(Buddy.allCases) { buddy in
                            Text(buddy.pickerLabel).tag(buddy.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Durations") {
                    Stepper("Focus: \(engine.focusMinutes) min",
                            value: $engine.focusMinutes, in: 5...90, step: 5)
                    Stepper("Short break: \(engine.shortBreakMinutes) min",
                            value: $engine.shortBreakMinutes, in: 1...30)
                    Stepper("Long break: \(engine.longBreakMinutes) min",
                            value: $engine.longBreakMinutes, in: 5...60, step: 5)
                    Stepper("Long break every \(engine.sessionsPerLongBreak) sessions",
                            value: $engine.sessionsPerLongBreak, in: 2...8)
                }

                Section {
                    Toggle("Haptics", isOn: $engine.hapticsEnabled)
                } footer: {
                    Text("Duration changes apply to the next session. Pawmodoro stores everything on your device — no accounts, no tracking.")
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
}

#Preview {
    SettingsView()
        .environment(TimerEngine())
}
