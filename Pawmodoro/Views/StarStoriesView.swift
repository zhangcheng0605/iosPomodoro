import SwiftUI

/// A star, telling its night back.
///
/// Every star in the atlas already IS a night session, so each one can
/// compose its story live: a join across the log, the dream diary, the
/// heard log and the journal, at the date the star was earned. Zero new
/// state — the card is a query, and it appreciates automatically as the
/// other systems fill in. No game could ship this, because no game has
/// your actual evenings.
enum NightStory {

    /// The lines for one night, oldest systems first. Sparse records (from
    /// before the log learned places and buddies) still get a warm card.
    static func compose(
        record: SessionRecord, dreams: DreamDiary, journal: Journal,
        settings: PomodoroSettings, calendar: Calendar = .current
    ) -> [String] {
        var lines: [String] = []

        let weekday = record.endedAt.formatted(.dateTime.weekday(.wide))
        let month = record.endedAt.formatted(.dateTime.month(.wide))
        lines.append("A \(weekday) in \(month).")

        let hour = calendar.component(.hour, from: record.endedAt)
        let lateness = hour >= 23 || hour < 5 ? "past \(hour == 0 ? 12 : hour)" : "after dark"
        if let place = record.place.flatMap(Place.init(rawValue:)) {
            lines.append("\(place.name), \(lateness).")
        }
        if let buddy = record.buddy.flatMap(Buddy.init(rawValue:)) {
            lines.append("\(settings.displayName(for: buddy)) was with you.")
        }
        // What got dreamed that night, if the diary caught one.
        if let dreamed = dreams.records.first(where: { _, dreamRecord in
            calendar.isDate(dreamRecord.firstDreamed, inSameDayAs: record.endedAt)
                || calendar.isDate(dreamRecord.lastDreamed, inSameDayAs: record.endedAt)
        }), let dream = Dream.from(id: dreamed.key) {
            lines.append("There was a dream after — \(dream.subject).")
        }
        // First meetings that happened that night.
        let met = Species.allCases.filter { species in
            guard let sighting = journal.record(for: species) else { return false }
            return calendar.isDate(sighting.firstSeen, inSameDayAs: record.endedAt)
        }
        if let first = met.first {
            lines.append("The \(first.name.lowercased()) — that was this night.")
        }
        // Something heard, never seen.
        if let heard = journal.heard.first(where: { _, date in
            calendar.isDate(date, inSameDayAs: record.endedAt)
        }), let sound = Heard(rawValue: heard.key) {
            lines.append("You heard \(sound.name.lowercased()) that night.")
        }

        if lines.count == 1 {
            lines.append("A night session, from before the notes got good.")
        }
        return lines
    }
}

/// The nights behind one constellation: each lit star, told.
struct StarNightsSheet: View {
    let figureIndex: Int
    let figure: Constellation

    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ConstellationFigure(
                        figure: figure,
                        lit: ConstellationAtlas.litStars(
                            of: figureIndex, nightSessions: engine.log.nightSessions
                        ),
                        tint: Theme.bark
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)

                    ForEach(Array(stories.enumerated()), id: \.offset) { index, story in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Star \(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.blossom)
                            Text(story.joined(separator: " "))
                                .font(.footnote)
                                .foregroundStyle(Theme.bark.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.surface.opacity(0.75))
                        )
                    }

                    if stories.isEmpty {
                        Text("No stars here yet. They land one per session "
                             + "finished after dark.")
                            .font(.footnote)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                    }
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle(figure.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// This figure's lit stars are a contiguous run of the night sessions:
    /// the atlas fills figures in order, so the offset is the stars of
    /// every earlier figure.
    private var stories: [[String]] {
        let lit = ConstellationAtlas.litStars(
            of: figureIndex, nightSessions: engine.log.nightSessions
        )
        guard lit > 0 else { return [] }
        let offset = ConstellationAtlas.all.prefix(figureIndex)
            .reduce(0) { $0 + $1.starCount }
        let nights = engine.log.nightRecords
        return (0..<lit).map { index in
            let global = offset + index
            guard nights.indices.contains(global) else {
                // A star from before the log's horizon: real, just quiet.
                return ["A night session, further back than the log can see."]
            }
            return NightStory.compose(
                record: nights[global], dreams: engine.dreams,
                journal: engine.journal, settings: engine.settings
            )
        }
    }
}
