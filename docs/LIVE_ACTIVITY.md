# Adding the Live Activity (lock screen + Dynamic Island)

> **The code is already written.** Everything below except *Step 1* has been
> done in the repo:
>
> - `Pawmodoro/LiveActivity/PawmodoroActivityAttributes.swift` — shared type
> - `Pawmodoro/LiveActivity/LiveActivityController.swift` — the app side, wired
>   into `TimerEngine.start/pause/reset/skipPhase/completePhase`
> - `PawmodoroWidgets/PawmodoroLiveActivity.swift` — the widget UI, **in no
>   target yet** because the target doesn't exist
> - `INFOPLIST_KEY_NSSupportsLiveActivities = YES` on both app build configs,
>   so Step 2 is done too
> - A "Lock screen countdown" toggle in Settings → Behaviour
>
> So the whole job is now: **create the target (Step 1), delete the files Xcode
> generates for it, drag in `PawmodoroWidgets/PawmodoroLiveActivity.swift`, and
> tick `PawmodoroActivityAttributes.swift` for both targets.** Five minutes
> rather than forty-five. The app builds and runs right now without any of it —
> `Activity.request` simply returns nil with no extension present.
>
> **The same step now also ships the home-screen buddy** (keepsake plan,
> Phase AL). When you drag files into the target, include
> `PawmodoroWidgets/PawmodoroHomeWidget.swift` and the
> `PawmodoroWidgets/Assets.xcassets` catalog beside it (buddy sprites,
> copied byte-for-byte by `tools/generate_widget_assets.py`, plus the
> December night-cap). No further wiring: the widget is a pure function
> of the wall clock, reads the buddy's identity from the
> `group.com.pawmodoro` App Group *if you add one* (both targets →
> Signing & Capabilities → App Groups), and falls back to the cat
> without it. The App Group is optional in v1 — skip it and everything
> still works, just always as the cat.


A running Pomodoro on the lock screen is the single best remaining feature for
this app — you can see the countdown without unlocking your phone.

**Why this isn't already in the repo:** a Live Activity requires a second build
target (a Widget Extension). Adding a target means new build phases, an embed
step, and a second Info.plist — and I can't compile or open Xcode in the
environment I work in. If I hand-wrote that into `project.pbxproj` and got one
detail wrong, the *whole project* might fail to open, which would block you from
running the app at all. Xcode generates all of it correctly in about 30 seconds,
so that's the safer split: you make the target, paste in the code below.

Do this **after** you've confirmed the app builds and runs.

## Step 1 — Create the target

1. In Xcode: **File → New → Target…**
2. Choose **Widget Extension**, click Next.
3. Product Name: `PawmodoroWidgets`
4. **Check "Include Live Activity"**. **Uncheck** "Include Configuration App Intent".
5. Finish. When Xcode asks to activate the new scheme, click **Cancel** (keep the
   Pawmodoro app scheme selected so ⌘R still runs the app).

Xcode creates a `PawmodoroWidgets/` folder with placeholder files. You'll replace
their contents below.

## Step 2 — Let the app declare Live Activity support

Select the **Pawmodoro** app target → **Info** tab → hover a row, click **+**, and add:

| Key | Type | Value |
|---|---|---|
| `Supports Live Activities` (`NSSupportsLiveActivities`) | Boolean | `YES` |

Without this the app can't start an activity at runtime.

## Step 3 — Shared attributes file

This type must be visible to **both** targets. Create
`Pawmodoro/LiveActivity/PawmodoroActivityAttributes.swift` with the content
below, then select it in the Project navigator and, in the **File inspector** on
the right, tick **both** "Pawmodoro" and "PawmodoroWidgets" under Target
Membership.

```swift
import ActivityKit
import Foundation

struct PawmodoroActivityAttributes: ActivityAttributes {
    /// Values that change while the activity is live.
    struct ContentState: Codable, Hashable {
        var phaseTitle: String
        var isBreak: Bool
        var endDate: Date
    }

    /// Fixed for the life of the activity.
    var buddyName: String
}
```

## Step 4 — The widget UI

Replace the contents of the generated `PawmodoroWidgetsLiveActivity.swift` (name
may vary slightly) with this. Delete any other generated widget/attributes files
so there's exactly one `@main` in the extension.

Note `Text(timerInterval:)` — the system animates the countdown itself, so the
activity stays accurate with **no push notifications and no background updates**.

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct PawmodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PawmodoroActivityAttributes.self) { context in
            // Lock screen / notification banner presentation.
            HStack(spacing: 14) {
                Text(context.state.isBreak ? "☕️" : "🐾")
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.phaseTitle)
                        .font(.headline)
                    Text(context.state.isBreak
                         ? "\(context.attributes.buddyName) is playing"
                         : "\(context.attributes.buddyName) is napping")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .frame(width: 78)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.98, green: 0.80, blue: 0.82).opacity(0.35))
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.isBreak ? "☕️" : "🐾").font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .frame(width: 72)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseTitle).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(context.state.isBreak ? "☕️" : "🐾")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Text(context.state.isBreak ? "☕️" : "🐾")
            }
        }
    }
}

@main
struct PawmodoroWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PawmodoroLiveActivity()
    }
}
```

## Step 5 — Start and stop it from the app

Add `Pawmodoro/LiveActivity/LiveActivityController.swift` (app target only):

```swift
import ActivityKit
import Foundation

/// Wraps ActivityKit so TimerEngine doesn't need to know the details.
@available(iOS 16.2, *)
final class LiveActivityController {
    static let shared = LiveActivityController()
    private var activity: Activity<PawmodoroActivityAttributes>?

    private init() {}

    func startOrUpdate(phase: TimerEngine.Phase, buddyName: String, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = PawmodoroActivityAttributes.ContentState(
            phaseTitle: phase.title,
            isBreak: phase.isBreak,
            endDate: endDate
        )
        let content = ActivityContent(state: state, staleDate: endDate)

        if let activity {
            Task { await activity.update(content) }
            return
        }
        activity = try? Activity.request(
            attributes: PawmodoroActivityAttributes(buddyName: buddyName),
            content: content,
            pushType: nil
        )
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
```

Then hook it into `TimerEngine`:

- In `start()`, right after `NotificationManager.shared.schedulePhaseEnd(...)`:

  ```swift
  if #available(iOS 16.2, *) {
      LiveActivityController.shared.startOrUpdate(
          phase: phase, buddyName: settings.buddy.name, at: end
      )
  }
  ```
  (match the parameter label to the method above — `endDate: end`)

- In `pause()`, `reset()`, `skipPhase()`, and at the top of `completePhase()`:

  ```swift
  if #available(iOS 16.2, *) {
      LiveActivityController.shared.end()
  }
  ```

## Step 6 — Test it

Live Activities work in the **simulator** (iOS 16.2+) and on device. Start a
timer, then lock the screen (**⌘L** in the simulator). For the Dynamic Island,
pick an iPhone 15 Pro or newer simulator.

If nothing appears, check in order: `NSSupportsLiveActivities` is set on the
**app** target, the shared attributes file has **both** target memberships, and
Live Activities aren't disabled in **Settings → Pawmodoro**.

## Things worth knowing

- Live Activities are capped at **8 hours** of display, then the system ends them.
  A Pomodoro phase is far shorter, so this never bites.
- `staleDate` tells the system when the content is out of date — set to the phase
  end, which is what the code above does.
- The `Task { }` blocks mutate `activity` from a non-isolated class. That's fine in
  the Swift 5 language mode this project uses; if you ever switch the project to
  Swift 6 strict concurrency, mark the controller `@MainActor`.
- **This code has not been compiled** — same caveat as the rest of the repo. If
  Xcode complains, send me the error and I'll fix it.
