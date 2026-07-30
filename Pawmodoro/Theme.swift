import SwiftUI

/// The app's colours.
///
/// Every colour is resolved through `ThemeManager`, which means two things:
/// reading `Theme.bark` inside a view body registers an observation dependency
/// (so switching theme redraws everything), and each colour still adapts to the
/// system light/dark appearance underneath.
enum Theme {
    private static var palette: Palette { ThemeManager.shared.palette }

    /// Page background base.
    static var cream: Color { palette.cream.color }

    /// Focus-phase wash.
    static var blush: Color { palette.blush.color }

    /// Primary accent.
    static var blossom: Color { palette.blossom.color }

    /// Break-phase accent.
    static var sage: Color { palette.sage.color }

    static var forest: Color { palette.forest.color }

    /// Primary text and iconography.
    static var bark: Color { palette.bark.color }

    /// Long-break accent.
    static var sunshine: Color { palette.sunshine.color }

    /// Card and button fill. Call sites apply their own opacity so the layers
    /// still read against the gradient behind them.
    static var surface: Color { palette.surface.color }

    /// Text and icons drawn on top of an accent fill.
    ///
    /// Deliberately not white: white on these pastels measures as low as 1.5:1,
    /// well under the 4.5:1 needed to be legible. Every theme's `onAccent`
    /// clears 4.5:1 against all three accents in both appearances.
    static var onAccent: Color { palette.onAccent.color }

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
