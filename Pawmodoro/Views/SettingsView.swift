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
    // Debug-only, like the row and the sheet it drives — see the note in
    // `PaywallView`: a stored property's *name* ships in the struct's
    // reflection metadata even when nothing reads it.
    #if DEBUG
    @State private var showRedeem = false
    #endif
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

    /// A section footer that wraps rather than truncating.
    ///
    /// On a phone a `Form` is the width of the phone and its footers wrap by
    /// themselves. In a Mac sheet the Form is as wide as the widest row in it
    /// and the footers were cut off mid-word — "…and pauses when th…", "…calls
    /// them stra…", "Thank yo…". `fixedSize(horizontal:vertical:)` is the
    /// difference: it says the height may grow to fit the text, which is what
    /// makes it wrap instead of clipping. Identical on the phone, where the
    /// text already fitted.
    /// A footer is full-width in the grouped style — unlike a *row's* label,
    /// which lives in a column and must never ask for infinite width. So the
    /// leading alignment is safe here and is not safe there; see
    /// `stepperLabel`.
    ///
    /// **The two alignments are different things, and only stating both works.**
    /// `frame(alignment:)` places the finished text *block* within the row;
    /// `multilineTextAlignment` decides how the lines sit against each other
    /// *inside* that block. This helper stated the first and not the second,
    /// which is why the Mac walk's "truncated mid-word" footers came back
    /// wrapped but ragged-left — every continuation line pushed hard against
    /// the right edge, so "…comes back — with a letter, and something" sat
    /// full width and "for the drawer. Picking a traveler…" hung off the right.
    /// A block that is leading-aligned in a full-width frame looks identical
    /// to one that is trailing-aligned when its first line happens to fill the
    /// width, which is exactly how this survived a fix that was aimed at it.
    ///
    /// The trailing default is not arbitrary: a macOS `Form` lays out labels in
    /// a right-aligned column and the footer inherits that environment. On iOS
    /// the environment is already leading, so saying it costs nothing and
    /// changes nothing there.
    private func footer(_ copy: String) -> some View {
        Text(copy)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A stepper's label, ditto.
    ///
    /// A `Stepper` built from a `String` puts its title in a single line the
    /// Mac aligns to the *trailing* edge, so the longest of the four rows lost
    /// its first characters off the left of the sheet: "Long break every 4
    /// sessions" rendered as "g break every 4 sessions". A `Text` label that is
    /// allowed to grow downwards has nowhere to be clipped.
    ///
    /// **No `maxWidth: .infinity` here.** That was tried and it destroyed the
    /// whole screen: a macOS `Form` lays labels and controls out in two
    /// columns, so a label asking for infinite width takes the entire sheet
    /// and squeezes every control into a fifteen-point gutter — the Form came
    /// out as one letter per line down the right-hand edge. Nothing on the
    /// phone can show that, because a phone's `Form` has no column layout to
    /// wreck.
    ///
    /// `multilineTextAlignment` for the same reason as `footer` — a label that
    /// is allowed to grow downwards will one day grow, and when it does the
    /// inherited trailing alignment is what decides where the second line
    /// goes. Stating it now costs nothing and removes the surprise.
    ///
    /// **Driven at last, 10 Aug 2026** — this had been written and shipped
    /// without anybody seeing it work, because the row is four sections down
    /// and a Mac sheet cannot be scrolled by a posted event. Read off the
    /// running app through both doors, Debug and Release, by scrolling the
    /// Form from its scroll bar's accessibility value and photographing the
    /// window by id:
    ///
    /// | Row | x | width |
    /// |---|---|---|
    /// | Focus: 25 min | 3600 | 84 |
    /// | Short break: 5 min | 3600 | 108 |
    /// | Long break: 15 min | 3600 | 112 |
    /// | Long break every 4 sessions | 3600 | **168** |
    ///
    /// One left margin for all four, and the longest row at its full natural
    /// width on one 16-point line. Clipped, it read "g break every 4 sessions".
    private func stepperLabel(_ copy: String) -> some View {
        Text(copy)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    var body: some View {
        @Bindable var engine = engine

        NavigationStack {
            Form {
                Section {
                    BuddyPicker(onLockedTap: lockedTap)
                    HStack {
                        Text("Name")
                        Spacer(minLength: 12)
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
                        // A `TextField` wants every point it can get, and on a
                        // phone the row is the width of the phone so that
                        // reads as "the rest of the row". In a Mac sheet the
                        // row is as wide as the widest thing in the Form and
                        // the field ran off the right edge of the sheet.
                        // Bounding it costs the phone nothing: 220 points is
                        // longer than any buddy name anybody types.
                        .frame(maxWidth: 220)
                    }
                    Button {
                        showBuddyBook = true
                    } label: {
                        HStack {
                            Text("The buddy book")
                                .foregroundStyle(Theme.bark)
                            Spacer()
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(Theme.blossom)
                        }
                    }
                    // Like the cart and the scrapbook rows below. Without it
                    // macOS draws a *bordered* button around a label that ends
                    // in a `Spacer`, which asks for infinite width and gets
                    // clipped by the sheet.
                    .buttonStyle(.plain)
                    WardrobePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Your buddy")
                } footer: {
                    footer("Leave the name blank to go back to \(engine.settings.buddy.name). "
                           + "What they wear is remembered per buddy.")
                }

                Section {
                    JourneyRoster()
                } header: {
                    Text("Little journeys")
                } footer: {
                    footer("An off-duty buddy comes back when it comes back — "
                           + "with a letter, and something for the drawer. "
                           + "Picking a traveler for duty calls them straight home.")
                }

                Section {
                    PlacePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Where you are")
                } footer: {
                    footer("Finish focus sessions to travel further. Places you reach stay yours.")
                }

                Section("Durations") {
                    Stepper(value: $engine.settings.focusMinutes,
                            in: 5...90, step: 5) {
                        stepperLabel("Focus: \(engine.settings.focusMinutes) min")
                    }
                    Stepper(value: $engine.settings.shortBreakMinutes,
                            in: 1...30) {
                        stepperLabel("Short break: \(engine.settings.shortBreakMinutes) min")
                    }
                    Stepper(value: $engine.settings.longBreakMinutes,
                            in: 5...60, step: 5) {
                        stepperLabel("Long break: \(engine.settings.longBreakMinutes) min")
                    }
                    Stepper(value: $engine.settings.sessionsPerLongBreak,
                            in: 2...8) {
                        stepperLabel("Long break every \(engine.settings.sessionsPerLongBreak) sessions")
                    }
                }

                Section {
                    AmbiencePicker(onLockedTap: lockedTap)
                } header: {
                    Text("Ambience")
                } footer: {
                    footer("Ambient sound plays while the timer is running, and pauses when the app is closed.")
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
                    footer("Settling in takes three slow breaths before the "
                         + "countdown starts. \(Pointing.Tap) anywhere to skip it. The lock "
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
                    footer("Duration changes take effect on the next session. Pawmodoro keeps everything on your device — no account, no tracking, version \(appVersion).")
                }
            }
            // The phone's `Form` is grouped and always has been; the Mac's
            // default is the two-column style, which is what put a section
            // header hard against the previous section's footer and
            // right-aligned every label. Asking for the grouped style is a
            // no-op on iOS — it is already that — and makes the Mac read like
            // the screen this is.
            .formStyle(.grouped)
            .sheetSize()
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
            footer("Keep a picture of wherever you are sitting. They stay on this "
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
            footer("The wood drops an acorn every twenty minutes you sit. "
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
                        Text("Seven more buddies, sounds and themes — one payment.")
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
