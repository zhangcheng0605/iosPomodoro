import SwiftUI

/// What a padlock opens.
///
/// One sheet, reused by every locked thing in the app, and the whole of the
/// era's commercial argument lives in its shape: the thing, its price, how far
/// away it is — and then, under a rule line, *"Or everything, at once."*
/// Every padlock is a Plus advertisement with an honest free road attached,
/// which is exactly why the free road has to stay honest. A distance that
/// nudged, a price that moved, a countdown on the offer, and the sheet would
/// stop being trustworthy and start being a funnel; the fences in
/// `docs/HEARTH_PLAN.md` are what keep it the first thing.
///
/// Two rules it must never break:
///
/// - **The distance is an observation, not a target.** "About a week of
///   afternoons away" is a fact about a wood; "6 more sessions!" is homework.
///   Same distinction the grove's next-tree line is built on, and the reason
///   there is no progress bar anywhere on this sheet.
/// - **Nothing is ever hurried.** No countdown, no sale, no "today only". The
///   price on this sheet is the price next month.
struct UnlockSheet: View {
    let item: CatalogItem

    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    /// Set the moment a trade goes through, so the sheet can say something
    /// before it closes. It is the only congratulation in the economy and it
    /// congratulates the *thing*, not the spending.
    @State private var traded = false

    private var owned: Bool { engine.pouch.owns(item) }
    private var affordable: Bool { engine.acorns >= item.price }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    portrait
                    Text(item.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.bark)
                    priceRow
                    if let line = distanceLine {
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    tradeButton
                    plusRoad
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: The thing itself

    /// Drawn as it will actually look, not as an icon. A place shows its
    /// scene, a buddy shows its sprite, a theme shows its own colours — the
    /// point of the sheet is to want the thing, and a row in a list has never
    /// made anybody want anything.
    @ViewBuilder
    private var portrait: some View {
        switch item {
        case .buddy(let buddy):
            BuddySprite(buddy: buddy, sleeping: false, size: 120)
        case .place(let place):
            Image(place.assetName(for: .day))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        case .theme(let theme):
            // Each theme's own palette, read directly, so the preview is the
            // theme rather than whatever is currently active — the same thing
            // `ThemePicker.swatch` does and for the same reason.
            HStack(spacing: 0) {
                Rectangle().fill(theme.palette.blossom.color)
                Rectangle().fill(theme.palette.sage.color)
                Rectangle().fill(theme.palette.sunshine.color)
                Rectangle().fill(theme.palette.cream.color)
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var priceRow: some View {
        HStack(spacing: 6) {
            Image("acorn")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: 20)
            Text("\(item.price)")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.bark)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.price) acorns")
    }

    /// How far off it is, in afternoons.
    ///
    /// Nil once it is affordable — there is nothing to say then, and a sheet
    /// that keeps talking about distance after you have arrived is nagging.
    /// Deliberately vague at the far end: "a long way off yet" rather than
    /// "1,240 minutes", because a precise number invites arithmetic and the
    /// arithmetic is the part that feels like a grind.
    private var distanceLine: String? {
        guard !owned, let minutes = engine.minutesUntil(item.price) else { return nil }
        let sessions = max(1, minutes / max(1, engine.settings.focusMinutes))
        switch sessions {
        case 1: return "About one more sit."
        case 2...5: return "About \(sessions) more sits."
        case 6...20: return "About a week of afternoons away."
        case 21...60: return "A few weeks of afternoons away."
        default: return "A long way off yet. It keeps."
        }
    }

    @ViewBuilder
    private var tradeButton: some View {
        if owned {
            Label(traded ? "It's yours" : "Already yours", systemImage: "checkmark")
                .font(.headline)
                .foregroundStyle(Theme.bark.opacity(0.7))
                .padding(.vertical, 12)
        } else {
            Button {
                // The engine's own minutes, so the pouch checks the sums
                // itself rather than trusting a view to have got them right.
                if engine.trade(item) { traded = true }
            } label: {
                Text("Trade")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(affordable ? Theme.blossom : Theme.surface)
            )
            .foregroundStyle(affordable ? Theme.onAccent : Theme.bark.opacity(0.4))
            .disabled(!affordable)
        }
    }

    /// The other road, on every single padlock in the app.
    ///
    /// Under a rule line and in a quieter voice than the Trade button: it is
    /// an alternative, not the recommendation. An app that shouts this louder
    /// than the thing you came to look at has stopped selling the thing.
    @ViewBuilder
    private var plusRoad: some View {
        if !store.hasPlus {
            VStack(spacing: 10) {
                Divider().padding(.vertical, 4)
                Text("Or everything, at once.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.bark.opacity(0.8))
                Text("Plus opens the whole cart, now and whatever it gains later.")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.55))
                    .multilineTextAlignment(.center)
                Button("See Plus") { showPaywall = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.blossom)
            }
        }
    }
}
