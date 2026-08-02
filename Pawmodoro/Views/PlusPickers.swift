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
    var onLockedTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Buddy.allCases) { buddy in
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
                onLockedTap()
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

    var onLockedTap: () -> Void

    var body: some View {
        ForEach(Ambience.allCases) { option in
            row(for: option)
        }
    }

    private func row(for option: Ambience) -> some View {
        let unlocked = store.isUnlocked(option)
        let selected = engine.settings.ambience == option

        return Button {
            if unlocked {
                engine.settings.ambience = option
            } else {
                onLockedTap()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(unlocked ? Theme.blossom : Theme.bark.opacity(0.4))
                Text(option.label)
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 1 : 0.5))
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

    var onLockedTap: () -> Void

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
                onLockedTap()
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
