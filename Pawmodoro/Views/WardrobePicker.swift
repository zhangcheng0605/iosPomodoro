import SwiftUI

/// What the buddy is wearing, and what it could be.
///
/// Sits under the buddy's name in Settings, because that is where you already
/// go to decide who you are sitting with. Two rows, one per slot, and the
/// first tile in each is *nothing* — taking a hat off has to be as easy as
/// putting one on, or the wardrobe becomes a thing you have to manage.
///
/// Padlocked, never hidden: everything is drawn at full size with its price,
/// and tapping a locked piece opens the unlock sheet like every other lock in
/// the app.
struct WardrobePicker: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store

    /// Passed the catalogue entry for a locked piece. Never nil here — the
    /// free accessories are never locked, and everything else in the wardrobe
    /// is for sale — but the signature matches the other pickers so one
    /// handler in `SettingsView` serves them all.
    var onLockedTap: (CatalogItem?) -> Void

    /// How wide one tile is, and the whole of why the names read.
    ///
    /// The row was built at 58 points with a one-line label, which truncated
    /// every long name to about ten characters — "The knitt…", "Round sp…",
    /// "The dark…", "The red b…" — on both platforms, in a row that scrolls
    /// and therefore had width to spare. Measured at caption2's 11 points, the
    /// names need up to **97.2** points on one line ("A crown of flowers") but
    /// only **58.8** on two ("The knitted cap" → "The knitted" / "cap"), and no
    /// single word is wider than 56.7 ("spectacles"). So the fix is not a much
    /// bigger tile: it is the second line, plus enough width to hold the widest
    /// two-line break clear of the tile's edges. 70 − 8 of label padding leaves
    /// 62 points of text, which clears 58.8 with room for the semibold weight.
    ///
    /// `@ScaledMetric` because the number is only true relative to the font: at
    /// an accessibility size an unscaled 70 would truncate again, and this way
    /// the tile grows with the label and every name still breaks in two.
    @ScaledMetric(relativeTo: .caption2) private var tileWidth: CGFloat = 70
    /// The art scales with it, or a tile at the top text size is a 217-point
    /// box with a 42-point picture adrift in the middle of it.
    @ScaledMetric(relativeTo: .caption2) private var artWidth: CGFloat = 42
    @ScaledMetric(relativeTo: .caption2) private var artHeight: CGFloat = 30

    private var buddy: Buddy { engine.settings.buddy }

    var body: some View {
        ForEach(Accessory.Slot.allCases) { slot in
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.6))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        bareTile(slot)
                        ForEach(Accessory.items(in: slot)) { accessory in
                            tile(accessory, in: slot)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    /// Wearing nothing, as a first-class choice rather than a long-press or a
    /// tap-the-selected-one-again gesture nobody would find.
    private func bareTile(_ slot: Accessory.Slot) -> some View {
        let selected = engine.settings.worn(slot, on: buddy) == nil
        return Button {
            engine.wear(nil, in: slot)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "slash.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.bark.opacity(0.35))
                    .frame(width: artWidth, height: artHeight)
                Text("None")
                    .font(.caption2)
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    // Reserved rather than merely allowed: "None" is one line
                    // and its neighbours are two, and without the reservation
                    // this tile would sit a line short of the row it is in.
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .frame(width: tileWidth)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Theme.blossom.opacity(0.28) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func tile(_ accessory: Accessory, in slot: Accessory.Slot) -> some View {
        let unlocked = store.isUnlocked(byPurchase: .accessory(accessory))
        let selected = engine.settings.worn(slot, on: buddy) == accessory

        return Button {
            if unlocked {
                engine.wear(accessory, in: slot)
            } else {
                onLockedTap(.accessory(accessory))
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(accessory.asset)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: artWidth, height: artHeight)
                        .opacity(unlocked ? 1 : 0.4)
                        .grayscale(unlocked ? 0 : 0.8)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.onAccent)
                            .padding(3)
                            .background(Circle().fill(Theme.blossom))
                            .offset(x: 6, y: -4)
                    }
                }
                Text(unlocked ? accessory.name : "\(CatalogItem.accessory(accessory).price)")
                    .font(.caption2)
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 0.8 : 0.5))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .frame(width: tileWidth)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Theme.blossom.opacity(0.28) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            unlocked
                ? "\(accessory.name)\(selected ? ", worn" : "")"
                : "\(accessory.name), locked, \(CatalogItem.accessory(accessory).price) acorns"
        )
    }
}
