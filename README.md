# Pawmodoro 🐾

A cozy Pomodoro timer for iOS with a cat or dog buddy. Your buddy naps while you
focus — don't wake them! — and plays during your breaks.

Built with SwiftUI. iOS 17+. No dependencies, no accounts, no data collection.

## Quick start

1. On a Mac, install **Xcode 16+** from the Mac App Store (free).
2. `git clone` this repo, then `open Pawmodoro.xcodeproj`.
3. Press **⌘R** to run in the iPhone simulator.

Or skip Xcode's window and let Claude Code Desktop build and drive the app in
its iOS Simulator pane — see [`docs/SIMULATOR.md`](docs/SIMULATOR.md). Either
way, `tools/run-sim.sh --demo` builds, installs and launches from a terminal.

**New here? Read [`docs/START_HERE.md`](docs/START_HERE.md)** — every step from
cloning this repo to the app being live, in order, with timings.

> Heads up: this code has been syntax-checked but never compiled — there's no Mac
> in the environment it was written in. The first real build is on your machine.

## Features

- Classic Pomodoro loop: focus / short break / long break, all adjustable
- A pixel-art buddy that naps while you focus and sits up on breaks — five to choose from
- Four themes, each with its own light and dark look
- Paw prints track your progress toward the next long break
- Stats: today, last 7 days, current and best streak, 7-day chart
- Six ambient sounds while you work — rain, purring, fireplace, forest, café, ocean
- Chime, haptics, and a local notification when a phase ends, even if the app is backgrounded
- Accurate across backgrounding: the countdown is derived from an absolute end date, not ticks
- Optional auto-start for the next phase
- Accessible: labelled controls, Reduce Motion support, and every text/background pair
  measured at 4.5:1 contrast or better, in every theme
- Free, with an optional one-time "Pawmodoro Plus" unlock and a tip jar

## Docs

| File | What's in it |
|---|---|
| [`docs/START_HERE.md`](docs/START_HERE.md) | **The whole path to launch, in order. Start here.** |
| [`docs/XCODE_WORKFLOW.md`](docs/XCODE_WORKFLOW.md) | Clone, run, pull changes, run on your iPhone, fix build errors |
| [`docs/SIMULATOR.md`](docs/SIMULATOR.md) | Building and testing with Claude Code's iOS Simulator pane, and the debug launch flags |
| [`docs/APP_STORE_LAUNCH_GUIDE.md`](docs/APP_STORE_LAUNCH_GUIDE.md) | First-time App Store submission, start to finish |
| [`docs/LIVE_ACTIVITY.md`](docs/LIVE_ACTIVITY.md) | Add the lock screen / Dynamic Island timer (needs an Xcode step) |
| [`docs/MONETIZATION.md`](docs/MONETIZATION.md) | Setting up the in-app purchases, banking, and sandbox testing |
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
│   ├── Buddy.swift           # the five buddies, their moods and sprite names
│   ├── Ambience.swift        # the six ambient sounds
│   ├── AppTheme.swift        # palettes and the four themes
│   ├── PlusLockable.swift    # what "requires Plus" means
│   ├── PomodoroSettings.swift# user settings, Codable + lenient decoding
│   └── SessionLog.swift      # session history and stats
├── Store/
│   ├── StoreIDs.swift        # product identifiers, in one place
│   └── StoreManager.swift    # StoreKit 2: buying, restoring, entitlements
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
    ├── OnboardingView.swift  # first-launch pages
    ├── PaywallView.swift     # the Pawmodoro Plus unlock
    ├── TipJarView.swift      # optional tips
    └── PlusPickers.swift     # pickers that show locked content with a padlock
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
