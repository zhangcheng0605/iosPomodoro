import SwiftUI

/// What you've seen, and what you haven't.
///
/// The unseen half is the point. A silhouette with "At dawn, in Whispering
/// Woods" under it is a reason to focus at a different hour, in a different
/// place — which is the whole retention argument for the journal, and it only
/// works if the locked entries are shown rather than hidden. Same house rule
/// as the padlocks, for a different reason.
struct JournalView: View {
    @Environment(TimerEngine.self) private var engine
    /// Read for one reason: the unseen silhouette's weight. See
    /// `Palette.silhouetteOpacityLight`.
    @Environment(\.colorScheme) private var colorScheme

    private var journal: Journal { engine.journal }

    /// How strongly a not-yet-seen silhouette is drawn. Two values, because
    /// the tile behind it is near-white one way up and near-black the other,
    /// and one number lands them at very different contrast.
    private var silhouetteOpacity: Double {
        colorScheme == .dark
            ? Palette.silhouetteOpacityDark
            : Palette.silhouetteOpacityLight
    }

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Field journal")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                Spacer()
                Text("\(journal.seenCount) of \(journal.total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    .monospacedDigit()
            }

            Text("Hold still and things come out. Finish the session to keep the sighting.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            ForEach(Journal.pages) { page in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(page.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.8))
                        Spacer()
                        Text("\(seen(in: page)) / \(page.species.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.bark.opacity(0.5))
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(page.species) { species in
                            tile(for: species)
                        }
                    }
                }
                .padding(.top, 4)
            }

            heardPage

            if journal.nightKnownCount > 0 {
                nightPage
            }
        }
    }

    /// Known by night.
    ///
    /// Species met only as evidence — prints in the dew where the sill snack
    /// was. Renders nothing until the first visit, and never a denominator:
    /// an unmet visitor must not exist as a hole to fill.
    private var nightPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Known by night")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.8))

            ForEach(journal.nightKnownEntries) { entry in
                HStack(spacing: 10) {
                    Image(systemName: "moon.stars.fill")
                        .font(.footnote)
                        .frame(width: 20)
                        .foregroundStyle(Theme.bark.opacity(0.6))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.species.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.9))
                        Text("Never seen — the prints say enough. Since "
                             + entry.since.formatted(.dateTime.month(.abbreviated).day())
                             + ".")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.bark.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surface.opacity(0.9))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Known by night: \(entry.species.name). Never seen; "
                        + "met by evidence on the sill."
                )
            }
        }
        .padding(.top, 6)
    }

    /// Heard, not seen.
    ///
    /// The quietest page in the app, and the only one whose entries can never
    /// be looked at — a sound has no sprite, so the row *is* the record. Kept
    /// as rows rather than tiles for exactly that reason: a grid of five
    /// identical ear glyphs would be pretending there was something to see.
    private var heardPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Heard, not seen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.8))
                Spacer()
                Text("\(journal.heardCount) / \(Heard.allCases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.bark.opacity(0.5))
            }

            ForEach(Heard.allCases) { sound in
                let heard = journal.hasHeard(sound)
                HStack(spacing: 10) {
                    Image(systemName: heard ? "ear.fill" : "ear")
                        .font(.footnote)
                        .frame(width: 20)
                        .foregroundStyle(Theme.bark.opacity(heard ? 0.75 : 0.3))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(heard ? sound.name : "Something")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(heard ? 0.9 : 0.5))
                        Text(heard ? sound.note : sound.hint)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.bark.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surface.opacity(heard ? 0.9 : 0.4))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    heard
                        ? "Heard: \(sound.name). \(sound.note)"
                        : "Not yet heard. Hint: \(sound.hint)."
                )
            }
        }
        .padding(.top, 6)
    }

    private func seen(in page: Journal.Page) -> Int {
        page.species.filter(journal.hasSeen).count
    }

    private func tile(for species: Species) -> some View {
        let record = journal.record(for: species)
        let seen = record != nil
        let regular = journal.isRegular(species)

        return VStack(spacing: 5) {
            // A regular gets the marked variant — the same drawing with one
            // tone lifted, so it reads as the individual you keep meeting
            // rather than as a different animal.
            //
            // The unseen silhouette is the one image here not drawn as it was
            // generated. Its sprite is a single flat brown baked into the PNG,
            // which is invisible on a dark tile whatever opacity it is given —
            // so it is template-rendered and tinted with the theme's own text
            // colour instead. `Palette.silhouetteOpacityLight` has the
            // measurements and the argument.
            Group {
                if seen {
                    Image(regular ? species.regularAsset : species.sketchAsset)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(species.ghostAsset)
                        .interpolation(.none)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Theme.bark.opacity(silhouetteOpacity))
                }
            }
                .frame(height: 42)
                // The pale-coat star: once, ever, this one crossed the scene
                // in the moon-washed coat. A memory mark, not a checklist —
                // there is no count of these anywhere.
                .overlay(alignment: .topTrailing) {
                    if journal.hasPaleSeen(species) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.blossom)
                            .offset(x: 3, y: -2)
                    }
                }

            Text(seen ? species.name : "?")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(seen ? 0.9 : 0.5))
                .lineLimit(1)

            Text(caption(for: species, record: record))
                .font(.system(size: 9))
                .foregroundStyle(Theme.bark.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 22, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface.opacity(seen ? 0.9 : 0.45))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: species, record: record))
    }

    private func caption(for species: Species, record: SightingRecord?) -> String {
        guard let record else { return species.hint }
        // Once it's a regular the caption stops counting and starts describing:
        // relationship over collection, which is the whole point of the page.
        if journal.isRegular(species) { return species.regularNote }
        let date = record.firstSeen.formatted(.dateTime.day().month(.abbreviated))
        if record.count > 1 { return "\(date) · seen \(record.count)×" }
        // Something met exactly once has a thin caption — a date and nothing
        // else — and that is precisely the sighting worth saying more about.
        // The count takes over as soon as there is one, because "seen 6×" is
        // the more interesting fact by then.
        if let raw = record.weather, let sky = Weather(rawValue: raw) {
            return "\(date) · in \(sky.hintPhrase)"
        }
        return date
    }

    /// Where, when and — for anything met since the sky started having moods
    /// — what it was doing. The sentence a field journal actually keeps.
    ///
    /// Weather is optional in the record because nothing backfills it, so this
    /// silently reads the same as it always did for older sightings rather
    /// than announcing a gap.
    private func firstSeenLine(_ record: SightingRecord) -> String {
        let place = Place(rawValue: record.place)?.name ?? record.place
        var line = "First seen in \(place)"
        if let part = DayPart(rawValue: record.dayPart) {
            line += ", \(part.almanacWhen)"
        }
        if let raw = record.weather, let sky = Weather(rawValue: raw) {
            line += ", in \(sky.hintPhrase)"
        }
        return line + "."
    }

    private func accessibilityLabel(for species: Species, record: SightingRecord?) -> String {
        guard let record else {
            return "Not yet seen. Hint: \(species.hint)."
        }
        let date = record.firstSeen.formatted(.dateTime.day().month(.wide))
        return "\(species.name), \(species.rarity.label). "
            + "Seen \(record.count) time\(record.count == 1 ? "" : "s"), first on \(date). "
            + firstSeenLine(record) + " " + species.note
    }
}
