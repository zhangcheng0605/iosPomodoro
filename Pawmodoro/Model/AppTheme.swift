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
}

/// The colour schemes the user can pick between. Every one of these was checked
/// so that body text clears 4.5:1 on each phase background, and `onAccent`
/// clears 4.5:1 on every accent fill, in both light and dark appearance.
enum AppTheme: String, Codable, CaseIterable, Identifiable, PlusLockable {
    case sakura
    case matcha
    case cocoa
    case midnight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sakura: "Sakura"
        case .matcha: "Matcha"
        case .cocoa: "Cocoa"
        case .midnight: "Midnight"
        }
    }

    var blurb: String {
        switch self {
        case .sakura: "Soft pinks and cream"
        case .matcha: "Green tea and mist"
        case .cocoa: "Warm caramel and milk"
        case .midnight: "Cool blues for late nights"
        }
    }

    /// Sakura ships with the app; the rest come with Pawmodoro Plus.
    var isPlus: Bool { self != .sakura }

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
