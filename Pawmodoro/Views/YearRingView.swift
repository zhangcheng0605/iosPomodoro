import SwiftUI

/// The year you actually had, as a circle.
///
/// One wedge per day, tinted with the sky of the hours you sat. Drawn entirely
/// in a `Canvas` from the palette the scenery already uses — no images, no new
/// assets, and it re-tints itself when the theme changes because every colour
/// comes back through `Theme`.
///
/// It is a picture, not a chart. There is no axis, no count, no "you focused
/// 41 % of days" — the only quantity on screen is how much of the circle has
/// colour in it, which is exactly as precise as this ought to be.
struct YearRingView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var year: Int?
    @State private var showPaywall = false

    private var years: [Int] { YearRing.years(in: engine.log.records) }

    private var currentYear: Int {
        WorldCalendar.calendar.component(.year, from: WorldCalendar.now)
    }

    private var shown: Int { year ?? currentYear }

    /// The current year is always free and always complete. Past years stack
    /// behind it like tree rings, and that stack is the Plus part — you never
    /// lose this year, and nobody is ever charged to see what they are doing
    /// now.
    private var canSee: Bool {
        shown == currentYear || store.hasPlus || LaunchOptions.unlockPlaces
    }

    private var ring: YearRing.Year {
        YearRing.build(year: shown, from: engine.log.records)
    }

    private var marks: [YearRing.Mark] {
        YearRing.marks(
            for: shown,
            from: engine.chronicle.events,
            firstSession: engine.log.records.map(\.endedAt).min()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if canSee {
                wheel
                caption
            } else {
                locked
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var header: some View {
        HStack {
            Text("The year ring")
                .font(.headline)
                .foregroundStyle(Theme.bark)
            Spacer()
            if years.count > 1 {
                yearPicker
            }
        }
    }

    private var yearPicker: some View {
        HStack(spacing: 6) {
            ForEach(years.prefix(6), id: \.self) { candidate in
                let selected = candidate == shown
                let free = candidate == currentYear || store.hasPlus
                Button {
                    year = candidate
                    if !free { showPaywall = true }
                } label: {
                    HStack(spacing: 3) {
                        Text(String(candidate))
                        if !free {
                            Image(systemName: "lock.fill").font(.system(size: 8))
                        }
                    }
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            selected ? Theme.blossom.opacity(0.22)
                                     : Theme.surface.opacity(0.6)
                        )
                    )
                    .foregroundStyle(Theme.bark.opacity(selected ? 0.95 : 0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The ring itself. One `Canvas`, no timeline: nothing here moves, so
    /// nothing here should cost a frame.
    private var wheel: some View {
        Canvas { context, size in
            let days = ring.days
            guard !days.isEmpty else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 10
            let inner = outer * 0.58
            let step = 360.0 / Double(days.count)

            for day in days {
                // -90 puts 1 January at the top, and the year runs clockwise
                // the way a clock face does.
                let start = Angle.degrees(Double(day.ordinal - 1) * step - 90)
                let end = Angle.degrees(Double(day.ordinal) * step - 90 + 0.35)

                var wedge = Path()
                wedge.addArc(center: centre, radius: outer,
                             startAngle: start, endAngle: end, clockwise: false)
                wedge.addArc(center: centre, radius: inner,
                             startAngle: end, endAngle: start, clockwise: true)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(tint(for: day)))
            }

            for mark in marks {
                let angle = Angle.degrees(
                    (Double(mark.ordinal) - 0.5) * step - 90
                )
                let radius = outer + 4
                let point = CGPoint(
                    x: centre.x + CGFloat(cos(angle.radians)) * radius,
                    y: centre.y + CGFloat(sin(angle.radians)) * radius
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2,
                                           width: 4, height: 4)),
                    with: .color(Theme.blossom)
                )
            }
        }
        .frame(height: 240)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    /// A day's colour: the sky of the hours it held, over parchment.
    ///
    /// Empty days are the parchment itself — never red, never a gap, never
    /// anything that reads as a day you owe somebody. A day with sessions in
    /// more than one part of the day gets them blended in a stable order,
    /// heaviest first, so a morning-and-evening day is its own colour rather
    /// than whichever one the dictionary happened to yield.
    private func tint(for day: YearRing.Day) -> Color {
        guard !day.isEmpty else { return Theme.bark.opacity(0.07) }
        var colour = Theme.cream
        var weight = 0.0
        for (part, count) in day.ordered {
            let share = Double(count)
            weight += share
            // `Theme.ringTint`, not `skyWash` — see `Palette.ringTint` for
            // the two designs that were tried before this one and the
            // measurements that ruled them out.
            colour = colour.mix(with: Theme.ringTint(for: part),
                                by: share / weight)
        }
        // Full strength, always. An opacity ramp by session count was here
        // and had to go: `Palette.ringTint` earns its separation from a
        // measured lightness ladder, and washing a wedge out by 40 % undoes
        // exactly that. It is also the better answer — the ring is about
        // *when* you sat, not how many times, and a day with one session is
        // not a fainter kind of day.
        return colour
    }

    private var caption: some View {
        Text(ring.isEmpty
             ? "Every day you finish a session paints its own day here."
             : captionLine)
            .font(.footnote)
            .foregroundStyle(Theme.bark.opacity(0.6))
    }

    /// Says what the picture is, and stops. No percentage, no comparison with
    /// last year, nothing anybody could be behind on.
    private var captionLine: String {
        let lived = ring.lived
        let marked = marks.count
        var line = "\(lived) day\(lived == 1 ? "" : "s") with colour in them, "
            + "tinted by the hours you sat."
        if marked > 0 {
            line += " The dots on the rim are days something happened."
        }
        return line
    }

    private var locked: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title3)
                Text("Past years are part of Pawmodoro Plus.")
                    .font(.footnote)
                Text("This year is always free, and always complete.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .foregroundStyle(Theme.bark.opacity(0.65))
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var accessibilityLabel: String {
        guard !ring.isEmpty else {
            return "The year ring for \(shown), with nothing in it yet."
        }
        return "The year ring for \(shown). \(ring.lived) days have sessions in "
            + "them, each tinted by the time of day you focused."
    }
}

extension Color {
    /// A plain blend toward another colour.
    ///
    /// SwiftUI's own `mix(with:by:)` is iOS 18, and this app is 17+. Written
    /// out through the platform colour so it composites the same way the
    /// palette does.
    func mix(with other: Color, by amount: Double) -> Color {
        // Through `rgbaComponents`, never `getRed` directly: the AppKit
        // spelling raises on a catalog colour, and every `Theme` colour is
        // one. See `Platform.swift`.
        let (r1, g1, b1, a1) = PlatformColor(self).rgbaComponents
        let (r2, g2, b2, a2) = PlatformColor(other).rgbaComponents
        let t = CGFloat(min(1, max(0, amount)))
        return Color(PlatformColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        ))
    }
}
