import StoreKit
import SwiftUI

/// The Pawmodoro Plus unlock. A one-time purchase, no subscription.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showRedeem = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    buddyShowcase
                    features
                    purchaseArea
                    footnote
                }
                .padding()
            }
            .background(Theme.background(for: .focus).ignoresSafeArea())
            .navigationTitle("Pawmodoro Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.bark)
                }
            }
            .task { await store.loadProducts() }
            #if DEBUG
            .sheet(isPresented: $showRedeem) { RedeemCodeView() }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("A bigger, cozier den")
                .font(.title2.bold())
                .foregroundStyle(Theme.bark)
            Text("Fifty tracks, seven more buddies, four far isles, six more themes.")
                .font(.subheadline)
                .foregroundStyle(Theme.bark.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var buddyShowcase: some View {
        // Six Plus buddies no longer fit across a phone, so the row scrolls
        // rather than shrinking each of them into illegibility.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Buddy.allCases.filter(\.isPlus)) { buddy in
                    VStack(spacing: 4) {
                        BuddySprite(buddy: buddy, sleeping: false, size: 68)
                        Text(buddy.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.8))
                    }
                    .frame(width: 78)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.65)))
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature(
                icon: "pawprint.fill",
                title: "Eleven buddies in total",
                // Tofu is no longer named here: the capybara ships free and is
                // what a new install opens on, so selling it back would be
                // the paywall taking credit for something already given.
                detail: "Luna the owl keeps watch at night, Pip the otter floats on his back holding a pebble, Momo the bunny binkies clean off the ground, and Bramble the hedgehog sleeps as a perfect ball."
            )
            feature(
                icon: "speaker.wave.2.fill",
                // Deliberately no longer "all fifty": the catalogue is
                // sixty-five and three of its mixtapes are not for sale at any
                // price. Claiming the whole shelf here would be the paywall
                // taking credit for the things it cannot give you.
                //
                // And no longer "layers a sound under a track": layering is
                // free and always has been in practice. The paywall sells the
                // *balance* between the two channels, not their coexistence —
                // see `TimerEngine.applyEntitlement(hasPlus:)`.
                title: "The Sound Almanac",
                detail: "Fifty lo-fi tracks the moment you \(Pointing.tap), the mixer that sets the balance between a sound and a track, and radio — which picks for you, matched to where you are and the hour."
            )
            feature(
                icon: "paintpalette.fill",
                title: "Eight themes",
                detail: "Matcha, Cocoa, Midnight, Ember, Lavender and Ink join Sakura and Snowdrift — each with its own light and dark look."
            )
            feature(
                icon: "checkmark.seal.fill",
                title: "Yours for good",
                detail: "One payment, no subscription, and it follows your Apple Account."
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
    }

    private func feature(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.blossom)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var purchaseArea: some View {
        if store.hasPlus {
            VStack(spacing: 8) {
                Text("💛")
                    .font(.system(size: 40))
                Text("You have Pawmodoro Plus")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                Text("Thank you — genuinely.")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 12) {
                switch store.loadState {
                case .idle, .loading:
                    ProgressView()
                        .frame(height: 54)
                case .failed(let message):
                    VStack(spacing: 8) {
                        Text("The store isn't available right now.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.bark)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            Task { await store.loadProducts() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blossom)
                    }
                case .loaded:
                    if let product = store.plusProduct {
                        buyButton(for: product)
                    } else {
                        Text("Pawmodoro Plus isn't available in your region yet.")
                            .font(.footnote)
                            .foregroundStyle(Theme.bark.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }

                Button("Restore purchase") {
                    Task { await store.restore() }
                }
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.75))

                // Somebody staring at a locked screen is exactly who has been
                // handed a code, so it is offered here — quietly, in the
                // smallest type on the sheet, below the two things most
                // people came for.
                // DEBUG only — see the note in SettingsView. Guideline
                // 3.1.1 forbids a self-issued unlock, and a paywall is the
                // worst possible place for a reviewer to find one.
                #if DEBUG
                Button("I have a code") { showRedeem = true }
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.6))
                #endif

                if let error = store.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func buyButton(for product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            Group {
                if store.purchasingProductID == product.id {
                    ProgressView()
                } else {
                    Text("Unlock for \(product.displayPrice)")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(Theme.blossom))
            .foregroundStyle(Theme.onAccent)
        }
        .disabled(store.purchasingProductID != nil)
    }

    private var footnote: some View {
        Text("A one-time purchase — there is no subscription. If you reinstall Pawmodoro or set up a new device, use Restore to get it back.")
            .font(.caption2)
            .foregroundStyle(Theme.bark.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}

#Preview {
    PaywallView()
        .environment(StoreManager())
        .fontDesign(.rounded)
}
