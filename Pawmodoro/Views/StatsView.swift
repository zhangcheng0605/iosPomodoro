import SwiftUI

struct StatsView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    private var log: SessionLog { engine.log }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AlmanacView()
                    bondCard
                    TastesCard()
                    summaryGrid
                    weekChart
                    if log.totalSessions == 0 {
                        emptyState
                    }
                    AlbumView()
                    StarAtlasView()
                    JournalView()
                    DreamDiaryView()
                    KeepsakeDrawerView()
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Your paw prints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) {
                        confirmingClear = true
                    }
                    .disabled(log.totalSessions == 0)
                }
            }
            .confirmationDialog(
                "Clear your session history?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear history", role: .destructive) {
                    log.clearHistory()
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("This erases every recorded focus session. It cannot be undone.")
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            statCard(
                title: "Today",
                value: "\(log.todaySessions)",
                caption: log.todayMinutes == 0 ? "no sessions yet" : "\(log.todayMinutes) min focused",
                icon: "sun.max.fill"
            )
            statCard(
                title: "This week",
                value: "\(log.weekSessions)",
                caption: "last 7 days",
                icon: "calendar"
            )
            statCard(
                title: "Streak",
                value: "\(log.streak.days)",
                // When a day was forgiven, the card says so rather than
                // quietly pretending it didn't happen. Naming the missed day
                // is the whole difference between a kind streak and a fudged
                // one, and it is the sentence this feature exists for.
                caption: streakCaption,
                icon: "flame.fill"
            )
            statCard(
                title: "All time",
                value: "\(log.totalSessions)",
                caption: "best streak \(log.bestStreak)",
                icon: "pawprint.fill"
            )
        }
    }

    /// The bond meter. Five hearts and a line, and deliberately no bar: this
    /// is a thing to notice having happened, not a target to chase.
    private var bondCard: some View {
        let bond = engine.bond
        let name = engine.buddyName
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                Text("You and \(name)")
                Spacer()
                Text(bond.name)
                    .foregroundStyle(Theme.bark.opacity(0.75))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            HStack(spacing: 6) {
                ForEach(0..<Bond.allCases.count - 1, id: \.self) { index in
                    Image(systemName: index < bond.hearts ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(index < bond.hearts
                                         ? Theme.blossom : Theme.bark.opacity(0.22))
                }
            }

            Text(bond.blurb(buddy: name))
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.65))

            if let togo = Bond.sessionsToNext(from: log.totalSessions) {
                Text("\(togo) more session\(togo == 1 ? "" : "s") together")
                    .font(.caption2)
                    .foregroundStyle(Theme.bark.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "You and \(name): \(bond.name), \(bond.hearts) of 5. "
                + bond.blurb(buddy: name)
        )
    }

    private var streakCaption: String {
        let streak = log.streak
        if let missed = streak.forgiven.first {
            let day = missed.formatted(.dateTime.weekday(.wide))
            return "the boat stayed anchored on \(day)"
        }
        return streak.days == 1 ? "day in a row" : "days in a row"
    }

    private func statCard(title: String, value: String, caption: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.bark)

            Text(caption)
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
    }

    private var weekChart: some View {
        let days = log.dailyCounts(days: 7)
        let peak = max(days.map(\.count).max() ?? 0, 1)
        // Where the buddy has settled: the week's tallest bar is, from the
        // right altitude, a mountain — and mountains are for napping on.
        let summit = days.enumerated()
            .filter { $0.element.count > 0 }
            .max { $0.element.count < $1.element.count }?.offset

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.blossom)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 6) {
                        Text(day.count == 0 ? " " : "\(day.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.7))

                        Capsule()
                            .fill(day.count == 0 ? Theme.bark.opacity(0.12) : Theme.blossom)
                            .frame(height: barHeight(count: day.count, peak: peak))
                            .overlay(alignment: .top) {
                                if index == summit {
                                    summitNap
                                }
                            }

                        Text(weekdayLabel(for: day.date))
                            .font(.caption2)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            // Extra headroom so the sleeper clears the count labels.
            .padding(.top, summit == nil ? 0 : 16)

            if summit != nil, currentWeekIsBest {
                Text("A flag on the summit — your best week yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
    }

    /// The buddy asleep on the tallest bar, with a flag if this week is the
    /// best there has ever been. It naps exactly as contentedly on a
    /// one-session molehill — the altitude is yours, the nap is its own.
    private var summitNap: some View {
        HStack(alignment: .bottom, spacing: 0) {
            BuddySprite(buddy: engine.settings.buddy, sleeping: true, size: 26)
            if currentWeekIsBest {
                Image("fx_flag")
                    .renderingMode(.template)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 14)
                    .foregroundStyle(Theme.blossom)
                    .offset(y: -2)
            }
        }
        .offset(y: -24)
        .accessibilityHidden(true)
    }

    /// Derived from the log every time, like the bond: whether the current
    /// calendar week has strictly more sessions than any other week ever.
    private var currentWeekIsBest: Bool {
        let calendar = Calendar.current
        var weeks: [String: Int] = [:]
        for record in log.records {
            let parts = calendar.dateComponents(
                [.weekOfYear, .yearForWeekOfYear], from: record.endedAt
            )
            let key = "\(parts.yearForWeekOfYear ?? 0)-\(parts.weekOfYear ?? 0)"
            weeks[key, default: 0] += 1
        }
        let now = calendar.dateComponents(
            [.weekOfYear, .yearForWeekOfYear], from: Date()
        )
        let nowKey = "\(now.yearForWeekOfYear ?? 0)-\(now.weekOfYear ?? 0)"
        guard let current = weeks[nowKey], current > 0 else { return false }
        return weeks.allSatisfy { $0.key == nowKey || $0.value < current }
    }

    private func barHeight(count: Int, peak: Int) -> CGFloat {
        let minimum: CGFloat = 8
        let maximum: CGFloat = 110
        guard count > 0 else { return minimum }
        return minimum + (maximum - minimum) * CGFloat(count) / CGFloat(peak)
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🐾")
                .font(.system(size: 44))
            Text("Finish a focus session and your first paw print lands here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.bark.opacity(0.7))
        }
        .padding(.top, 8)
    }
}

#Preview {
    StatsView()
        .environment(TimerEngine())
        .fontDesign(.rounded)
}
