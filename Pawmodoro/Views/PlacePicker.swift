import SwiftUI

/// The journey, laid out as somewhere to go next.
///
/// Every place is shown, including the ones still ahead — a row of postcards
/// with "12 more sessions" under them is the whole motivation of the feature,
/// and hiding them would throw that away. Two different locks live here: the
/// journey lock, which only time and focus open, and the Plus lock, which
/// behaves like every other padlock in the app and opens the paywall.
struct PlacePicker: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store

    var onLockedTap: () -> Void

    private var part: DayPart {
        LaunchOptions.forcedDayPart ?? DayPart.current()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Place.journey) { place in
                    tile(for: place)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }

    private func tile(for place: Place) -> some View {
        let reached = engine.hasReached(place)
        let owned = store.isUnlocked(place)
        let available = reached && owned
        let selected = engine.settings.place == place

        return Button {
            if available {
                engine.settings.place = place
            } else if reached, !owned {
                onLockedTap()
            } else {
                // Still ahead of you: there's nothing to buy, only sessions to
                // finish, so say nothing and just decline.
                HapticsDirector.shared.nudge()
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(place.assetName(for: part))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 78, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(available ? 1 : 0.45)
                        .grayscale(available ? 0 : 0.75)

                    if !owned {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.onAccent)
                            .padding(4)
                            .background(Circle().fill(Theme.blossom))
                            .offset(x: 5, y: -3)
                    }
                }

                Text(place.name)
                    .font(.caption2.weight(selected ? .bold : .regular))
                    .foregroundStyle(Theme.bark.opacity(available ? 0.9 : 0.55))
                    .lineLimit(1)

                Text(caption(for: place, reached: reached, owned: owned))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.bark.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(width: 92)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Theme.blossom.opacity(0.28) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Theme.blossom : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.squishy(pressedScale: 0.94))
        .accessibilityLabel(accessibilityLabel(for: place, reached: reached, owned: owned))
    }

    private func caption(for place: Place, reached: Bool, owned: Bool) -> String {
        if !reached {
            let remaining = engine.sessionsRemaining(to: place)
            return remaining == 1 ? "1 more session" : "\(remaining) more sessions"
        }
        return owned ? place.blurb : "Pawmodoro Plus"
    }

    private func accessibilityLabel(for place: Place, reached: Bool, owned: Bool) -> String {
        if !reached {
            return "\(place.name), locked, "
                + "\(engine.sessionsRemaining(to: place)) more focus sessions to reach it"
        }
        return owned
            ? "\(place.name). \(place.blurb)"
            : "\(place.name), locked, requires Pawmodoro Plus"
    }
}
