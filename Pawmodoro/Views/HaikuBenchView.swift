import SwiftUI

/// One finished poem, styled for the anthology and for export.
struct HaikuCard: View {
    let haiku: Haiku

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(haiku.lines, id: \.self) { line in
                    Text(line)
                        .font(.callout.italic())
                        .foregroundStyle(Theme.bark)
                }
            }
            HStack {
                Text(haiku.placeName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.blossom)
                Spacer()
                Text(haiku.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.bark.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surface.opacity(0.85))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "A haiku from \(haiku.placeName): " + haiku.lines.joined(separator: ", ")
        )
    }
}

/// The bench: pick one of three lines, three times, and the poem files
/// into the anthology. The pools change with the place, the season and
/// the hour, so the Harbor at dusk writes differently than the Peaks at
/// dawn. The bench is furniture, not homework — it asks for nothing.
struct HaikuBenchView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: [Int?] = [nil, nil, nil]
    @State private var saved: Haiku?
    @State private var sharingPoem: Haiku?

    private static let labels = ["FIRST LINE", "SECOND LINE", "THIRD LINE"]

    private var name: String {
        engine.settings.displayName(for: engine.settings.buddy)
    }

    /// Today's page: stable for the calendar day at this place.
    private var page: [[String]] {
        HaikuBench.choices(
            place: engine.settings.place,
            season: Season.current(),
            part: LaunchOptions.forcedDayPart ?? DayPart.current(),
            day: Snack.dayNumber(for: Date())
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if let saved {
                        keptView(saved)
                    } else {
                        composer
                    }
                    anthologySection
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("The bench")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sharingPoem) { poem in
                ShareableCardSheet(title: "A haiku") {
                    HaikuCard(haiku: poem)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            BuddySprite(buddy: engine.settings.buddy, sleeping: false, size: 56)
            Text(saved == nil
                 ? "\(name) sits beside you while you choose."
                 : "\(name) considers it. A slow blink. Kept.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Choosing

    private var composer: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { line in
                lineGroup(line)
            }
            Button {
                keepPoem()
            } label: {
                Text("Keep")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(
                        Theme.blossom.opacity(allChosen ? 1 : 0.35)
                    ))
            }
            .buttonStyle(.squishy)
            .disabled(!allChosen)
            .padding(.top, 4)
        }
    }

    private var allChosen: Bool {
        !chosen.contains(nil)
    }

    @ViewBuilder
    private func lineGroup(_ line: Int) -> some View {
        let options = page[line]
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.labels[line])
                .font(.caption2.weight(.bold))
                .tracking(2)
                .foregroundStyle(Theme.bark.opacity(0.45))
            ForEach(options.indices, id: \.self) { index in
                let picked = chosen[line] == index
                Button {
                    chosen[line] = index
                } label: {
                    HStack {
                        Text(options[index])
                            .font(.callout.italic())
                            .foregroundStyle(picked ? Theme.onAccent : Theme.bark)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(picked ? Theme.blossom : Theme.surface.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(options[index])
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func keepPoem() {
        guard allChosen else { return }
        let lines = (0..<3).compactMap { line in
            chosen[line].map { page[line][$0] }
        }
        let haiku = Haiku(
            id: UUID(), date: Date(),
            place: engine.settings.place.rawValue, lines: lines
        )
        engine.anthology.keep(haiku)
        withAnimation(.easeInOut(duration: 0.3)) {
            saved = haiku
        }
    }

    @ViewBuilder
    private func keptView(_ poem: Haiku) -> some View {
        HaikuCard(haiku: poem)
        HStack(spacing: 20) {
            Button {
                sharingPoem = poem
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.7))
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    saved = nil
                    chosen = [nil, nil, nil]
                }
            } label: {
                Label("Another", systemImage: "arrow.uturn.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: The anthology

    @ViewBuilder
    private var anthologySection: some View {
        let poems = Array(engine.anthology.poems.reversed())
        if !poems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("THE ANTHOLOGY")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.bark.opacity(0.45))
                    .padding(.top, 8)
                ForEach(poems) { poem in
                    Button {
                        sharingPoem = poem
                    } label: {
                        HaikuCard(haiku: poem)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
