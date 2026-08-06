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

    /// Passed the catalogue entry for a locked piece. Never nil here — every
    /// accessory is for sale — but the signature matches the other pickers so
    /// one handler in `SettingsView` serves them all.
    var onLockedTap: (CatalogItem?) -> Void

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
                    .frame(width: 42, height: 30)
                Text("None")
                    .font(.caption2)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            }
            .frame(width: 58)
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
                        .frame(width: 42, height: 30)
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
                    .lineLimit(1)
            }
            .frame(width: 58)
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
