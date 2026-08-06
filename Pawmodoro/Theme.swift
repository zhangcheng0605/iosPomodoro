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

    /// How strongly the time-of-day tint is laid over the phase background.
    ///
    /// Safe to raise: `Palette.sky(_:)` has already pulled the wash's luminance
    /// close to the background's, so this changes how much hue arrives, not how
    /// bright the result is. `tools/check_contrast.py` proves that over every
    /// theme, appearance, phase and time of day.
    static let skyWashOpacity: Double = 0.45

    /// A tint over the phase background that follows the real time of day, so
    /// an evening session doesn't look like a lunchtime one.
    static func skyWash(for part: DayPart) -> Color? {
        palette.sky(part)?.color
    }

    /// The tint for what the sky is doing today, laid over the place itself
    /// rather than over the phase gradient. Nil when the weather is `clear`,
    /// which is what the app looked like before weather existed.
    static func weatherVeil(for weather: Weather) -> Color? {
        palette.weather(weather)?.color
    }

    static func accent(for phase: TimerEngine.Phase) -> Color {
        switch phase {
        case .focus: blossom
        case .shortBreak: sage
        case .longBreak: sunshine
        }
    }
}

/// Four rough times of day, from the wall clock.
enum DayPart: String, CaseIterable {
    case dawn, day, dusk, night

    static func current(at date: Date = WorldCalendar.now,
                        calendar: Calendar = WorldCalendar.calendar) -> DayPart {
        from(hour: calendar.component(.hour, from: date))
    }

    static func from(hour: Int) -> DayPart {
        switch hour {
        case 5..<8: .dawn
        case 8..<17: .day
        case 17..<21: .dusk
        default: .night
        }
    }

    /// Only night gets stars.
    var showsStars: Bool { self == .night }
}
