import SwiftUI
import UIKit

/// Cozy pastel palette — warm cream, blossom pink, and sage by day; deep plum
/// and moonlight by night. Every colour adapts to the system appearance, so the
/// app reads well during a late-evening study session too.
enum Theme {
    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        var uiColor: UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
    }

    /// A colour that resolves differently in light and dark appearance.
    private static func dynamic(light: RGB, dark: RGB) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
        })
    }

    /// Page background base.
    static let cream = dynamic(
        light: RGB(0.99, 0.96, 0.89),
        dark: RGB(0.11, 0.10, 0.16)
    )

    /// Focus-phase wash.
    static let blush = dynamic(
        light: RGB(0.98, 0.80, 0.82),
        dark: RGB(0.29, 0.18, 0.30)
    )

    /// Primary accent.
    static let blossom = dynamic(
        light: RGB(0.93, 0.55, 0.66),
        dark: RGB(0.95, 0.62, 0.73)
    )

    /// Break-phase accent.
    static let sage = dynamic(
        light: RGB(0.68, 0.79, 0.63),
        dark: RGB(0.52, 0.68, 0.55)
    )

    static let forest = dynamic(
        light: RGB(0.29, 0.42, 0.34),
        dark: RGB(0.62, 0.78, 0.65)
    )

    /// Primary text and iconography.
    static let bark = dynamic(
        light: RGB(0.45, 0.32, 0.24),
        dark: RGB(0.95, 0.92, 0.86)
    )

    /// Long-break accent.
    static let sunshine = dynamic(
        light: RGB(0.97, 0.82, 0.45),
        dark: RGB(0.86, 0.71, 0.42)
    )

    /// Card and button fill. Call sites apply their own opacity so the layers
    /// still read against the gradient behind them.
    static let surface = dynamic(
        light: RGB(1.00, 1.00, 1.00),
        dark: RGB(0.22, 0.21, 0.29)
    )

    /// Text and icons drawn on top of an accent fill.
    ///
    /// Deliberately not white: white on these pastels measures as low as 1.5:1,
    /// well under the 4.5:1 needed to be legible. This soft cocoa clears 5.5:1
    /// against every accent in both light and dark appearance, and suits the
    /// palette better than black would.
    static let onAccent = dynamic(
        light: RGB(0.24, 0.15, 0.13),
        dark: RGB(0.24, 0.15, 0.13)
    )

    static func background(for phase: TimerEngine.Phase) -> LinearGradient {
        let colors: [Color] = switch phase {
        case .focus: [blush.opacity(0.6), cream]
        case .shortBreak: [sage.opacity(0.5), cream]
        case .longBreak: [sunshine.opacity(0.45), cream]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static func accent(for phase: TimerEngine.Phase) -> Color {
        switch phase {
        case .focus: blossom
        case .shortBreak: sage
        case .longBreak: sunshine
        }
    }
}
