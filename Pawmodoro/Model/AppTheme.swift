import SwiftUI
import UIKit

/// Plain colour components, 0...1 per channel.
struct RGBComponents: Equatable {
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

    /// Linear blend, `amount` being how much of `other` ends up in the result.
    func mixed(with other: RGBComponents, amount: Double) -> RGBComponents {
        RGBComponents(
            red + (other.red - red) * amount,
            green + (other.green - green) * amount,
            blue + (other.blue - blue) * amount
        )
    }
}

/// A colour that resolves differently in light and dark appearance.
struct DualColor: Equatable {
    let light: RGBComponents
    let dark: RGBComponents

    static func dual(
        _ lightRed: Double, _ lightGreen: Double, _ lightBlue: Double,
        _ darkRed: Double, _ darkGreen: Double, _ darkBlue: Double
    ) -> DualColor {
        DualColor(
            light: RGBComponents(lightRed, lightGreen, lightBlue),
            dark: RGBComponents(darkRed, darkGreen, darkBlue)
        )
    }

    var color: Color {
        // Resolve both up front so the dynamic provider only picks between two
        // ready-made colours, and so the closure captures locals rather than self.
        let lightColor = light.uiColor
        let darkColor = dark.uiColor
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}

/// One complete colour scheme.
struct Palette: Equatable {
    let cream: DualColor
    let blush: DualColor
    let blossom: DualColor
    let sage: DualColor
    let forest: DualColor
    let bark: DualColor
    let sunshine: DualColor
    let surface: DualColor
    let onAccent: DualColor
    /// The hue the sky takes after dark. In dark appearance it's a real depth;
    /// in light appearance it's cool moonlight rather than blackness, because
    /// a light-mode phone shouldn't go dark just because it's late.
    let night: DualColor

    /// How much `cream` is blended into a sky wash before it's drawn.
    ///
    /// This is what keeps the wash safe. Mixing the hue toward the background's
    /// own base pins the wash's luminance near the background's, so the tint
    /// reads as a change of colour rather than of brightness — and the text
    /// contrast barely moves however strongly it's applied. Lowering this will
    /// fail `tools/check_contrast.py`.
    static let skyMix: Double = 0.58

    /// The tint for a time of day, or nil at midday when the sky is just itself.
    func sky(_ part: DayPart) -> DualColor? {
        let hue: DualColor
        switch part {
        case .day: return nil
        case .dawn: hue = sunshine
        case .dusk: hue = blossom
        case .night: hue = night
        }
        return DualColor(
            light: hue.light.mixed(with: cream.light, amount: Self.skyMix),
            dark: hue.dark.mixed(with: cream.dark, amount: Self.skyMix)
        )
    }

    /// The four times of day, for the year ring: four shades of the theme's
    /// own accent, laddered from the page colour toward the text colour.
    ///
    /// **Not `sky(_:)`, and not four different hues either.** Both were tried
    /// and both were measured by `tools/check_yearring.py`, which asks the one
    /// question that matters here — can an eye tell these four apart, in every
    /// theme, in both appearances:
    ///
    /// - The sky washes failed 61 of 320 pairs. A wash is pulled most of the
    ///   way to `cream` on purpose, to pin its luminance so text stays legible
    ///   over it; a wedge has nothing written on it and needs the opposite. In
    ///   Cocoa, a night session's day measured ΔE 1.3 from a day nobody
    ///   focused at all.
    /// - Four separate hues (sunshine / sage / blossom / night) failed 18.
    ///   `sunshine` and `blossom` are both warm and sit close together in
    ///   several palettes, and mixing toward `bark` barely separates them in
    ///   dark appearance, where `bark` is *also* light. Ink's dark palette is
    ///   the limiting case and simply has no four distinguishable hues in it.
    ///
    /// So the ladder does the work and the hue rides along. Lightness is the
    /// one axis every palette has four of, the steps are evenly spaced by
    /// construction, and the result reads as the day going on — a year of
    /// mornings is a pale ring, a year of late nights a dark one, which was
    /// the whole claim. Worst measured separation across all 320 pairs: ΔE
    /// 10.4, against a bar of 8.
    func ringTint(_ part: DayPart) -> DualColor {
        let step: Double
        switch part {
        case .dawn: step = 0.26
        case .day: step = 0.48
        case .dusk: step = 0.70
        case .night: step = 0.92
        }
        func shade(_ page: RGBComponents, _ text: RGBComponents,
                   _ accent: RGBComponents) -> RGBComponents {
            page.mixed(with: text, amount: step).mixed(with: accent, amount: 0.20)
        }
        return DualColor(
            light: shade(cream.light, bark.light, blossom.light),
            dark: shade(cream.dark, bark.dark, blossom.dark)
        )
    }

    /// How much `cream` is blended into a weather veil before it's drawn.
    ///
    /// Higher than `skyMix`, and deliberately: the weather veil is laid over
    /// the *scene* rather than over a flat gradient, so it has real artwork
    /// under it and much less room to be wrong. Pulling each hue toward the
    /// page colour keeps the veil a change of colour rather than of
    /// brightness — the same argument `skyMix` makes.
    ///
    /// **What the contrast check does and does not prove here.**
    /// `tools/check_contrast.py` composites every one of these over the real
    /// scene pixels behind every text row — 922k measurements — and they all
    /// clear 4.5:1 with room. But it was pushed to find out what it is
    /// actually sensitive to, and the answer is: not this. The text capsules
    /// composite *last* at 70–82 % opacity, so they dominate the result; the
    /// veil only starts failing at `weatherMix` 0 combined with an opacity of
    /// 0.8, which is four times anything shipped. So the check confirms these
    /// values are safe rather than standing guard over them. What a bad veil
    /// would really cost is the scenery becoming unreadable *as scenery*, and
    /// that is an eye judgement no checker makes.
    ///
    /// One genuinely reassuring measurement did come out of it: every weather
    /// veil measures *better* than a clear sky, because mixing toward `cream`
    /// moves the background away from the `bark` text rather than toward it.
    /// The tightest pair in the whole matrix, 5.18:1, is a clear-sky pair that
    /// predates weather entirely.
    static let weatherMix: Double = 0.62

    /// The tint for a weather, or nil for the one that is just the sky.
    ///
    /// Every hue here is one the theme already owns, so eight themes get nine
    /// weathers for free and none of them can drift from the palette they
    /// belong to. `mist` and `snow` borrow the page colour itself: fog does
    /// not tint the world, it removes it.
    func weather(_ weather: Weather) -> DualColor? {
        let hue: DualColor
        switch weather {
        case .clear: return nil
        case .overcast: hue = bark
        case .breeze: hue = sage
        case .drizzle, .rain, .storm: hue = night
        case .mist: hue = cream
        case .snow: hue = night
        case .golden: hue = sunshine
        }
        return DualColor(
            light: hue.light.mixed(with: cream.light, amount: Self.weatherMix),
            dark: hue.dark.mixed(with: cream.dark, amount: Self.weatherMix)
        )
    }
}

/// The colour schemes the user can pick between. Every one of these was checked
/// so that body text clears 4.5:1 on each phase background, and `onAccent`
/// clears 4.5:1 on every accent fill, in both light and dark appearance.
enum AppTheme: String, Codable, CaseIterable, Identifiable, PlusLockable {
    case sakura
    case snowdrift
    case matcha
    case cocoa
    case midnight
    case ember
    case lavender
    case ink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sakura: "Sakura"
        case .snowdrift: "Snowdrift"
        case .matcha: "Matcha"
        case .cocoa: "Cocoa"
        case .midnight: "Midnight"
        case .ember: "Ember"
        case .lavender: "Lavender"
        case .ink: "Ink"
        }
    }

    var blurb: String {
        switch self {
        case .sakura: "Soft pinks and cream"
        case .snowdrift: "Paper white and ice"
        case .matcha: "Green tea and mist"
        case .cocoa: "Warm caramel and milk"
        case .midnight: "Cool blues for late nights"
        case .ember: "Sunset amber over charcoal"
        case .lavender: "Lilac dusk"
        case .ink: "Sumi-e greys and one red"
        }
    }

    /// Sakura and Snowdrift ship with the app — two free themes rather than
    /// one, for the same reason the penguin is free.
    var isPlus: Bool {
        switch self {
        case .sakura, .snowdrift: false
        default: true
        }
    }

    var palette: Palette {
        switch self {
        case .sakura:
            Palette(
                cream:    .dual(0.99, 0.96, 0.89, 0.11, 0.10, 0.16),
                blush:    .dual(0.98, 0.80, 0.82, 0.29, 0.18, 0.30),
                blossom:  .dual(0.93, 0.55, 0.66, 0.95, 0.62, 0.73),
                sage:     .dual(0.68, 0.79, 0.63, 0.52, 0.68, 0.55),
                forest:   .dual(0.29, 0.42, 0.34, 0.62, 0.78, 0.65),
                bark:     .dual(0.45, 0.32, 0.24, 0.95, 0.92, 0.86),
                sunshine: .dual(0.97, 0.82, 0.45, 0.86, 0.71, 0.42),
                surface:  .dual(1.00, 1.00, 1.00, 0.22, 0.21, 0.29),
                onAccent: .dual(0.24, 0.15, 0.13, 0.24, 0.15, 0.13),
                night:    .dual(0.72, 0.68, 0.82, 0.05, 0.04, 0.10)
            )
        case .matcha:
            Palette(
                cream:    .dual(0.96, 0.97, 0.90, 0.09, 0.13, 0.11),
                blush:    .dual(0.80, 0.88, 0.72, 0.16, 0.26, 0.19),
                blossom:  .dual(0.60, 0.78, 0.55, 0.64, 0.83, 0.59),
                sage:     .dual(0.72, 0.86, 0.80, 0.52, 0.75, 0.70),
                forest:   .dual(0.20, 0.35, 0.25, 0.62, 0.82, 0.64),
                bark:     .dual(0.24, 0.33, 0.26, 0.91, 0.95, 0.89),
                sunshine: .dual(0.95, 0.85, 0.55, 0.86, 0.76, 0.48),
                surface:  .dual(1.00, 1.00, 1.00, 0.17, 0.23, 0.19),
                onAccent: .dual(0.13, 0.21, 0.15, 0.13, 0.21, 0.15),
                night:    .dual(0.66, 0.74, 0.72, 0.03, 0.07, 0.05)
            )
        case .cocoa:
            Palette(
                cream:    .dual(0.98, 0.94, 0.88, 0.13, 0.10, 0.09),
                blush:    .dual(0.93, 0.81, 0.69, 0.28, 0.20, 0.16),
                blossom:  .dual(0.86, 0.62, 0.44, 0.90, 0.68, 0.50),
                sage:     .dual(0.80, 0.77, 0.60, 0.64, 0.63, 0.48),
                forest:   .dual(0.32, 0.30, 0.20, 0.72, 0.72, 0.56),
                bark:     .dual(0.35, 0.24, 0.18, 0.95, 0.91, 0.85),
                sunshine: .dual(0.94, 0.80, 0.52, 0.85, 0.72, 0.46),
                surface:  .dual(1.00, 1.00, 1.00, 0.24, 0.20, 0.18),
                onAccent: .dual(0.20, 0.12, 0.08, 0.20, 0.12, 0.08),
                night:    .dual(0.74, 0.68, 0.64, 0.07, 0.05, 0.04)
            )
        case .midnight:
            Palette(
                cream:    .dual(0.94, 0.95, 0.99, 0.08, 0.09, 0.15),
                blush:    .dual(0.82, 0.86, 0.97, 0.18, 0.20, 0.34),
                blossom:  .dual(0.68, 0.73, 0.95, 0.72, 0.78, 0.97),
                sage:     .dual(0.66, 0.85, 0.88, 0.52, 0.76, 0.80),
                forest:   .dual(0.24, 0.30, 0.45, 0.68, 0.75, 0.92),
                bark:     .dual(0.24, 0.26, 0.40, 0.91, 0.93, 0.99),
                sunshine: .dual(0.88, 0.82, 0.98, 0.80, 0.74, 0.95),
                surface:  .dual(1.00, 1.00, 1.00, 0.16, 0.18, 0.28),
                onAccent: .dual(0.11, 0.13, 0.25, 0.11, 0.13, 0.25),
                night:    .dual(0.64, 0.70, 0.86, 0.03, 0.04, 0.09)
            )
        case .snowdrift:
            Palette(
                cream:    .dual(0.97, 0.98, 1.00, 0.07, 0.09, 0.14),
                blush:    .dual(0.84, 0.90, 0.97, 0.15, 0.20, 0.30),
                blossom:  .dual(0.62, 0.78, 0.92, 0.66, 0.82, 0.96),
                sage:     .dual(0.72, 0.87, 0.89, 0.56, 0.78, 0.82),
                forest:   .dual(0.20, 0.32, 0.44, 0.68, 0.82, 0.92),
                bark:     .dual(0.17, 0.25, 0.35, 0.93, 0.96, 1.00),
                sunshine: .dual(0.88, 0.92, 0.98, 0.80, 0.86, 0.94),
                surface:  .dual(1.00, 1.00, 1.00, 0.13, 0.17, 0.25),
                onAccent: .dual(0.08, 0.13, 0.21, 0.08, 0.13, 0.21),
                night:    .dual(0.66, 0.73, 0.86, 0.02, 0.04, 0.10)
            )
        case .ember:
            Palette(
                cream:    .dual(1.00, 0.96, 0.90, 0.13, 0.10, 0.09),
                blush:    .dual(0.98, 0.82, 0.70, 0.28, 0.17, 0.13),
                blossom:  .dual(0.94, 0.62, 0.46, 0.96, 0.68, 0.52),
                sage:     .dual(0.90, 0.78, 0.56, 0.78, 0.68, 0.48),
                forest:   .dual(0.42, 0.24, 0.16, 0.88, 0.72, 0.54),
                bark:     .dual(0.34, 0.19, 0.13, 0.98, 0.93, 0.87),
                sunshine: .dual(0.99, 0.82, 0.46, 0.90, 0.74, 0.42),
                surface:  .dual(1.00, 1.00, 1.00, 0.22, 0.17, 0.15),
                onAccent: .dual(0.21, 0.10, 0.06, 0.21, 0.10, 0.06),
                night:    .dual(0.76, 0.66, 0.62, 0.06, 0.04, 0.04)
            )
        case .lavender:
            Palette(
                cream:    .dual(0.98, 0.96, 1.00, 0.11, 0.09, 0.16),
                blush:    .dual(0.90, 0.84, 0.98, 0.23, 0.18, 0.34),
                blossom:  .dual(0.76, 0.64, 0.94, 0.80, 0.70, 0.97),
                sage:     .dual(0.80, 0.84, 0.96, 0.66, 0.72, 0.90),
                forest:   .dual(0.32, 0.26, 0.48, 0.76, 0.72, 0.94),
                bark:     .dual(0.26, 0.20, 0.40, 0.95, 0.93, 1.00),
                sunshine: .dual(0.95, 0.88, 0.99, 0.86, 0.78, 0.94),
                surface:  .dual(1.00, 1.00, 1.00, 0.18, 0.15, 0.28),
                onAccent: .dual(0.13, 0.09, 0.25, 0.13, 0.09, 0.25),
                night:    .dual(0.70, 0.66, 0.86, 0.03, 0.02, 0.10)
            )
        case .ink:
            Palette(
                cream:    .dual(0.98, 0.97, 0.95, 0.11, 0.11, 0.10),
                blush:    .dual(0.88, 0.87, 0.84, 0.21, 0.21, 0.20),
                blossom:  .dual(0.90, 0.50, 0.42, 0.92, 0.54, 0.46),
                sage:     .dual(0.84, 0.84, 0.80, 0.66, 0.67, 0.63),
                forest:   .dual(0.26, 0.26, 0.24, 0.80, 0.80, 0.77),
                bark:     .dual(0.19, 0.19, 0.17, 0.95, 0.95, 0.93),
                sunshine: .dual(0.92, 0.90, 0.84, 0.80, 0.78, 0.72),
                surface:  .dual(1.00, 1.00, 1.00, 0.17, 0.17, 0.16),
                onAccent: .dual(0.14, 0.06, 0.04, 0.14, 0.06, 0.04),
                night:    .dual(0.72, 0.72, 0.76, 0.03, 0.03, 0.03)
            )
        }
    }
}

/// Holds the theme currently in use.
///
/// `Theme` reads its colours through this object, so any view that draws with a
/// `Theme` colour picks up an observation dependency and redraws when the theme
/// changes — without every call site having to thread a palette through.
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var theme: AppTheme = .sakura

    var palette: Palette { theme.palette }

    private init() {}
}
