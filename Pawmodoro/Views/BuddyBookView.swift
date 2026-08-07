import SwiftUI

/// The buddy book: one dossier per buddy, assembled entirely from what the
/// app already knows — the Usagi Shima BunBook loop, run on real history.
/// Nothing here is stored; blank lines say "still finding out", never
/// "0 of n".
struct BuddyBookSheet: View {
    let buddy: Buddy

    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var sharingPapers = false

    private var name: String { engine.settings.displayName(for: buddy) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PapersCard(buddy: buddy)

                    Button {
                        sharingPapers = true
                    } label: {
                        Label("Share the papers", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    factsCard
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("The buddy book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $sharingPapers) {
                ShareableCardSheet(title: "\(name)'s papers") {
                    PapersCard(buddy: buddy)
                }
            }
        }
    }

    // MARK: What is known

    private var factsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(facts, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.blossom)
                        .padding(.top, 4)
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(Theme.bark.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
    }

    private var facts: [String] {
        var lines: [String] = []

        let together = engine.log.records.filter { $0.buddy == buddy.rawValue }.count
        if together > 0 {
            lines.append("\(together) session\(together == 1 ? "" : "s") kept company, "
                + "since the notes got good.")
        }
        // The quirk, stated as fact — it is one.
        lines.append(quirkLine)

        // Tastes, as discovered — never as a checklist.
        let lovesKnown = engine.pantry.hasTried(buddy, buddy.favoriteSnack)
        let snubKnown = engine.pantry.hasTried(buddy, buddy.snubbedSnack)
        if lovesKnown {
            lines.append("Loves \(buddy.favoriteSnack.plural).")
        }
        if snubKnown {
            lines.append("\(buddy.snubbedSnack.plural.capitalized): no. Noted, respected.")
        }
        if !lovesKnown && !snubKnown {
            lines.append("Tastes: still finding out.")
        }

        // The repertoire, at whatever stage it truly is.
        for trick in Trick.allCases {
            let tier = engine.repertoire.tier(buddy, trick)
            if tier >= Repertoire.masteredTier {
                lines.append("Has \(trick.name), for good.")
            } else if tier > 0 {
                lines.append("Working on \(trick.name). Sleeping on it, mostly.")
            }
        }

        // The travel record, from the letters that came home.
        let letters = engine.travels.mailbox.filter { $0.buddy == buddy.rawValue }
        if let latest = letters.last,
           let place = Place(rawValue: latest.place) {
            lines.append("\(letters.count) little journey\(letters.count == 1 ? "" : "s") — "
                + "most recently \(place.name).")
        }

        if engine.fives.preempts {
            lines.append("Raises the paw before the chime now. Has learned you'll be there.")
        }
        return lines
    }

    /// One line per buddy, data like every quirk.
    private var quirkLine: String {
        switch buddy {
        case .cat: "Sleeps like it's a craft. It is."
        case .dog: "The whole back half wags. Structural."
        case .penguin: "Does not sit. Has never sat. Will not start."
        case .bunny: "Both ears run independent operations."
        case .hamster: "Everything worth having fits in a cheek."
        case .fox: "Named after a fruit. Has made peace with it."
        case .capybara: "Soaks on breaks. The onsen is the whole point."
        case .redpanda: "Celebrates with both arms. No exceptions."
        case .owl: "Works nights. Keeps your watch when you keep hers."
        case .otter: "Owns one pebble. It is the correct pebble."
        case .hedgehog: "A perfect ball under pressure. Relatable."
        case .stray: "Came in from the hedge on her own terms. Kept them."
        }
    }
}

/// The adoption papers: the certificate block, in the postcard language,
/// exportable. Soot's say what only hers can.
struct PapersCard: View {
    let buddy: Buddy

    @Environment(TimerEngine.self) private var engine

    private var name: String { engine.settings.displayName(for: buddy) }

    var body: some View {
        VStack(spacing: 10) {
            Text("THE PAPERS")
                .font(.caption2.weight(.bold))
                .tracking(3)
                .foregroundStyle(Theme.bark.opacity(0.45))

            BuddySprite(buddy: buddy, sleeping: false, size: 72)

            Text(name)
                .font(.title3.bold())
                .foregroundStyle(Theme.bark)

            if name != buddy.name {
                Text("born \(buddy.name), renamed with cause")
                    .font(.caption2)
                    .foregroundStyle(Theme.bark.opacity(0.55))
            }

            Text(buddy.kind)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.65))

            Rectangle()
                .fill(Theme.bark.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 24)

            Text(originLine)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.surface.opacity(0.85))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name)'s papers. \(originLine)")
    }

    private var originLine: String {
        if buddy == .stray {
            return "Arrived on her own recognizance. Twelve days in the hedge. "
                + "Stays because she decided to."
        }
        let first = engine.log.records.first { $0.buddy == buddy.rawValue }
        if let first {
            let day = first.endedAt.formatted(.dateTime.month(.wide).day().year())
            return "First session together: \(day). "
                + "Home turf: \(buddy.homePlace.name)."
        }
        return "Together since before the notes got good. "
            + "Home turf: \(buddy.homePlace.name)."
    }
}
