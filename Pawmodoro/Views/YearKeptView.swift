import SwiftUI

/// One season letter, styled for reading and for export.
struct LetterCard: View {
    let letter: SeasonLetter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(letter.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.blossom)
                Spacer()
                Text(String(letter.year))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.bark.opacity(0.45))
            }
            Text(letter.text)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surface.opacity(0.85))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A letter from \(letter.title): \(letter.text)")
    }
}

/// A Year, Kept: the anniversary sequence. A handful of full-screen cards
/// in the postcard language — hours, first meetings, the sky, the
/// strangest keepsake — each exportable, none of them a score. Presented
/// whenever the year rolls past, so it cannot be missed.
struct YearKeptView: View {
    let years: Int
    let onDone: () -> Void

    @Environment(TimerEngine.self) private var engine
    @State private var sharing: Int?

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 12) {
                TabView {
                    ForEach(0..<cardCount, id: \.self) { index in
                        VStack(spacing: 14) {
                            card(index)
                            Button {
                                sharing = index
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.bark.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    onDone()
                } label: {
                    Text("Kept")
                        .font(.headline)
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.blossom))
                }
                .buttonStyle(.squishy)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: sharingBinding) { wrapped in
            ShareableCardSheet(title: "A year, kept") {
                card(wrapped.index)
            }
        }
    }

    private var sharingBinding: Binding<SharingIndex?> {
        Binding(
            get: { sharing.map(SharingIndex.init) },
            set: { sharing = $0?.index }
        )
    }

    private struct SharingIndex: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var cardCount: Int { 5 }

    // MARK: The cards

    @ViewBuilder
    private func card(_ index: Int) -> some View {
        switch index {
        case 0: coverCard
        case 1: hoursCard
        case 2: wildCard
        case 3: skyCard
        default: closingCard
        }
    }

    private func cardShell<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.surface.opacity(0.9))
        )
    }

    private var coverCard: some View {
        cardShell {
            Text("A YEAR, KEPT")
                .font(.caption.weight(.bold))
                .tracking(4)
                .foregroundStyle(Theme.blossom)
            BuddySprite(buddy: engine.settings.buddy, sleeping: false, size: 84)
            Text("Year \(years), together")
                .font(.title3.bold())
                .foregroundStyle(Theme.bark)
            Text("What the almanac kept while you worked.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))
        }
    }

    private var hoursCard: some View {
        let stats = yearStats
        return cardShell {
            Text("THE HOURS")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(Theme.blossom)
            Text("\(stats.hours)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.bark)
            Text("quiet hours this year, across \(stats.sessions) sessions")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.65))
            Text(stats.hours > 0
                 ? "All of them counted. None of them graded."
                 : "The year is young. The kettle is on.")
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.5))
        }
    }

    private var wildCard: some View {
        let rarest = rarestThisYear
        return cardShell {
            Text("THE WILD")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(Theme.blossom)
            if let rarest {
                Image(rarest.sketchAsset)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                Text("Rarest this year: the \(rarest.name.lowercased())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark)
                Text(rarest.note)
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            } else {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(Theme.blossom)
                Text("The stag is still out there.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark)
            }
        }
    }

    private var skyCard: some View {
        let stats = yearStats
        return cardShell {
            Text("THE SKY")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(Theme.blossom)
            Image(systemName: "moon.stars.fill")
                .font(.title)
                .foregroundStyle(Theme.bark.opacity(0.7))
            Text("\(stats.stars) star\(stats.stars == 1 ? "" : "s") went up after dark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.bark)
            if stats.showerStars > 0 {
                Text("\(stats.showerStars) of them on falling-star nights.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            } else {
                Text("Each one a night you stayed.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            }
        }
    }

    private var closingCard: some View {
        cardShell {
            BuddySprite(buddy: engine.settings.buddy, sleeping: true, size: 64)
            Text("Year \(years), kept.")
                .font(.title3.bold())
                .foregroundStyle(Theme.bark)
            Text("See you in the morning.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))
        }
    }

    // MARK: Derived stats, over this anniversary year only

    private struct YearStats {
        var hours = 0
        var sessions = 0
        var stars = 0
        var showerStars = 0
    }

    private var yearWindow: ClosedRange<Date>? {
        guard let first = engine.log.firstSessionDate else { return nil }
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .year, value: years - 1, to: first),
              let end = calendar.date(byAdding: .year, value: years, to: first)
        else { return nil }
        return start...end
    }

    private var yearStats: YearStats {
        guard let window = yearWindow else { return YearStats() }
        var stats = YearStats()
        let records = engine.log.records.filter { window.contains($0.endedAt) }
        stats.sessions = records.count
        stats.hours = records.reduce(0) { $0 + $1.minutes } / 60
        let nights = engine.log.nightRecords.filter { window.contains($0.endedAt) }
        stats.stars = nights.count
        stats.showerStars = nights.filter {
            ShowerCalendar.isShowerNight(on: $0.endedAt)
        }.count
        return stats
    }

    private var rarestThisYear: Species? {
        guard let window = yearWindow else { return nil }
        return engine.journal.records
            .compactMap { key, record -> Species? in
                guard window.contains(record.firstSeen) else { return nil }
                return Species(rawValue: key)
            }
            .min { $0.rarity.chance < $1.rarity.chance }
    }
}
