import SwiftUI

/// The Magpie's Cart — the one room in this app where anything is for sale.
///
/// Everywhere else stays world. A padlocked buddy in the picker, a padlocked
/// place on the map: each is still a thing in its own place with a lock on it,
/// and tapping it opens `UnlockSheet`. This is where you come to *browse*, and
/// containing the browsing to one room is what stops the rest of the app
/// feeling like a shop.
///
/// She is a neighbour, not a species — nothing here touches the field journal.
/// A shopkeeper you could collect would make the storefront into another tile
/// to fill, which is the opposite of the point.
struct CartView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var opened: CatalogItem?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    magpie
                    ForEach(CatalogItem.Shelf.allCases) { shelf in
                        self.shelf(shelf)
                    }
                    everythingLine
                }
                .padding()
            }
            .sheetSize()
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("The magpie's cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $opened) { UnlockSheet(item: $0) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: The shopkeeper

    /// Two frames at the homestead's pace — she tilts her head at you and goes
    /// back to her pile. Anything faster would be a shop assistant hovering.
    ///
    /// The pouch count sits here, beside her, and that is where it belongs
    /// rather than where it used to be. It was a `.topBarLeading` toolbar item,
    /// which a Mac sheet has nowhere to put and therefore does not draw at all:
    /// on macOS you shopped without ever seeing your balance. Moving it into
    /// the content is the Scrapbook's fix again — one control, drawn by the
    /// same code on both platforms — and it reads better on the phone too,
    /// because the number you are about to spend is now next to the person you
    /// are about to spend it with.
    private var magpie: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TimelineView(.periodic(from: .now, by: Self.frameSeconds)) { context in
                Image(Self.frame(at: context.date) == 0 ? "magpie_0" : "magpie_1")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 50)
            }
            .accessibilityHidden(true)
            Image("cart_1")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 54)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                pouchLabel
                Text(greeting)
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    /// Slower than the homestead's neighbours, which is the point: she looks
    /// up every second and a half and otherwise ignores you.
    private static let frameSeconds: TimeInterval = 1.5

    private static func frame(at date: Date) -> Int {
        let steps = date.timeIntervalSinceReferenceDate / frameSeconds
        return Int(steps.rounded(.down)) % 2
    }

    /// She never sells. She describes her pile and lets you get on with it —
    /// which is also the only tone that can survive being read a hundred
    /// times.
    private var greeting: String {
        if store.hasPlus { return "You have the run of it. She doesn't mind." }
        if engine.pouch.hasEverything { return "Nothing left she'd part with." }
        return "She found all of this. She is willing to discuss it."
    }

    private var pouchLabel: some View {
        HStack(spacing: 4) {
            Image("acorn")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: 16)
            Text("\(engine.acorns)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.bark)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(engine.acorns) acorns in the pouch")
    }

    // MARK: The shelves

    private func shelf(_ shelf: CatalogItem.Shelf) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shelf.title)
                .font(.headline)
                .foregroundStyle(Theme.bark)
            Text(shelf.blurb)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))
            ForEach(CatalogItem.items(on: shelf)) { item in
                row(for: item)
            }
        }
    }

    /// Everything is shown, always, with its price on it — padlocked, never
    /// hidden, which is the oldest rule in this app and the one an economy is
    /// most tempted to break. There is no "coming soon", no blurred silhouette
    /// and no count of how many you are missing.
    private func row(for item: CatalogItem) -> some View {
        let owned = store.isUnlocked(byPurchase: item)
        let affordable = engine.acorns >= item.price

        return Button {
            opened = item
        } label: {
            HStack(spacing: 12) {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.bark.opacity(owned ? 0.9 : 0.75))
                Spacer(minLength: 8)
                if owned {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blossom)
                } else {
                    HStack(spacing: 4) {
                        Image("acorn")
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)
                        Text("\(item.price)")
                            .font(.subheadline.monospacedDigit())
                    }
                    // Dimmed rather than hidden or disabled when it is out of
                    // reach: you can still open it, look at it, and find out
                    // how far off it is. A price you cannot even tap is a
                    // wall, and this is meant to be a window.
                    .foregroundStyle(Theme.bark.opacity(affordable ? 0.9 : 0.45))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface.opacity(owned ? 0.9 : 0.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            owned ? "\(item.name), yours"
                  : "\(item.name), \(item.price) acorns"
        )
    }

    /// The one place the whole hoard is priced, and the quietest possible way
    /// to make the argument for Plus: here is the number, work it out.
    @ViewBuilder
    private var everythingLine: some View {
        if !store.hasPlus {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                Text("The lot comes to \(CatalogItem.everything) acorns.")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.6))
                Button("Or everything, at once — Plus") { showPaywall = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.blossom)
            }
            .padding(.top, 6)
        }
    }
}
