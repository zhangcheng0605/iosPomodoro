import SwiftUI

/// The see-off desk: every owned, off-duty buddy, and where each one is.
///
/// Lives in Settings beside the buddy picker. A row is either home — with a
/// menu of unlocked places to be seen off to — or away, showing only where.
/// Never when: the return time exists and is nobody's business.
struct JourneyRoster: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store

    /// Owned and off-duty: the roster minus the one keeping you company.
    private var offDuty: [Buddy] {
        Buddy.roster(strayJoined: engine.stray.hasJoined)
            .filter { $0 != engine.settings.buddy && store.isUnlocked($0) }
    }

    private var destinations: [Place] {
        Place.journey.filter { engine.hasReached($0) && (!$0.isPlus || store.hasPlus) }
    }

    var body: some View {
        ForEach(offDuty) { buddy in
            row(for: buddy)
        }
    }

    @ViewBuilder
    private func row(for buddy: Buddy) -> some View {
        let name = engine.settings.displayName(for: buddy)
        HStack(spacing: 10) {
            BuddySprite(buddy: buddy, sleeping: false, size: 34)
                .opacity(engine.travels.isAway(buddy) ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline)
                if let journey = engine.travels.journey(for: buddy),
                   let place = Place(rawValue: journey.destination) {
                    Text("away — \(place.name)")
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.55))
                } else {
                    Text("home")
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.55))
                }
            }
            Spacer()
            if !engine.travels.isAway(buddy) {
                Menu {
                    ForEach(destinations) { place in
                        Button(place.name) {
                            engine.sendOnJourney(buddy, to: place)
                        }
                    }
                } label: {
                    Text("See off")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            engine.travels.isAway(buddy)
                ? "\(name), away on a little journey"
                : "\(name), home. See off on a little journey."
        )
    }
}

/// The mailbox: every letter that ever came home, newest first.
struct MailboxView: View {
    @Environment(TimerEngine.self) private var engine

    private static let shown = 4

    var body: some View {
        let letters = Array(engine.travels.mailbox.suffix(Self.shown).reversed())

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                Text("The mailbox")
                Spacer()
                if !engine.travels.away.isEmpty {
                    // Present tense, no clock: that's the whole Travel Frog
                    // of it.
                    Text(awayLine)
                        .foregroundStyle(Theme.bark.opacity(0.6))
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            if letters.isEmpty {
                Text("See an off-duty buddy off from Settings, and a letter "
                     + "comes home — whenever it comes home.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            } else {
                ForEach(letters) { letter in
                    letterRow(letter)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
    }

    private var awayLine: String {
        let names = engine.travels.away
            .compactMap { Buddy(rawValue: $0.buddy) }
            .map { engine.settings.displayName(for: $0) }
        return names.count == 1
            ? "\(names[0]) is out there"
            : "\(names.count) are out there"
    }

    @ViewBuilder
    private func letterRow(_ letter: Letter) -> some View {
        let buddy = Buddy(rawValue: letter.buddy)
        HStack(alignment: .top, spacing: 10) {
            if let buddy {
                BuddySprite(buddy: buddy, sleeping: false, size: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(Place(rawValue: letter.place)?.name ?? "Somewhere")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.bark.opacity(0.85))
                    Spacer()
                    Text(letter.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.bark.opacity(0.45))
                }
                Text(letter.text)
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A letter from "
            + (Place(rawValue: letter.place)?.name ?? "somewhere")
            + ": \(letter.text)")
    }
}
