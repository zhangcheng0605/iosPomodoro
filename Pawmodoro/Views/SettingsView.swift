import SwiftUI

struct SettingsView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var showTipJar = false
    @State private var showBuddyBook = false
    @State private var showCart = false
    @State private var showScrapbook = false
    @State private var showRedeem = false
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
                    Button {
                        showBuddyBook = true
                    } label: {
                        HStack {
                            Text("The buddy book")
                            Spacer()
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(Theme.blossom)
                        }
                    }
                    WardrobePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Your buddy")
                } footer: {
                    Text("Leave the name blank to go back to \(engine.settings.buddy.name). "
                         + "What they wear is remembered per buddy.")
                }

                Section {
                    JourneyRoster()
                } header: {
                    Text("Little journeys")
                } footer: {
                    Text("An off-duty buddy comes back when it comes back — "
                         + "with a letter, and something for the drawer. "
                         + "Picking a traveler for duty calls them straight home.")
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

                // Below the theme rather than inside it, and free rather than
                // Plus. The icon is on the Home screen, which is the user's
                // room and not the app's: a padlock there would put the store
                // between somebody and their own phone, to sell 60 KB of PNG.
                AppIconSection()

                Section("The cabinet of clocks") {
                    ClockFacePicker()
                }

                Section {
                    Toggle("Auto-start next phase", isOn: $engine.settings.autoStartNextPhase)
                    Toggle("Haptics", isOn: $engine.settings.hapticsEnabled)
                    Toggle("Breathing ring on breaks", isOn: $engine.settings.breatheOnBreaks)
                    Toggle("Settle in before focus", isOn: $engine.settings.settleInBeforeFocus)
                    Toggle("Lock screen countdown", isOn: $engine.settings.liveActivityEnabled)
                    Toggle("Golden hour call", isOn: $engine.settings.goldenHourCall)
                    Toggle("Bell on the hour", isOn: $engine.settings.hourBellEnabled)
                } header: {
                    Text("Behaviour")
                } footer: {
                    Text("Settling in takes three slow breaths before the "
                         + "countdown starts. Tap anywhere to skip it. The lock "
                         + "screen countdown is drawn by the system, so it costs "
                         + "no battery. The golden hour call is at most one "
                         + "quiet notification a day, when the light is good "
                         + "and the camera hasn't been used — letting it pass "
                         + "costs nothing, and is never mentioned. The bell "
                         + "marks the top of each hour while you are sitting, "
                         + "in the voice of wherever you are, and is quieter "
                         + "the later it gets.")
                }

                scrapbookSection
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
            .sheet(isPresented: $showBuddyBook) {
                BuddyBookSheet(buddy: engine.settings.buddy)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(item: $unlocking) { UnlockSheet(item: $0) }
            .sheet(isPresented: $showCart) { CartView() }
            .sheet(isPresented: $showScrapbook) { ScrapbookView() }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
            #if DEBUG
            .sheet(isPresented: $showRedeem) { RedeemCodeView() }
            #endif
        }
    }

    /// The way into the one commercial room, and the only mention of the
    /// economy anywhere outside it and the stats sheet. Never badged, never
    /// with a count on it — fence 8: the balance does not follow you around.
    /// The way into the scrapbook. In Settings beside the cart rather than on
    /// the timer, for the same reason: nothing goes between somebody and the
    /// countdown.
    private var scrapbookSection: some View {
        Section {
            Button {
                showScrapbook = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(Theme.blossom)
                        .frame(width: 22)
                    Text("Where you were")
                        .foregroundStyle(Theme.bark)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.bark.opacity(0.35))
                }
            }
            .buttonStyle(.plain)
        } footer: {
            Text("Keep a picture of wherever you are sitting. They stay on this "
                 + "device — the app has no way to send them anywhere.")
        }
    }

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

            // DEBUG ONLY, and it must stay that way. App Review guideline
            // 3.1.1 names this exact mechanism — "apps may not use their own
            // mechanisms to unlock content or functionality, such as license
            // keys…" — and Apple's rejection letter for it leads with promo
            // codes. Hiding the field instead would trade a 3.1.1 problem for
            // a 2.3.1 "hidden, dormant, or undocumented features" one, whose
            // remedy reaches removal from the developer program.
            //
            // So it is compiled out of Release entirely rather than merely
            // tucked away: the owner needs it to reach his own paid content
            // on his own phone (StoreKit vends nothing to an app installed
            // outside Xcode, so there is no other way to test what he built),
            // and it must be impossible to ship by accident.
            //
            // The sanctioned replacement, when a real code is wanted, is
            // StoreKit Offer Codes — extended to non-consumables at iOS 16.3,
            // and this app targets 17. See docs/PROMO_CODES.md.
            #if DEBUG
            Button("Redeem a code", systemImage: "ticket") {
                showRedeem = true
            }
            #endif

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
