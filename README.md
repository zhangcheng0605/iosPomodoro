# Pawmodoro 🐾

A cozy Pomodoro timer for iOS with a cat or dog buddy. Your buddy naps while
you focus — don't wake them! — and plays during your breaks.

Built with SwiftUI. iOS 17+. No dependencies, no accounts, no data collection.

## Quick start

1. On a Mac, install **Xcode 16+** from the Mac App Store (free).
2. Clone this repo and open `Pawmodoro.xcodeproj`.
3. Press **⌘R** to run in the iPhone simulator.
4. To run on a real iPhone, select the project → Signing & Capabilities →
   pick your Team (a free Apple ID works for personal devices).

## Features (v1)

- Classic Pomodoro loop: focus / short break / long break, all adjustable
- Cat (Mochi) or dog (Biscuit) buddy that reacts to your timer
- Paw-print progress for completed sessions
- Notification + haptic when a phase ends, even with the app backgrounded
- Timer keeps accurate time across backgrounding (end-date based, not tick based)

## Roadmap & launch

- `docs/PLAN.md` — full product plan and phases
- `docs/APP_STORE_LAUNCH_GUIDE.md` — step-by-step first-time App Store guide
  (developer account, TestFlight, review, common rejections)

## Project layout

```
Pawmodoro/
├── PawmodoroApp.swift        # app entry, re-syncs timer on foreground
├── TimerEngine.swift         # Pomodoro state machine (@Observable)
├── NotificationManager.swift # local "timer done" notifications
├── Theme.swift               # cozy pastel palette
└── Views/
    ├── ContentView.swift     # main screen
    ├── TimerRingView.swift   # countdown ring
    ├── BuddyView.swift       # the cat/dog companion
    └── SettingsView.swift    # durations, buddy choice, haptics
```
