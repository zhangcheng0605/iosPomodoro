import SwiftUI

/// One timetabled place event, happening. Mounted only while its window is
/// open, drawn as a Canvas over the lower scene band — nothing here ever
/// approaches the sky rows the countdown owns. Watching it for a few
/// seconds writes the Timetable entry; the event itself neither knows nor
/// cares whether it was seen.
struct ClockworkEventView: View {
    let event: ClockworkEvent
    let timetable: Timetable
    let tint: Color

    @State private var born = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 6.0)) { context in
                Canvas { canvas, size in
                    draw(&canvas, size: size,
                         t: context.date.timeIntervalSince(born))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            // Present for a few breaths counts as having caught it.
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            timetable.witness(event)
        }
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch event {
        case .ferryMorning, .ferryEvening:
            drawFerry(&canvas, size: size, t: t,
                      leaving: event == .ferryMorning)
        case .keepFirstLight:
            drawFirstLight(&canvas, size: size, t: t)
        case .onsenNightSteam:
            drawSteam(&canvas, size: size, t: t)
        case .meadowHeron:
            break   // the heron is a sprite, drawn by the wrapper below
        case .cloudspireBeacon:
            drawBeacon(&canvas, size: size, t: t)
        }
    }

    /// A small silhouette ferry, crossing the harbor's water band over the
    /// whole window. Out means rightward; home means left.
    private func drawFerry(
        _ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval, leaving: Bool
    ) {
        // A twelve-minute crossing, restarted per mount — pure f(t).
        let span = 720.0
        let progress = min(1, (t.truncatingRemainder(dividingBy: span)) / span + 0.08)
        let x = size.width * (leaving ? progress : (1 - progress))
        let y = size.height * 0.72 + sin(t * 0.8) * 1.5
        var hull = Path()
        hull.move(to: CGPoint(x: x - 11, y: y))
        hull.addLine(to: CGPoint(x: x + 11, y: y))
        hull.addLine(to: CGPoint(x: x + 7, y: y + 6))
        hull.addLine(to: CGPoint(x: x - 7, y: y + 6))
        hull.closeSubpath()
        canvas.fill(hull, with: .color(tint.opacity(0.75)))
        canvas.stroke(
            Path { $0.move(to: CGPoint(x: x, y: y)); $0.addLine(to: CGPoint(x: x, y: y - 10)) },
            with: .color(tint.opacity(0.75)), lineWidth: 1.4
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: x + 1, y: y - 10, width: 6, height: 4)),
            with: .color(tint.opacity(0.5))
        )
    }

    /// The dawn hour on the Keep: a warm band low on the stone, breathing.
    private func drawFirstLight(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let glow = 0.10 + 0.05 * sin(t * 0.7)
        let rect = CGRect(
            x: size.width * 0.12, y: size.height * 0.58,
            width: size.width * 0.76, height: size.height * 0.10
        )
        canvas.fill(
            Path(roundedRect: rect, cornerRadius: rect.height / 2),
            with: .color(Theme.sunshine.opacity(glow))
        )
    }

    /// The late steam: slow wisps rising off the spring, twice the usual.
    private func drawSteam(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<4 {
            let n = Double(index)
            let cycle = 7.0 + n
            let phase = (t + n * 1.9).truncatingRemainder(dividingBy: cycle) / cycle
            let x = size.width * (0.55 + 0.1 * n / 3) + sin(phase * .pi * 2 + n) * 7
            let y = size.height * (0.70 - phase * 0.14)
            let fade = (1 - phase) * 0.28
            canvas.stroke(
                Path(ellipseIn: CGRect(x: x - 7, y: y - 3, width: 14, height: 6)),
                with: .color(tint.opacity(fade)), lineWidth: 1
            )
        }
    }

    /// The beacon: long, short, short, dark. From full dark only.
    private func drawBeacon(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let beat = t.truncatingRemainder(dividingBy: 4.0)
        let lit = beat < 1.2 || (2.0...2.3).contains(beat) || (2.8...3.1).contains(beat)
        guard lit else { return }
        let point = CGPoint(x: size.width * 0.86, y: size.height * 0.30)
        canvas.fill(
            Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
            with: .color(Theme.sunshine.opacity(0.20))
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
            with: .color(Theme.sunshine.opacity(0.9))
        )
    }
}

/// The heron variant needs a sprite, not a Canvas — it borrows the wildlife
/// art and stands very still at the meadow stream, which is the whole act.
struct ClockworkHeronView: View {
    let timetable: Timetable

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 1.6)) { context in
                let tick = Int(context.date.timeIntervalSince1970 / 1.6)
                Image("wild_heron_\(tick % 2)")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34)
                    .position(
                        x: geometry.size.width * 0.24,
                        y: geometry.size.height * 0.72
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            timetable.witness(.meadowHeron)
        }
    }
}

/// The Timetable: what you've caught the places doing, and when they do
/// it. Learned rows only — an uncaught event does not exist as a hole.
struct TimetableView: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        let entries = engine.timetable.entries

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                Text("The timetable")
                Spacer()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            if entries.isEmpty {
                Text("The places keep hours. Be somewhere at the right one "
                     + "and it goes in the book.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            } else {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(entry.event.name) — \(entry.event.place.name)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.bark.opacity(0.85))
                            Text(entry.event.schedule
                                 + " · learned "
                                 + entry.learned.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                                .foregroundStyle(Theme.bark.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            entries.isEmpty
                ? "The timetable, empty. The places keep hours; catch one."
                : "The timetable: \(entries.count) learned."
        )
    }
}
