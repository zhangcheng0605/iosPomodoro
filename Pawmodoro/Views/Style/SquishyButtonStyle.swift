import SwiftUI

/// Presses the button into the screen and lets it spring back.
///
/// The whole point of the app is that touching it feels good, and a control
/// that doesn't move under a finger reads as a picture of a button. Under
/// Reduce Motion the scale is dropped and only the dimming remains.
struct SquishyButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.90

    func makeBody(configuration: Configuration) -> some View {
        Squish(configuration: configuration, pressedScale: pressedScale)
    }

    private struct Squish: View {
        let configuration: ButtonStyleConfiguration
        let pressedScale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(scale)
                .opacity(configuration.isPressed ? 0.82 : 1)
                .animation(
                    .spring(response: 0.24, dampingFraction: 0.52),
                    value: configuration.isPressed
                )
        }

        private var scale: CGFloat {
            guard !reduceMotion, configuration.isPressed else { return 1 }
            return pressedScale
        }
    }
}

extension ButtonStyle where Self == SquishyButtonStyle {
    static var squishy: SquishyButtonStyle { SquishyButtonStyle() }

    static func squishy(pressedScale: CGFloat) -> SquishyButtonStyle {
        SquishyButtonStyle(pressedScale: pressedScale)
    }
}
