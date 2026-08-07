import SwiftUI

/// One photograph, full size, with the light it is kept in.
struct SnapshotView: View {
    let snapshot: Snapshot

    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var unlocking: CatalogItem?
    @State private var confirmingRemoval = false

    private var current: Snapshot {
        engine.scrapbook.snapshots.first { $0.id == snapshot.id } ?? snapshot
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SnapshotImage(snapshot: current, in: engine.scrapbook)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    // The stamp. Everything on it was already known — nothing
                    // here was typed in, and there is nowhere to type.
                    VStack(spacing: 3) {
                        Text(current.caption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.bark)
                        Text(current.date.formatted(.dateTime.weekday(.wide)
                                                     .day().month(.wide)))
                            .font(.footnote)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                    }

                    stocks
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Remove", role: .destructive) {
                        confirmingRemoval = true
                    }
                }
            }
            .sheet(item: $unlocking) { UnlockSheet(item: $0) }
            .confirmationDialog("Let this one go?",
                                isPresented: $confirmingRemoval,
                                titleVisibility: .visible) {
                Button("Let it go", role: .destructive) {
                    engine.scrapbook.remove(current)
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("The picture is deleted from this device. Nothing else "
                     + "about the session changes.")
            }
        }
    }

    /// Every stock, always shown, padlocked where it is not owned — the app's
    /// oldest rule, and the row where somebody first meets the cart without
    /// being sent to it.
    private var stocks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The light")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilmStock.allCases) { stock in
                        swatch(stock)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }

    private func swatch(_ stock: FilmStock) -> some View {
        let unlocked = stock.isFree
            || stock.catalogItem.map(store.isUnlocked(byPurchase:)) == true
        let selected = current.filmStock == stock

        return Button {
            if unlocked {
                engine.scrapbook.setStock(stock, on: current)
            } else if let item = stock.catalogItem {
                unlocking = item
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // The swatch previews the stock on the photograph itself,
                    // not on an abstract gradient: what somebody wants to know
                    // is what *this picture* looks like in that light.
                    SnapshotImage(snapshot: current, in: engine.scrapbook)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .filmStock(stock)
                        .opacity(unlocked ? 1 : 0.5)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.onAccent)
                            .padding(3)
                            .background(Circle().fill(Theme.blossom))
                            .offset(x: 5, y: -4)
                    }
                }
                Text(stock.name)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 0.8 : 0.5))
                    .lineLimit(1)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Theme.blossom.opacity(0.28) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked ? stock.name : "\(stock.name), locked")
    }
}
