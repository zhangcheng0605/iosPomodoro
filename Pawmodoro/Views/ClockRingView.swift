import SwiftUI

/// The clock ring: twenty-four positions, midnight at the top, filling as you
/// are actually present for each hour striking.
///
/// **There is no count on this view and there must never be one.** Not "19 of
/// 24", not a bar, not "five to go", not a percentage in an accessibility
/// label. The whole design of the thing is that the dark side of the dial is
/// visible only by looking at the dial — the unfilled hours are unfilled
/// because somebody was asleep, and a number counting them turns eight hours
/// of sleep into a shortfall. That is the same argument the shelf of hours
/// makes, and this is the collection where it matters most, because unlike the
/// shelf you cannot fill this one on purpose without sitting still at four in
/// the morning waiting for a bell.
///
/// It is also the only screen in the app that shows something you *cannot*
/// hurry. A session can be started; an hour cannot.
struct ClockRingView: View {
    @Environment(TimerEngine.self) private var engine

    /// Outer radius of the dial, in points. The dots sit on it.
    private let radius: CGFloat = 46
    private var diameter: CGFloat { radius * 2 + 18 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The bell")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.8))

            HStack(alignment: .center, spacing: 14) {
                dial
                VStack(alignment: .leading, spacing: 4) {
                    Text(voiceLine)
                        .font(.footnote)
                        .foregroundStyle(Theme.bark.opacity(0.7))
                    Text(caption)
                        .font(.footnote.italic())
                        .foregroundStyle(Theme.bark.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: The dial

    private var dial: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.bark.opacity(0.14), lineWidth: 1)
                .frame(width: radius * 2, height: radius * 2)

            // Midnight and noon get a tick, so the dial reads as a day rather
            // than as a pie chart. Nothing else is labelled: four numbers
            // round a small circle is a clock, twenty-four is a table.
            ForEach([0, 12], id: \.self) { hour in
                Text(HourWords.short(hour))
                    .font(.system(size: 7))
                    .monospacedDigit()
                    .foregroundStyle(Theme.bark.opacity(0.35))
                    .offset(offset(for: hour, radius: radius + 9))
            }

            ForEach(0..<24, id: \.self) { hour in
                dot(hour)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func dot(_ hour: Int) -> some View {
        let filled = engine.clockRing.has(hour)
        return Circle()
            .fill(filled ? Theme.sunshine : Theme.bark.opacity(0.16))
            .frame(width: filled ? 7 : 5, height: filled ? 7 : 5)
            .offset(offset(for: hour, radius: radius))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(for: hour))
    }

    /// Midnight at the top, going round the way a clock does. Twenty-four
    /// positions rather than twelve, so the small hours have somewhere of
    /// their own to be — on a twelve-hour face 3 a.m. and 3 p.m. would share a
    /// light, and the whole point is which of the two you were there for.
    private func offset(for hour: Int, radius: CGFloat) -> CGSize {
        let angle: Double = Double(hour) / 24.0 * 2 * .pi - .pi / 2
        let arm = Double(radius)
        return CGSize(width: arm * cos(angle), height: arm * sin(angle))
    }

    // MARK: Words

    /// What it sounds like here. Named because a bell you cannot place is just
    /// a noise, and because it is the only hint anywhere that moving on down
    /// the journey changes it.
    private var voiceLine: String {
        "Here, the hour comes as \(BellVoice.at(engine.settings.place).name)."
    }

    /// One line, and never a tally.
    ///
    /// Three states: nothing yet, something, and all the way round. The middle
    /// one names the oddest hour it has caught you in — which says something
    /// true about a dial without counting anything on it, exactly as the
    /// shelf's caption does.
    private var caption: String {
        if engine.clockRing.isComplete {
            return "It has caught you in every hour there is."
        }
        guard engine.clockRing.hasAny else {
            return engine.settings.hourBellEnabled
                ? "Sit through the top of an hour and it will strike where you are."
                : "Silent, by your own decision. The switch is in Settings."
        }
        guard let oddest = engine.clockRing.oddestStruck else {
            return "The hours it has caught you sitting in."
        }
        return "It caught you once at \(HourWords.spoken(oddest))."
    }

    private func label(for hour: Int) -> String {
        guard let first = engine.clockRing.firstStruck(hour) else {
            // Deliberately not "not yet", and deliberately not part of a
            // running total — VoiceOver is where a forbidden count would be
            // easiest to smuggle in and hardest to notice.
            return "\(HourWords.spoken(hour).capitalizedFirstLetter): dark."
        }
        let day = first.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(HourWords.spoken(hour).capitalizedFirstLetter): struck, first on \(day)."
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

#Preview {
    ClockRingView()
        .padding()
        .environment(TimerEngine())
}
