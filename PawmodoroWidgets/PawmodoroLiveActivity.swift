import ActivityKit
import SwiftUI
import WidgetKit

/// The lock screen card and the Dynamic Island.
///
/// **This file is not in any target yet** — it can't be, because the widget
/// extension doesn't exist until someone creates it in Xcode. That is the one
/// step in this whole feature that needs a Mac. Once the target is made, delete
/// the files Xcode generates for it and drag this one in; everything else is
/// already wired. See `docs/LIVE_ACTIVITY.md`.
///
/// `Text(timerInterval:)` is the load-bearing part: the system animates the
/// countdown from the end date on its own, so this stays accurate with no push
/// notifications, no background refresh, and no battery cost.
///
/// Colours are literals here, which is the single exception to the app's
/// go-through-`Theme` rule and a deliberate one: a widget runs in a separate
/// process with no access to `ThemeManager`, and plumbing the palette across
/// would need an App Group for a card the system already tints for us.
struct PawmodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PawmodoroActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Self.blush.opacity(0.35))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(Self.glyph(isBreak: context.state.isBreak))
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.endDate)
                        .font(.title2.monospacedDigit())
                        .frame(width: 72)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(caption(for: context))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(Self.glyph(isBreak: context.state.isBreak))
            } compactTrailing: {
                countdown(to: context.state.endDate)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Text(Self.glyph(isBreak: context.state.isBreak))
            }
        }
    }

    // MARK: Pieces

    private func lockScreen(
        context: ActivityViewContext<PawmodoroActivityAttributes>
    ) -> some View {
        HStack(spacing: 14) {
            Text(Self.glyph(isBreak: context.state.isBreak))
                .font(.system(size: 34))

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.phaseTitle)
                    .font(.headline)
                Text(caption(for: context))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            countdown(to: context.state.endDate)
                .font(.title2.weight(.bold).monospacedDigit())
                .frame(width: 78)
        }
        .padding()
    }

    private func countdown(to end: Date) -> some View {
        // Clamped so a phase that has already finished shows 00:00 rather than
        // an empty range, which `Text(timerInterval:)` will not accept.
        Text(timerInterval: Date.now...max(end, Date.now.addingTimeInterval(1)),
             countsDown: true)
    }

    private func caption(
        for context: ActivityViewContext<PawmodoroActivityAttributes>
    ) -> String {
        let name = context.attributes.buddyName
        return context.state.isBreak
            ? "\(name) is up and about"
            : "\(name) is napping — stay focused"
    }

    /// The app itself no longer uses emoji anywhere, because a simulator
    /// runtime was missing the font and rendered them as boxes. Here they are
    /// safe: a Live Activity only ever renders on a real system that has them.
    private static func glyph(isBreak: Bool) -> String {
        isBreak ? "☕️" : "🐾"
    }

    private static let blush = Color(red: 0.98, green: 0.80, blue: 0.82)
}

@main
struct PawmodoroWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PawmodoroLiveActivity()
    }
}
