import SwiftUI

/// The tide table, drawn the way tide tables have always been drawn.
///
/// Twenty-four hours of water across the width, as the sinusoid it actually
/// is, with a mark where *now* is. Two highs and two lows, and the curve
/// visibly shifts along by about fifty minutes each day — which is the thing
/// the plan wanted this to teach and the thing nobody ever tells you.
///
/// It is a `Canvas` with no `TimelineView` around it: the shape changes by
/// under a pixel a minute and the almanac is a sheet somebody has open for
/// twenty seconds. Redrawing it sixty times a second to move a dot four
/// pixels an hour would be the exact battery tax the anti-goals forbid.
struct TideCurveView: View {
    let now: Date
    let tint: Color
    let line: Color

    /// Samples across the day. Fifty is about one every half hour — smooth at
    /// any width a phone has, and cheap enough that the whole curve is built
    /// during layout.
    private static let samples = 50

    var body: some View {
        Canvas { canvas, size in
            let start = WorldCalendar.startOfDay(now)
            let day: TimeInterval = 24 * 3600

            var path = Path()
            for step in 0...Self.samples {
                let fraction = Double(step) / Double(Self.samples)
                let level = Tide.level(at: start.addingTimeInterval(day * fraction))
                let point = CGPoint(x: size.width * fraction,
                                    y: size.height * (1 - level))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            canvas.stroke(path, with: .color(line.opacity(0.45)),
                          style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Where the water is now. A filled dot rather than a vertical
            // rule: a rule across a curve reads as a threshold to cross, and
            // there is nothing here to cross.
            let elapsed = now.timeIntervalSince(start) / day
            let level = Tide.level(at: now)
            let here = CGPoint(x: size.width * elapsed,
                               y: size.height * (1 - level))
            canvas.fill(
                Path(ellipseIn: CGRect(x: here.x - 3, y: here.y - 3,
                                       width: 6, height: 6)),
                with: .color(tint)
            )
        }
        // The curve is decoration around a sentence that already says the same
        // thing in words, one line above it. A screen reader that read out
        // "chart" here would be announcing furniture.
        .accessibilityHidden(true)
    }
}
