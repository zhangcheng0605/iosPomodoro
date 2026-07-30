# Pawmodoro 🐾

A cozy Pomodoro timer for iOS with a cat or dog buddy. Your buddy naps while you
focus — don't wake them! — and plays during your breaks.

Built with SwiftUI. iOS 17+. No dependencies, no accounts, no data collection.

## Quick start

1. On a Mac, install **Xcode 16+** from the Mac App Store (free).
2. `git clone` this repo, then `open Pawmodoro.xcodeproj`.
3. Press **⌘R** to run in the iPhone simulator.

Full walkthrough, including running on a real iPhone and pulling later changes:
**[`docs/XCODE_WORKFLOW.md`](docs/XCODE_WORKFLOW.md)**.

> Heads up: this code has been syntax-checked but never compiled — there's no Mac
> in the environment it was written in. The first real build is on your machine.

## Features

- Classic Pomodoro loop: focus / short break / long break, all adjustable
- Cat (Mochi) or dog (Biscuit) buddy that reacts to what the timer is doing
- Paw prints track your progress toward the next long break
- Stats: today, last 7 days, current and best streak, 7-day chart
- Ambient sound while you work — rain, purring, or a fireplace
- Chime, haptics, and a local notification when a phase ends, even if the app is backgrounded
- Accurate across backgrounding: the countdown is derived from an absolute end date, not ticks
- Optional auto-start for the next phase

## Docs

| File | What's in it |
|---|---|
| [`docs/XCODE_WORKFLOW.md`](docs/XCODE_WORKFLOW.md) | Clone, run, pull changes, run on your iPhone, fix build errors |
| [`docs/APP_STORE_LAUNCH_GUIDE.md`](docs/APP_STORE_LAUNCH_GUIDE.md) | First-time App Store submission, start to finish |
| [`docs/PLAN.md`](docs/PLAN.md) | Product plan, phases, what's left |

## Project layout

```
Pawmodoro/
├── PawmodoroApp.swift        # app entry; re-syncs the timer on foreground
├── TimerEngine.swift         # Pomodoro state machine (@Observable)
├── NotificationManager.swift # local "timer done" notifications
├── Theme.swift               # cozy pastel palette
├── Model/
│   ├── Buddy.swift           # cat / dog, and their moods
│   ├── Ambience.swift        # rain / purr / fireplace
│   ├── PomodoroSettings.swift# user settings, Codable + lenient decoding
│   └── SessionLog.swift      # session history and stats
├── Audio/SoundPlayer.swift   # ambience loops + phase-end chime
├── Resources/*.wav           # synthesized audio (see tools/generate_assets.py)
└── Views/
    ├── ContentView.swift     # main screen
    ├── TimerRingView.swift   # countdown ring
    ├── BuddyView.swift       # the companion
    ├── SettingsView.swift    # durations, buddy, ambience, behaviour
    ├── StatsView.swift       # streaks and history
    └── OnboardingView.swift  # first-launch pages
```

## Regenerating assets

The app icon and the four audio loops are generated, not hand-drawn or recorded —
so they're original content with nothing to license. To change them, edit and re-run:

```sh
pip install pillow numpy
python3 tools/generate_assets.py
```

The emoji buddy art is a deliberate placeholder; commissioned sprites are the one
remaining art task before launch.
