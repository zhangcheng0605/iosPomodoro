import SwiftUI

/// Pickers for content that may be locked behind Pawmodoro Plus.
///
/// Locked items are shown rather than hidden — seeing Momo greyed out with a
/// padlock is what makes the unlock worth buying — and tapping one opens the
/// paywall instead of silently doing nothing.

// MARK: - Buddy

struct BuddyPicker: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store

    /// Called when the user taps something they don't own yet.
    /// Passed the catalogue entry for the thing tapped, or nil for something
    /// Plus gates but the cart does not sell. The caller shows the unlock
    /// sheet for the first and the paywall for the second.
    var onLockedTap: (CatalogItem?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Soot appears here the day she comes inside and not before —
                // see `Buddy.roster(strayJoined:)` for why she is the one
                // exception to showing locked content.
                // `|| selected` so the picker can never be showing a row-set
                // that excludes the buddy currently in use, which
                // `-PawmodoroBuddy stray` would otherwise do.
                ForEach(Buddy.roster(
                    strayJoined: engine.stray.hasJoined
                        || engine.settings.buddy == .stray
                )) { buddy in
                    tile(for: buddy)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }

    private func tile(for buddy: Buddy) -> some View {
        let unlocked = store.isUnlocked(buddy)
        let selected = engine.settings.buddy == buddy

        return Button {
            if unlocked {
                engine.settings.buddy = buddy
            } else {
                onLockedTap(buddy.catalogItem)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    BuddySprite(buddy: buddy, sleeping: false, size: 54)
                        .opacity(unlocked ? 1 : 0.4)
                        .grayscale(unlocked ? 0 : 0.8)

                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.onAccent)
                            .padding(4)
                            .background(Circle().fill(Theme.blossom))
                            .offset(x: 4, y: -2)
                    }
                }
                Text(engine.settings.displayName(for: buddy))
                    .font(.caption2.weight(selected ? .bold : .regular))
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 0.9 : 0.5))
            }
            .frame(width: 74)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Theme.blossom.opacity(0.28) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Theme.blossom : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            unlocked
                ? "\(engine.settings.displayName(for: buddy)) the \(buddy.kind)"
                : "\(engine.settings.displayName(for: buddy)) the \(buddy.kind), locked, requires Pawmodoro Plus"
        )
    }
}

// MARK: - Ambience

struct AmbiencePicker: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store

    /// Passed the catalogue entry for the thing tapped, or nil for something
    /// Plus gates but the cart does not sell. The caller shows the unlock
    /// sheet for the first and the paywall for the second.
    var onLockedTap: (CatalogItem?) -> Void

    var body: some View {
        ForEach(Ambience.allCases) { option in
            row(for: option)
        }
    }

    private func row(for option: Ambience) -> some View {
        // A found loop is free but not given: Plus does not open it and the
        // cart does not stock it. Both roads have to agree it is yours.
        let unlocked = store.isUnlocked(option) && engine.hasFound(option)
        let selected = engine.settings.ambience == option
        let suggested = unlocked && !selected && engine.weather.suggests == option

        return Button {
            if unlocked {
                engine.settings.ambience = option
            } else {
                // Ambience is Plus-only and the cart does not stock it — the
                // sound shelf is Phase W's business, not the magpie's. Nil
                // sends the caller to the paywall, unchanged.
                onLockedTap(nil)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(unlocked ? Theme.blossom : Theme.bark.opacity(0.4))
                Text(option.label)
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 1 : 0.5))
                // Why, in three words. The list keeps its order — see the
                // Phase V As-built note: a settings list that rearranges
                // itself with the sky is the app moving your furniture.
                if suggested, let note = engine.weather.suggestionNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Theme.bark.opacity(0.5))
                }
                Spacer()
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.4))
                } else if selected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blossom)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme

struct ThemePicker: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store

    /// Passed the catalogue entry for the thing tapped, or nil for something
    /// Plus gates but the cart does not sell. The caller shows the unlock
    /// sheet for the first and the paywall for the second.
    var onLockedTap: (CatalogItem?) -> Void

    var body: some View {
        ForEach(AppTheme.allCases) { theme in
            row(for: theme)
        }
    }

    private func row(for theme: AppTheme) -> some View {
        let unlocked = store.isUnlocked(theme)
        let selected = engine.settings.theme == theme

        return Button {
            if unlocked {
                engine.settings.theme = theme
            } else {
                onLockedTap(theme.catalogItem)
            }
        } label: {
            HStack(spacing: 12) {
                swatch(for: theme)
                    .opacity(unlocked ? 1 : 0.45)

                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.displayName)
                        .foregroundStyle(Theme.bark.opacity(unlocked ? 1 : 0.5))
                    Text(theme.blurb)
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.6))
                }

                Spacer()

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.bark.opacity(0.4))
                } else if selected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blossom)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Reads each theme's own palette directly, so every row previews itself
    /// rather than the theme that happens to be active.
    private func swatch(for theme: AppTheme) -> some View {
        let palette = theme.palette
        return HStack(spacing: -6) {
            Circle().fill(palette.blossom.color).frame(width: 20, height: 20)
            Circle().fill(palette.sage.color).frame(width: 20, height: 20)
            Circle().fill(palette.sunshine.color).frame(width: 20, height: 20)
        }
        .overlay(
            Capsule()
                .strokeBorder(palette.bark.color.opacity(0.25), lineWidth: 1)
                .padding(-2)
        )
    }
}
