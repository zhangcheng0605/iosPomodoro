import SwiftUI

struct SettingsView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var showTipJar = false
    @State private var showCart = false
    /// The locked thing somebody just tapped, if the cart sells it.
    @State private var unlocking: CatalogItem?

    /// What a padlock does, everywhere in this screen.
    ///
    /// Something the cart sells opens the unlock sheet, which shows the price
    /// *and* the Plus road. Anything else — ambience, today — still goes
    /// straight to the paywall, because there is no acorn road to offer and
    /// pretending otherwise would be worse than the padlock.
    private func lockedTap(_ item: CatalogItem?) {
        if let item { unlocking = item } else { showPaywall = true }
    }

    var body: some View {
        @Bindable var engine = engine

        NavigationStack {
            Form {
                Section {
                    BuddyPicker(onLockedTap: lockedTap)
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField(
                            engine.settings.buddy.name,
                            text: Binding(
                                get: { engine.settings.buddyNames[engine.settings.buddy.rawValue] ?? "" },
                                set: { engine.settings.setName($0, for: engine.settings.buddy) }
                            )
                        )
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                    }
                    WardrobePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Your buddy")
                } footer: {
                    Text("Leave the name blank to go back to \(engine.settings.buddy.name). "
                         + "What they wear is remembered per buddy.")
                }

                Section {
                    PlacePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Where you are")
                } footer: {
                    Text("Finish focus sessions to travel further. Places you reach stay yours.")
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
                    AmbiencePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Ambience")
                } footer: {
                    Text("Ambient sound plays while the timer is running, and pauses when the app is closed.")
                }

                Section("Theme") {
                    ThemePicker(onLockedTap: lockedTap)
                }

                Section("The cabinet of clocks") {
                    ClockFacePicker()
                }

                Section {
                    Toggle("Auto-start next phase", isOn: $engine.settings.autoStartNextPhase)
                    Toggle("Haptics", isOn: $engine.settings.hapticsEnabled)
                    Toggle("Breathing ring on breaks", isOn: $engine.settings.breatheOnBreaks)
                    Toggle("Settle in before focus", isOn: $engine.settings.settleInBeforeFocus)
                    Toggle("Lock screen countdown", isOn: $engine.settings.liveActivityEnabled)
                } header: {
                    Text("Behaviour")
                } footer: {
                    Text("Settling in takes three slow breaths before the "
                         + "countdown starts. Tap anywhere to skip it. The lock "
                         + "screen countdown is drawn by the system, so it costs "
                         + "no battery.")
                }

                cartSection
                plusSection

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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(item: $unlocking) { UnlockSheet(item: $0) }
            .sheet(isPresented: $showCart) { CartView() }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
        }
    }

    /// The way into the one commercial room, and the only mention of the
    /// economy anywhere outside it and the stats sheet. Never badged, never
    /// with a count on it — fence 8: the balance does not follow you around.
    private var cartSection: some View {
        Section {
            Button {
                showCart = true
            } label: {
                HStack(spacing: 10) {
                    Image("magpie_0")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 24)
                    Text("The magpie's cart")
                        .foregroundStyle(Theme.bark)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.bark.opacity(0.35))
                }
            }
            .buttonStyle(.plain)
        } footer: {
            Text("The wood drops an acorn every twenty minutes you sit. "
                 + "She trades.")
        }
    }

    @ViewBuilder
    private var plusSection: some View {
        Section("Pawmodoro Plus") {
            if store.hasPlus {
                HStack {
                    Label("Unlocked", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.blossom)
                    Spacer()
                    Text("Thank you 💛")
                        .font(.footnote)
                        .foregroundStyle(Theme.bark.opacity(0.7))
                }
                Button("See what's included") { showPaywall = true }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Unlock Pawmodoro Plus", systemImage: "sparkles")
                            .font(.body.weight(.semibold))
                        Text("Eight more buddies, sounds and themes — one payment.")
                            .font(.caption)
                            .foregroundStyle(Theme.bark.opacity(0.7))
                    }
                }
                Button("Restore purchase") {
                    Task { await store.restore() }
                }
                .font(.footnote)
            }

            Button("Leave a tip", systemImage: "heart.fill") {
                showTipJar = true
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
        .environment(StoreManager())
}
