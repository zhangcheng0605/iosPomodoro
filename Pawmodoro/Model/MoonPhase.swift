import Foundation

/// The real phase of the real moon, worked out from arithmetic.
///
/// No network, no table, no API key: the synodic month is a known constant and
/// a known new moon is a known date, so everything else is a remainder. An app
/// that quietly knows tonight's moon is full — and shows you something only
/// then — is the kind of detail people screenshot.
enum MoonPhase {
    /// 2000-01-06 18:14 UTC, a new moon.
    private static let reference = Date(timeIntervalSince1970: 947_182_440)
    /// Mean synodic month, in days.
    private static let synodic = 29.530_588_853

    /// 0 at new moon, 0.5 at full, wrapping back to 1.
    static func age(on date: Date = Date()) -> Double {
        let days = date.timeIntervalSince(reference) / 86_400.0
        let cycles = days / synodic
        return cycles - cycles.rounded(.down)
    }

    /// How lit the disc is, 0...1.
    static func illumination(on date: Date = Date()) -> Double {
        (1 - cos(2 * .pi * age(on: date))) / 2
    }

    /// True for roughly three nights around full — the moon rabbit's window.
    /// Wide enough to be catchable, narrow enough to stay rare.
    static func isFull(on date: Date = Date()) -> Bool {
        if let forced = LaunchOptions.forcedMoon { return forced }
        return abs(age(on: date) - 0.5) < 0.05
    }

    static func name(on date: Date = Date()) -> String {
        let phase = age(on: date)
        switch phase {
        case ..<0.03, 0.97...: return "New moon"
        case ..<0.22: return "Waxing crescent"
        case ..<0.28: return "First quarter"
        case ..<0.47: return "Waxing gibbous"
        case ..<0.53: return "Full moon"
        case ..<0.72: return "Waning gibbous"
        case ..<0.78: return "Last quarter"
        default: return "Waning crescent"
        }
    }
}
