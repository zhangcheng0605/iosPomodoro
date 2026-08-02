# Building Pawmodoro with Claude Code's iOS Simulator

Claude Code Desktop can build Pawmodoro, run it in an iPhone simulator, tap
through it, and look at the result — in a pane next to the conversation. This is
the fastest way to work on the app: you describe a change, Claude makes it, runs
it, and you both look at the same screen.

The repo is set up for it. This page is what you need to know.

---

## What you need

| | |
|---|---|
| **Claude Desktop** | v1.24012.0 or later (**Claude → Check for Updates**) |
| **Plan** | Pro, Max or Team — the pane is in public beta and isn't on Enterprise |
| **A Mac** | Apple's simulator doesn't exist on Windows or Linux |
| **Xcode** | With the iOS platform installed. If no simulators are listed, run `xcodebuild -downloadPlatform iOS` |

**This has to run on your Mac.** Cloud and SSH sessions — including the one that
wrote this file — run on a machine with no simulators on it. The simulator pane
is local sessions only.

## Starting

1. Clone the repo locally if you haven't:

   ```sh
   git clone https://github.com/zhangcheng0605/iosPomodoro.git
   cd iosPomodoro
   ```

2. In Claude Code Desktop, open the **Code** tab and start a session with
   `iosPomodoro` as the project folder.

3. Ask for something that involves running it:

   > Build Pawmodoro and run it in the simulator with `-PawmodoroDemo`, then show
   > me a focus session finishing.

   The pane opens by itself when the app launches. The first time Claude uses a
   device it asks permission; after that it taps and screenshots freely.

To pick a device, say so — "run it on the iPhone SE simulator" — otherwise
Claude picks one. Up to four panes per session.

The pane is interactive: click and drag to tap and swipe, `Cmd+Shift+H` for
Home, `Cmd+S` for a screenshot to your Desktop. You and Claude drive the same
device, so wait for the "Claude is using this device" badge to clear before
tapping, or you'll change what it's looking at mid-check.

## Launch options

A Pomodoro app is painful to test honestly: the first focus phase is 25 minutes
long. So debug builds take launch flags that collapse the wait. They live in
`Pawmodoro/LaunchOptions.swift` and are compiled out of Release builds — in a
shipping build every one of them is a `false` constant.

| Flag | What it does |
|---|---|
| `-PawmodoroDemo` | The three below, together. Start with this one. |
| `-PawmodoroFastTimers` | Minutes count as seconds: a 25-minute focus phase ends in 25 seconds, so a full cycle takes about a minute |
| `-PawmodoroSkipOnboarding` | Straight to the timer |
| `-PawmodoroSuppressNotificationPrompt` | No permission alert on the first start |
| `-PawmodoroUnlockPlus` | Pretend Pawmodoro Plus was bought |
| `-PawmodoroSeedStats` | Two weeks of session history, so the stats screen has bars to draw |
| `-PawmodoroResetState` | Clean-install state without deleting the app |

Ask for them by name — "run it with `-PawmodoroSeedStats` and open the stats
screen" — or use the script:

```sh
tools/run-sim.sh --demo                     # build, install, launch
tools/run-sim.sh --demo -PawmodoroSeedStats
tools/run-sim.sh --device "iPhone SE (3rd generation)"
tools/run-sim.sh --headless                 # skip Apple's Simulator window
```

With no `--device` it targets an already-booted simulator, which is the one the
pane is showing.

## Things that are different in a simulator

- **The paywall says the store isn't available.** Expected. StoreKit only sees
  the products in `Pawmodoro.storekit` when the app is launched *from Xcode*
  with the scheme's StoreKit configuration attached; a build installed with
  `simctl` has none. To check the paid content, launch with
  `-PawmodoroUnlockPlus`; to test buying for real, press ⌘R in Xcode.
- **Haptics do nothing.** There's no Taptic Engine to buzz.
- **Sound comes out of your Mac.** Ambience only plays while a timer runs.
- **Notifications** work, but you have to background the app (`Cmd+Shift+H`) to
  see the banner.
- **Don't sign into real accounts** on a device Claude drives — it screenshots
  the screen, and those go to Anthropic under your normal retention settings.

## When the pane doesn't open

- Say the goal outright: "run the app in the iOS Simulator and tap through the
  settings screen."
- Check Xcode's simulators exist by opening Apple's Simulator app on its own.
- Confirm the Desktop version, and that the session is local rather than cloud
  or SSH.
- The pane also lives under **Views → iOS Simulator** in the session toolbar,
  with an **Attach simulator** button.

## Turning it off

Claude's simulator access can be switched off in the desktop app's settings.
Organizations can disable it for everyone with the `disableMobileSimulatorTools`
managed setting, and the `requireCoworkFullVmSandbox` policy disables the pane
entirely.

---

Reference: [Test iOS apps in the simulator](https://code.claude.com/docs/en/desktop-ios-simulator).
