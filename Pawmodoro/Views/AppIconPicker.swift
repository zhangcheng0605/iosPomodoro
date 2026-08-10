import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The icons Pawmodoro can wear on a Home screen.
///
/// The `rawValue` of each case is the `.appiconset` name, which is three
/// things at once: what `tools/generate_assets.py` writes, what
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` lists in both build
/// configurations, and what `setAlternateIconName(_:)` is handed at runtime.
/// `tools/check_icons.py` walks all three and fails if any of them disagrees —
/// a name that only matches in two places builds and installs perfectly, and
/// then does nothing when tapped.
enum AppIconChoice: String, CaseIterable, Identifiable {
    /// The one on everybody's Home screen today. Its `rawValue` is the primary
    /// icon's name rather than an alternate's; `systemName` turns it into the
    /// `nil` UIKit wants.
    case sakura = "AppIcon"
    case matcha = "AppIconMatcha"
    case ember = "AppIconEmber"
    case snowdrift = "AppIconSnowdrift"
    case ink = "AppIconInk"

    var id: String { rawValue }

    /// The theme the icon is drawn in — the same name the theme picker shows,
    /// because they are the same palette and pretending otherwise would invent
    /// a second vocabulary for one set of colours.
    var displayName: String {
        switch self {
        case .sakura: "Sakura"
        case .matcha: "Matcha"
        case .ember: "Ember"
        case .snowdrift: "Snowdrift"
        case .ink: "Ink"
        }
    }

    var blurb: String {
        switch self {
        case .sakura: "The one you have"
        case .matcha: "Green tea"
        case .ember: "Sunset amber"
        case .snowdrift: "Paper and ice"
        case .ink: "Charcoal and one red — the dark one"
        }
    }

    /// What UIKit calls this icon: `nil` for the primary one.
    var systemName: String? { self == .sakura ? nil : rawValue }

    /// The imageset the picker draws, written by the same generator run that
    /// writes the icon. Derived from `rawValue` rather than listed, so there
    /// is no second table to fall out of step.
    var previewAsset: String { "iconpreview_\(rawValue)" }

    static func matching(systemName: String?) -> AppIconChoice {
        guard let systemName else { return .sakura }
        return AppIconChoice(rawValue: systemName) ?? .sakura
    }
}

/// Reading and writing the Home-screen icon.
///
/// The one UIKit touchpoint that is *not* in `Platform.swift`, and only
/// because that file is being edited on another branch as this lands. It
/// belongs there — see the diff at the bottom of this file — and moving it is
/// a five-line change that deletes the `#if os(iOS)` below.
enum AppIcons {

    /// False on the Mac, and on the rare iOS configuration that refuses.
    static var supported: Bool {
        #if os(iOS)
        return UIApplication.shared.supportsAlternateIcons
        #else
        return false
        #endif
    }

    /// What is on the Home screen right now.
    ///
    /// **The system is the only store.** There is deliberately no
    /// `StorageKeys` entry for this: iOS already persists the choice, and a
    /// second copy could only ever disagree with it — offload the app and
    /// reinstall it and the icon is back to Sakura while a saved preference
    /// would still be claiming Ink. A settings screen that lies about the
    /// Home screen is worse than one that has to ask.
    static var current: AppIconChoice {
        #if os(iOS)
        return .matching(systemName: UIApplication.shared.alternateIconName)
        #else
        return .sakura
        #endif
    }

    /// Put `choice` on the Home screen.
    ///
    /// `done` reports whether the icon is now the one that was asked for, and
    /// runs after iOS has had its say.
    ///
    /// **iOS can refuse, and the error it hands back is not the answer.**
    /// Driving this on the Simulator produced two different failures from the
    /// *alert* machinery rather than from the icon change:
    /// `NSPOSIXErrorDomain 35` out of
    /// `-[LSIconAlertManager iconChangeAlertTokenForIdentity:error:]`, where
    /// the icon genuinely did not change; and `NSPOSIXErrorDomain 5`,
    /// "couldn't load upcall bundle principal class", out of
    /// `CoreServicesUIUpcallEmbedded` — where the icon *did* change and only
    /// the announcement failed.
    ///
    /// So the error is a bad oracle in both directions, and the completion
    /// asks the system what the icon actually is instead. That is the same
    /// rule `current` follows and the reason nothing here is stored: there is
    /// one source of truth and it is not this app.
    static func set(_ choice: AppIconChoice, done: @escaping (Bool) -> Void) {
        #if os(iOS)
        guard choice != current else { return done(true) }
        UIApplication.shared.setAlternateIconName(choice.systemName) { error in
            #if DEBUG
            if let error { print("icon: \(choice.rawValue) — \(error)") }
            #endif
            done(current == choice)
        }
        #else
        done(false)
        #endif
    }
}

/// The Settings section that changes the Home-screen icon.
///
/// ## Why this is its own control, and not tied to the theme
///
/// Every icon change pops a system alert — "You have changed the icon for
/// Pawmodoro" — that the app cannot suppress, cannot restyle, and cannot
/// batch. That single fact decides the whole design, and it argues *against*
/// the obvious idea of following the theme:
///
/// - **The theme picker is a browsing surface.** It applies on tap because
///   that is the only way to see a theme; people run down all eight comparing
///   them. Tying the icon to it turns a comparison into eight modal alerts,
///   each one landing in the middle of the look somebody was taking. That is
///   strictly worse than a picker, not better.
/// - **The Home screen is outside the app.** Changing something a user sees
///   when they are not using Pawmodoro needs to be asked for in those terms.
///   Choosing Ink because you like green tea at night is not consent to have
///   your Home screen rearranged.
/// - **They are separately wanted.** Ink inside and Sakura outside is a
///   perfectly ordinary taste, and coupling them makes it unreachable.
///
/// An icon grid does not have the theme picker's problem, which is the other
/// half of the argument: a swatch cannot show you a theme, but a preview *is*
/// the icon, at the size it will be seen. There is nothing left to learn by
/// applying it, so a deliberate choice is one tap and exactly one alert — and
/// the alert then says something true about what was just asked for, which is
/// the only version of it that is not a nag.
///
/// The footer says the alert is coming. Warning somebody about an interruption
/// you cannot prevent is the whole of the mitigation available.
struct AppIconSection: View {
    /// Read from the system rather than stored, and re-read after every
    /// change, so a refused or failed change corrects itself on screen.
    @State private var current: AppIconChoice = .sakura

    /// True when iOS turned the last change down. Cleared by the next one that
    /// works, so it is never stale.
    @State private var refused = false

    @ViewBuilder
    var body: some View {
        if AppIcons.supported {
            Section {
                ForEach(AppIconChoice.allCases) { choice in
                    row(for: choice)
                }
            } header: {
                Text("Home screen icon")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if refused {
                        Text("iOS turned that one down and kept the icon you "
                             + "had. It does that sometimes just after an icon "
                             + "has been changed — a moment later usually works.")
                            .foregroundStyle(Theme.blossom)
                    }
                    Text("Changing the icon is announced by an alert from iOS "
                         + "itself. Pawmodoro has no way to turn that off, so "
                         + "it only ever changes the icon when you ask it to — "
                         + "never with the theme, and never on its own.")
                }
            }
            .onAppear { current = AppIcons.current }
        }
    }

    private func row(for choice: AppIconChoice) -> some View {
        Button {
            AppIcons.set(choice) { worked in
                current = AppIcons.current
                refused = !worked
            }
        } label: {
            HStack(spacing: 12) {
                preview(for: choice)

                VStack(alignment: .leading, spacing: 1) {
                    Text(choice.displayName)
                        .foregroundStyle(Theme.bark)
                    Text(choice.blurb)
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.6))
                }

                Spacer()

                if choice == current {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blossom)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(choice.displayName))
        .accessibilityAddTraits(choice == current ? [.isSelected] : [])
    }

    /// The real artwork, at the size a Home screen draws it.
    ///
    /// From `iconpreview_*`, not from the `.appiconset` — an app icon set's
    /// renditions live in the compiled catalogue under a name
    /// `UIImage(named:)` will not return, so `Image("AppIconMatcha")` draws
    /// nothing at all. It fails silently and it fails *identically* for every
    /// row, which is why the first build of this picker looked like five
    /// copies of one pink square rather than like a bug.
    private func preview(for choice: AppIconChoice) -> some View {
        Image(choice.previewAsset)
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.bark.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - The diff Platform.swift should take
//
// `AppIcons` above is the app's only `UIApplication` call outside the fence,
// and it is here rather than in `Platform.swift` because that file was being
// edited on another branch when this landed. Whoever merges the two should
// move these three members across verbatim and delete the `#if os(iOS)` from
// this file:
//
//     extension Platform {
//         /// Alternate Home-screen icons: iOS only, and iOS may still say no.
//         static var supportsAlternateIcons: Bool {
//             #if os(iOS)
//             return UIApplication.shared.supportsAlternateIcons
//             #else
//             return false
//             #endif
//         }
//
//         /// The alternate icon in use, or nil for the primary one.
//         static var alternateIconName: String? {
//             #if os(iOS)
//             return UIApplication.shared.alternateIconName
//             #else
//             return nil
//             #endif
//         }
//
//         /// Set it. The completion runs after iOS has shown its own alert.
//         static func setAlternateIcon(_ name: String?,
//                                      done: @escaping () -> Void) {
//             #if os(iOS)
//             UIApplication.shared.setAlternateIconName(name) { _ in done() }
//             #else
//             done()
//             #endif
//         }
//     }
//
// It is a fifth deliberate no-op on the Mac, for the same reason as the other
// four: macOS has no alternate application icons, and the section that would
// offer them does not render there.
