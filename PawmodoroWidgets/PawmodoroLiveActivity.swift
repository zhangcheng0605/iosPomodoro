import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The lock screen card and the Dynamic Island.
///
/// `Text(timerInterval:)` is the load-bearing part: the system animates the
/// countdown from the end date on its own, so this stays accurate with no push
/// notifications, no background refresh, and no battery cost. It is the same
/// property that makes `TimerEngine` correct — an absolute end `Date`, never a
/// count of ticks — reaching one process further out.
///
/// Colours are literals here, which is the single exception to the app's
/// go-through-`Theme` rule and a deliberate one: a widget runs in a separate
/// process with no access to `ThemeManager`, and plumbing the palette across
/// would need an App Group for a card the system already tints for us.
///
/// **The buddy is drawn, not spelled.** The first version of this file used
/// 🐾 and ☕️ for the two phases, reasoning that a Live Activity only renders on
/// a real system with the emoji font. True, but it gave the lock screen a
/// glyph the app itself does not use anywhere — and it made the whole thing
/// unverifiable in the simulator, whose iOS 26.3 runtime has no emoji font and
/// drew a `?` box. The sprites are already in this extension's catalog for the
/// home widget, so the card shows the actual animal: asleep while you focus,
/// up and about on a break, which is what the captions underneath already say.
struct PawmodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PawmodoroActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Self.blush.opacity(0.35))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    buddy(context: context, size: 38)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.endDate)
                        .font(.title2.monospacedDigit())
                        .frame(width: 76, alignment: .trailing)
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
                buddy(context: context, size: 20)
            } compactTrailing: {
                countdown(to: context.state.endDate)
                    .monospacedDigit()
                    .frame(width: 46, alignment: .trailing)
            } minimal: {
                buddy(context: context, size: 20)
            }
        }
    }

    // MARK: Pieces

    private func lockScreen(
        context: ActivityViewContext<PawmodoroActivityAttributes>
    ) -> some View {
        HStack(spacing: 14) {
            buddy(context: context, size: 44)

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
                .frame(width: 88, alignment: .trailing)
                .layoutPriority(1)
        }
        .padding()
    }

    /// The countdown the system animates for us.
    ///
    /// **Every slot keeps an explicit width, and that is not incidental.**
    /// `.fixedSize()` looks like the tidier answer and is wrong here: a timer
    /// text reports an ideal width big enough for its widest future rendering,
    /// which overflowed the lock screen's `HStack` and clipped the countdown
    /// off the card entirely — the one element the card exists for, gone, with
    /// nothing else about the layout looking wrong. The widths are generous
    /// enough for `50:00`, the longest phase this app has, and
    /// `monospacedDigit` keeps them from twitching as the digits change.
    ///
    /// Seconds shown as `––` are *not* this bug either, but the first
    /// explanation written here was wrong and is worth recording as wrong: it
    /// said the dimmed always-on state, and that waking the screen brought
    /// them back. It does not. A verifier saw `mm:––` on a fully bright,
    /// awake lock screen in five samples over four minutes, and then in the
    /// **compact Dynamic Island on an active home screen** — the same island
    /// that had shown `24:36` a few minutes earlier. A fresh twenty-five
    /// second activity counts seconds the whole way.
    ///
    /// So the trigger is activity *age* — the system throttling how often it
    /// re-renders a long-running Live Activity — not screen state, and not
    /// anything this view controls. Left as an observation rather than a
    /// second guess dressed as a fact.
    private func countdown(to end: Date) -> some View {
        // Clamped so a phase that has already finished shows 00:00 rather than
        // an empty range, which `Text(timerInterval:)` will not accept.
        Text(timerInterval: Date.now...max(end, Date.now.addingTimeInterval(1)),
             countsDown: true)
    }

    /// The buddy at the size the slot allows. Napping through a focus phase,
    /// awake on a break — the same two poses the home widget uses for night
    /// and day, and the same pair the captions describe.
    private func buddy(
        context: ActivityViewContext<PawmodoroActivityAttributes>,
        size: CGFloat
    ) -> some View {
        Image(WidgetSprite.buddy(
            context.attributes.buddyID,
            asleep: !context.state.isBreak
        ))
        .interpolation(.none)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    }

    private func caption(
        for context: ActivityViewContext<PawmodoroActivityAttributes>
    ) -> String {
        let name = context.attributes.buddyName
        return context.state.isBreak
            ? "\(name) is up and about"
            : "\(name) is napping — stay focused"
    }

    private static let blush = Color(red: 0.98, green: 0.80, blue: 0.82)
}

/// Asset-name resolution shared by the two widgets.
///
/// The rule both of them need is the same: an identity this build has no
/// sprite for degrades to the cat rather than to a blank rectangle. That
/// happens for a buddy added after the extension was built (the app and its
/// extension update together, but a Live Activity started by a newer app can
/// outlive an older extension in memory), and for a corrupted store.
enum WidgetSprite {
    static func buddy(_ id: String, asleep: Bool) -> String {
        // Luna keeps a watch rather than a bed; she has her own pose for it.
        let wanted = asleep
            ? (id == "owl" ? "buddy_owl_watch" : "buddy_\(id)_asleep")
            : "buddy_\(id)_awake"
        if UIImage(named: wanted) != nil { return wanted }
        return asleep ? "buddy_cat_asleep" : "buddy_cat_awake"
    }
}
