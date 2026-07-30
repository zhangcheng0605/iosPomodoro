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
- Cat (Mochi) or dog (Biscuit) pixel-art buddy that naps while you focus and sits up on breaks
- Cozy pastel theme in light mode, warm plum night theme in dark mode
- Paw prints track your progress toward the next long break
- Stats: today, last 7 days, current and best streak, 7-day chart
- Ambient sound while you work — rain, purring, or a fireplace
- Chime, haptics, and a local notification when a phase ends, even if the app is backgrounded
- Accurate across backgrounding: the countdown is derived from an absolute end date, not ticks
- Optional auto-start for the next phase
- Accessible: labelled controls, Reduce Motion support, and every text/background pair
  measured at 4.5:1 contrast or better

## Docs

| File | What's in it |
|---|---|
| [`docs/XCODE_WORKFLOW.md`](docs/XCODE_WORKFLOW.md) | Clone, run, pull changes, run on your iPhone, fix build errors |
| [`docs/APP_STORE_LAUNCH_GUIDE.md`](docs/APP_STORE_LAUNCH_GUIDE.md) | First-time App Store submission, start to finish |
| [`docs/LIVE_ACTIVITY.md`](docs/LIVE_ACTIVITY.md) | Add the lock screen / Dynamic Island timer (needs an Xcode step) |
| [`docs/PRIVACY.md`](docs/PRIVACY.md) | Privacy policy text + how to publish it |
| [`docs/PLAN.md`](docs/PLAN.md) | Product plan, phases, what's left |

## Project layout

```
Pawmodoro/
├── PawmodoroApp.swift        # app entry; re-syncs the timer on foreground
├── TimerEngine.swift         # Pomodoro state machine (@Observable)
├── NotificationManager.swift # local "timer done" notifications
├── Theme.swift               # palette, light + dark, contrast-checked
├── Model/
│   ├── Buddy.swift           # cat / dog, their moods and sprite names
│   ├── Ambience.swift        # rain / purr / fireplace
│   ├── PomodoroSettings.swift# user settings, Codable + lenient decoding
│   └── SessionLog.swift      # session history and stats
├── Audio/SoundPlayer.swift   # ambience loops + phase-end chime
├── Resources/*.wav           # synthesized audio (see tools/generate_assets.py)
├── Assets.xcassets/          # app icon + buddy sprites
└── Views/
    ├── ContentView.swift     # main screen
    ├── TimerRingView.swift   # countdown ring
    ├── BuddyView.swift       # the companion and its caption
    ├── BuddySprite.swift     # sprite image, with emoji fallback
    ├── SettingsView.swift    # durations, buddy, ambience, behaviour
    ├── StatsView.swift       # streaks and history
    └── OnboardingView.swift  # first-launch pages
```

## Regenerating assets

Every asset is generated, not hand-drawn or recorded, so it's all original content
with nothing to license. To restyle, edit the script and re-run:

```sh
pip install pillow numpy
python3 tools/generate_assets.py    # app icon + ambience loops and chime
python3 tools/generate_sprites.py   # buddy sprites
```

The sprites are true pixel art: drawn on a 40x40 logical grid and upscaled with
nearest-neighbour, so adding a third buddy is about twenty lines of shapes.
