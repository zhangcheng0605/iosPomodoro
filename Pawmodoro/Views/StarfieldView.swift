import SwiftUI

/// A dozen slow stars, drawn after dark.
///
/// Twinkling is an opacity wobble on a half-second tick — anything faster looks
/// like static, and anything busier stops being a background.
struct StarfieldView: View {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    private static let count = 12

    var body: some View {
        if reduceMotion {
            Canvas { canvas, size in draw(&canvas, size: size, t: 0) }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Canvas { canvas, size in
                    draw(&canvas, size: size, t: context.date.timeIntervalSince(started))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<Self.count {
            let n = Double(index)
            let x = ((n * 0.6180339887).truncatingRemainder(dividingBy: 1)) * size.width
            // Kept to the upper third: that's the part of the screen that reads
            // as sky, and the only part with no text over it.
            let y = ((n * 0.7548776662).truncatingRemainder(dividingBy: 1)) * size.height * 0.34
            let twinkle = 0.5 + 0.5 * sin(t * 0.9 + n * 1.7)
            let r = 1.0 + (n.truncatingRemainder(dividingBy: 3)) * 0.5

            canvas.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(tint.opacity(0.18 + twinkle * 0.3))
            )
        }
    }
}
