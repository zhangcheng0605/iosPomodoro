import SwiftUI

/// Slow meteors across the upper sky, on the calendar's three windows a
/// year. One streak roughly every six seconds, each lane decided by its
/// own hash — deterministic, so two launches on the same night rain the
/// same rain. Mounted only on shower nights, above the starfield, below
/// everything that can be touched.
struct MeteorShowerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var born = Date()

    var body: some View {
        if reduceMotion {
            // Every part of this is motion; there is no still version of a
            // meteor worth drawing. The comet-marked star stories carry the
            // night instead.
            EmptyView()
        } else {
            GeometryReader { geometry in
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    Canvas { canvas, size in
                        draw(&canvas, size: size,
                             t: context.date.timeIntervalSince(born))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lane = Int(t / 6)
        let phase = (t - Double(lane) * 6) / 0.9
        guard phase <= 1 else { return }
        let seed = Double(Doorstep.stableHash("meteor.\(lane)") % 1000) / 1000
        let start = CGPoint(
            x: size.width * (0.12 + 0.68 * seed),
            y: size.height * (0.05 + 0.10 * seed)
        )
        let head = CGPoint(x: start.x + 95 * phase, y: start.y + 58 * phase)
        var tail = Path()
        tail.move(to: head)
        tail.addLine(to: CGPoint(x: head.x - 26, y: head.y - 16))
        canvas.stroke(
            tail,
            with: .color(Theme.cream.opacity(0.8 * (1 - phase))),
            lineWidth: 1.5
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: head.x - 1.5, y: head.y - 1.5, width: 3, height: 3)),
            with: .color(Theme.sunshine.opacity(0.9 * (1 - phase * 0.5)))
        )
    }
}
