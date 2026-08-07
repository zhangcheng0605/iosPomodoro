import StoreKit
import SwiftUI

/// Optional tips. These unlock nothing — they're a way to say thanks.
struct TipJarView: View {
    @Environment(StoreManager.self) private var store
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BuddySprite(buddy: engine.settings.buddy, sleeping: false, size: 96)

                    VStack(spacing: 6) {
                        Text("Tip jar")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.bark)
                        Text("Tips unlock nothing at all. They keep "
                             + "\(engine.buddyName) in treats — and me making "
                             + "this app better for you.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.bark.opacity(0.75))
                            .multilineTextAlignment(.center)
                        Text("Every new place, sound and small creature so far "
                             + "was built in the evenings. A tip is how one "
                             + "more of them gets built.")
                            .font(.footnote)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    if store.tipsGiven > 0 {
                        Text(thanksMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.blossom)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    tipButtons

                    if let error = store.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .background(Theme.background(for: .shortBreak).ignoresSafeArea())
            .navigationTitle("Tip jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.bark)
                }
            }
            .task { await store.loadProducts() }
        }
    }

    private var thanksMessage: String {
        store.tipsGiven == 1
            ? "Thank you for the tip 💛"
            : "Thank you for \(store.tipsGiven) tips 💛"
    }

    @ViewBuilder
    private var tipButtons: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView().padding()
        case .failed(let message):
            VStack(spacing: 8) {
                Text("The tip jar isn't available right now.")
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
            if store.tipProducts.isEmpty {
                Text("Tips aren't available in your region yet.")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.7))
            } else {
                VStack(spacing: 10) {
                    ForEach(store.tipProducts, id: \.id) { product in
                        tipButton(for: product)
                    }
                }
            }
        }
    }

    private func tipButton(for product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack {
                Text(product.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if store.purchasingProductID == product.id {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.bold))
                }
            }
            .foregroundStyle(Theme.bark)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.8)))
        }
        .disabled(store.purchasingProductID != nil)
    }
}

#Preview {
    TipJarView()
        .environment(StoreManager())
        .environment(TimerEngine())
        .fontDesign(.rounded)
}
