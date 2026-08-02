# Pawmodoro Delight Plan — the version people stay for

> **Status: phases A, B and C are built and on the default branch.** The buddy
> breathes, blinks and can be petted; the ring is a dial and finishing a session
> throws paw-print confetti; the ambience is visible and the sky follows the
> clock. **Phase D is next** and needs one 30-second step in Xcode from you
> (creating the Widget Extension target) before the code can land — see D1.
> Phase E is unstarted.
>
> The *content* expansion — journey worlds, sound studio, four new buddies,
> four new themes, seasons, postcards — is specified separately in
> [CONTENT_PLAN.md](CONTENT_PLAN.md), which also holds the combined build
> order.

This is the build spec for making Pawmodoro *fancy*: the Pomodoro app people
open to show their friends. It was drafted against the code as of branch
`claude/pawmodoro-ios-simulator-sf815f` (now the default), with every feature
grounded in the files it touches. Build it phase by phase, in order — each
phase is independently shippable and each later phase leans on the earlier
ones.

**How to use this doc (for the implementing session):** work one phase at a
time. Read the phase's "touches" list before starting. After every feature,
verify with `tools/run-sim.sh --demo --headless` and the phase's checklist.
Don't start a phase until the previous one's "done when" bar is met.

---

## The thesis

Anyone can ship a countdown. The three things a competitor can't copy in a
weekend:

1. **A creature, not a clock.** The buddy is the moat. Right now it's two
   static PNGs. Make it a living pet — it breathes, blinks, stretches, gets
   petted, remembers you — and the app stops being a timer with a mascot and
   becomes a pet that keeps you focused.
2. **Touch that answers back.** Every interaction returns motion + haptic +
   sound within 100ms. Drag the ring like a watch bezel. Squish the buttons.
   Feel the cat purr in your hand. iOS 17 SwiftUI + CoreHaptics does all of
   this natively — zero dependencies, which stays true to this repo's rules.
3. **A place, not a screen.** The background becomes a living scene: the sky
   tracks the real time of day, choosing rain ambience makes it rain on
   screen, fireplace throws embers. The app is pleasant to leave open — which
   is exactly what a Pomodoro app needs to be.

Two force multipliers on top:

4. **Presence beyond the app** — the buddy asleep in the Dynamic Island and on
   the lock screen while a session runs ([LIVE_ACTIVITY.md](LIVE_ACTIVITY.md)
   already contains the recipe).
5. **A reason to come back** — a bond level that grows with completed
   sessions and unlocks keepsakes (accessories the buddy wears). Streaks feed
   a relationship, not just a number.

### The five signature moves

The moments a reviewer screenshots. Everything in this plan serves one of
these:

1. Pet the cat and **feel** it purr (continuous haptic).
2. Drag the timer ring like a dial, with clicky 5-minute detents.
3. Pick rain ambience and it **rains on screen**; fireplace throws embers.
4. Mochi asleep in the Dynamic Island with the live countdown.
5. Paw-print confetti + the buddy waking and stretching when a session lands.

### Anti-goals (as binding as the goals)

- **No effect soup.** Every visual stays inside the brand: pastel, pixel,
  rounded, cozy. If an effect would look at home in a crypto app, cut it.
- **No guilt mechanics.** No dead plants, no lost stre?aks shaming, no
  currency. The buddy is never sad *at* the user.
- **No battery tax.** Animation drivers pause when idle or backgrounded.
  Budgets below.
- **No dependency creep.** SwiftUI + Canvas + CoreHaptics + CoreMotion +
  ActivityKit — all system frameworks. No SpriteKit scenes, no packages.
- **No accessibility regression.** Every new animation has a Reduce Motion
  fallback; every text/background pair still clears 4.5:1 in both
  appearances, all four themes.

### Do-not-break list (existing invariants)

- `TimerEngine` derives the countdown from an absolute end `Date`
  ([TimerEngine.swift](../Pawmodoro/TimerEngine.swift)). Nothing here needs
  ticks; celebrations hook phase *transitions*, not time math.
- `PomodoroSettings` decodes leniently — every new field uses
  `decodeIfPresent` + fallback and gets added to `clamped()` if numeric
  ([PomodoroSettings.swift](../Pawmodoro/Model/PomodoroSettings.swift)).
- New persisted keys go in `StorageKeys` and `StorageKeys.all`
  ([LaunchOptions.swift](../Pawmodoro/LaunchOptions.swift)) so
  `-PawmodoroResetState` keeps working.
- Colours resolve through `Theme` / `Palette` only
  ([Theme.swift](../Pawmodoro/Theme.swift),
  [AppTheme.swift](../Pawmodoro/Model/AppTheme.swift)).
- Locked content shows a padlock and opens the paywall — never hidden.
  Anything Plus-gated must also revert in
  `TimerEngine.applyEntitlement(hasPlus:)` when Plus is revoked.
- Audio stays in the `.ambient` session category
  ([SoundPlayer.swift](../Pawmodoro/Audio/SoundPlayer.swift)) — no
  background-audio capability.
- Debug affordances live in `LaunchOptions`, compiled out of Release.

---

## Phase A — A living buddy ✅ built

**Goal:** within ten seconds of looking at the idle screen, something alive
happens. The buddy breathes, blinks, and responds to touch. This phase also
builds the sprite-frame pipeline every later phase draws from.

### A0. Repair the asset pipeline (do first)

Both generators still point at the old authoring environment and will crash
on this Mac:

- [generate_sprites.py:15](../tools/generate_sprites.py) —
  `ASSETS = "/home/user/iosPomodoro/..."`
- [generate_assets.py:13-14](../tools/generate_assets.py) — `RES` and
  `ICONSET` likewise.

Derive all three from the script's own location
(`os.path.dirname(os.path.abspath(__file__)) + "/.."`). Run both to confirm
they reproduce today's assets byte-identically (or near enough — commit any
benign diffs separately so real art changes stay reviewable).

### A1. Sprite frames from the generator

Extend [generate_sprites.py](../tools/generate_sprites.py). Today each buddy
has two hand-built poses (`cat_awake()` … `fox_asleep()`, lines 126–345).
Refactor toward *pose variants with small deltas* rather than whole new
drawings:

- **Frame set per buddy** (imageset naming `buddy_{species}_{pose}_{n}`,
  existing `buddy_{species}_awake/asleep` stay as frame 0 for compatibility):
  - `asleep_breathe` — 1 extra frame: body one grid-pixel squashed, ear dip.
  - `awake_blink` — 1 extra frame: open eyes → `eyes_closed()`.
  - `stretch_0..1` — the wake-up: front paws forward, rump up (2 frames).
  - `happy_0..1` — petting/celebration: eyes closed-smiling, tail up,
    1px bounce (2 frames).
- **Constraint that pays off in Phase E:** keep the head bounding box fixed
  across all frames of a posture (awake-family vs asleep-family). Accessory
  overlays then align across every frame with one anchor per posture.
- **Coverage:** cat and dog (the free buddies) get the full set. Bunny,
  hamster, fox get `asleep_breathe` + `awake_blink` minimum in this phase;
  full sets are a fast follow since the deltas are formulaic.
- Also generate `fx_zzz` — a tiny pixel "z z z" sprite (three sizes stacked),
  and `fx_heart` — a 7×7 pixel heart. Both used below.

### A2. The animator

New file `Pawmodoro/Animation/BuddyAnimator.swift` (the folder-synced project
picks it up — no pbxproj edit). An `@Observable` state machine:

- States: `napping` (breathe loop ~0.5fps + rare ear twitch), `idle` (blink
  every 3–7s with jitter, occasional tail flick), `waking` (stretch sequence,
  plays once on focus→break transition), `happy` (2s burst, triggered by
  petting or celebration).
- Driven by `TimelineView(.periodic(from:by:))` in the view — **not** a Timer
  in the model — so rendering pauses automatically off-screen. Gate on
  `scenePhase == .active`. Frame rates: 2fps for loops, 8fps for
  stretch/happy bursts.
- `BuddySprite` ([BuddySprite.swift](../Pawmodoro/Views/BuddySprite.swift))
  gains a `pose`/`frame` parameter; keep the emoji fallback for unknown
  assets so Plus buddies missing a pose degrade to their base sprite, never
  to a blank.
- Reduce Motion: animator freezes on frame 0 of the current state; the
  existing bob in [BuddyView.swift](../Pawmodoro/Views/BuddyView.swift)
  already respects this — fold the bob into the animator so there's one
  motion owner.

### A3. Petting

Gesture on the sprite in `BuddyView`:

- **On a break / idle (buddy awake):** tap or stroke → `happy` burst +
  floating `fx_heart` particles (2–3, drift up, fade) + purr haptic + a soft
  short purr audio blip (reuse `purr.wav` at low volume with a 0.5s fade-out;
  respect the ambience mute state).
- **During focus (buddy napping):** first touch → one ear twitch + caption
  swaps to "shhh — Mochi is sleeping" + a single soft warning haptic. The
  buddy *never wakes*; the fiction stays gentle. No penalty.
- Haptics via the new `HapticsDirector` (Phase B owns the full design; stub
  here with `UIImpactFeedbackGenerator` pulses so A ships standalone).
- Accessibility: sprite gets a labelled custom action ("Pet Mochi") that
  triggers the same response; label reflects state ("Mochi, napping").

### A4. Kill the tofu boxes

The iOS 26.3 simulator runtime is missing the primary emoji font, so every
emoji `Text` renders as `?` boxes in the pane:

- [BuddyView.swift:31](../Pawmodoro/Views/BuddyView.swift) `Text("💤")` →
  the generated `fx_zzz` sprite, drifting up on a slow loop next to the
  napping buddy.
- [OnboardingView.swift](../Pawmodoro/Views/OnboardingView.swift) pages use
  🐾 and ⏳ → replace with `pawprint.fill` SF Symbol tinted `Theme.blossom`
  and a generated pixel hourglass (or reuse a buddy sprite — the welcome page
  showing a sleeping Mochi is better onboarding anyway).
- `Buddy.pickerLabel` embeds emoji — drop the emoji from the label (the
  pickers already show sprites elsewhere).

### Done when

- Idle screen: blink within 10s. Focus running: visible breathing within 5s.
- Petting answers in <100ms with motion + haptic; napping buddy shh's
  instead.
- No emoji tofu anywhere in the simulator pane.
- Reduce Motion on: everything static, petting still responds (opacity-only).
- All 4 themes × light/dark screenshot-checked; Release config still builds.

**New debug flags:** none needed — `--demo` reaches everything in seconds.

---

## Phase B — A timer you can feel ✅ built

**Goal:** the controls feel physical. This is the phase reviewers describe
with the word "juicy".

### B1. The ring is a dial

In [TimerRingView.swift](../Pawmodoro/Views/TimerRingView.swift), when
`runState == .idle` and the phase is `.focus`:

- Drag anywhere on the ring → angle (atan2 from center) maps to
  `settings.focusMinutes` across 5…90 (the range `clamped()` already
  enforces), snapping to 5-minute detents.
- Each detent: `.sensoryFeedback(.selection, trigger:)` + the numerals roll
  via the `contentTransition(.numericText())` already in place.
- A small knob dot sits at the progress head while dragging; ring is
  read-only while running or paused (a nudge haptic + no-op if tried).
- Do the same for break durations *only* via the existing Settings screen —
  one dial on the main screen, not three.
- Accessibility: `accessibilityAdjustableAction` increments/decrements by 5
  minutes; announce the new duration.
- Persist through the existing `settingsDidChange()` path (it already
  refreshes `remaining` when idle).

### B2. Squish everything

- A shared `SquishyButtonStyle` (new file `Pawmodoro/Views/Style/`):
  `scaleEffect(pressed ? 0.92 : 1)` with `.spring(response: 0.25,
  dampingFraction: 0.5)`, applied to the play/reset/skip controls and
  ambience chips in [ContentView.swift](../Pawmodoro/Views/ContentView.swift).
- Play button gains a pressed-in shadow reduction (it already has the soft
  shadow) — press should feel like pushing a real button down.
- Paw prints: when one fills, stamp it — spring scale 1.4→1.0 with a slight
  rotation, one soft haptic tick. The `filledPaws` animation hook exists at
  [ContentView.swift:96-112](../Pawmodoro/Views/ContentView.swift).
- Reduce Motion: styles collapse to opacity changes.

### B3. The haptic score

New `Pawmodoro/Haptics/HapticsDirector.swift`, wrapping `CHHapticEngine` with
graceful fallback to the UIKit generators (simulator and old devices):

- **start** — one firm soft-thump.
- **detent** — light tick (ring dial, pickers).
- **final ten** — from `remaining <= 10` while running: one soft heartbeat
  pulse per second, intensity easing up. Drive from the engine's existing
  0.25s ticker; no new timers.
- **complete** — success triple-tap (replaces the bare
  `UINotificationFeedbackGenerator` call in
  [TimerEngine.swift:223](../Pawmodoro/TimerEngine.swift)).
- **purr** — continuous pattern, 1.5s, intensity modulated by a slow sine
  (Phase A's petting upgrades to this).
- Everything respects `settings.hapticsEnabled`. Engine must survive haptics
  engine resets (`CHHapticEngine` stops on backgrounding — restart lazily).
- Note: haptics are a no-op in the simulator — verify on device; everything
  else in this phase is visible in the pane.

### B4. Completion choreography

The dopamine moment. When a focus phase completes *naturally*:

- `TimerEngine` publishes a `completionEvent` (an `@Observable` value with a
  UUID + completed phase + `filledPaws`) set inside `completePhase()` —
  the engine stays UI-free; views react to the value change.
- `CelebrationView` overlay (new file, mounted in `ContentView`'s ZStack):
  1. Paw-print confetti: `Canvas` + `TimelineView(.animation)` burst of
     30–40 paw glyphs in the phase-accent colour family, 1.6s, gravity +
     spin, then the driver stops (no idling TimelineView).
  2. The buddy plays `stretch → happy` (Phase A animator).
  3. On long-break entry: a small card springs up — "Cycle complete · 4/4
     paws · streak 8" (data from `SessionLog`) — dismissible by tap,
     auto-dismisses in 4s.
- Tap anywhere skips the whole sequence. Reduce Motion: no confetti, card
  crossfades.
- Break completions get a lighter beat: chime + buddy settles back to
  napping-ready, no confetti (confetti stays special).

### B5. Breathe with the buddy (breaks)

While a break runs: the ring's stroke pulses on a 4s-in / 6s-out sine
(scale 1.00→1.03 + opacity), the buddy's breathing animation syncs to the
same clock, status line becomes "breathe with Mochi". A `breatheOnBreaks`
setting (default on; forced off under Reduce Motion). New settings field →
lenient decoding + StorageKeys unchanged (it lives inside
`pawmodoro.settings`).

### Done when

- Setting a duration never opens Settings: drag, click, done — and it
  persists across relaunch.
- Every control visibly responds to press; completion sequence lands in
  <2s total and is skippable.
- `-PawmodoroCelebrate` (new debug flag: fires a synthetic natural completion
  ~2s after launch) makes the choreography iterable without waiting 25s.
- Device pass: purr + heartbeat + detents feel distinct.

**New debug flags:** `-PawmodoroCelebrate` (add to `LaunchOptions`, document
in [CLAUDE.md](../CLAUDE.md)'s table).

---

## Phase C — The living scene ✅ built

**Goal:** the background is worth looking at. Ambience becomes visible.
Time of day is real.

### C1. The sky

Replace the flat two-stop gradient (`Theme.background(for:)` in
[Theme.swift:43](../Pawmodoro/Theme.swift)) with `Theme.sky(for phase:,
at date:)`:

- Four day-parts (dawn 5–8, day 8–17, dusk 17–21, night 21–5) each define a
  gradient pair *per theme* — new `Palette` entries in
  [AppTheme.swift](../Pawmodoro/Model/AppTheme.swift) (e.g. `skyDawnTop`…),
  filled for all four themes, both appearances. Phase wash (blush/sage/
  sunshine) blends on top at reduced opacity so focus/break still reads.
- Blend between day-parts over ~20 real minutes (a `TimelineView(.periodic
  (by: 60))` at the scene root is plenty; no per-frame work).
- **Contrast rule holds:** body text sits on the same regions it does today —
  re-measure `bark` on the darkest and lightest sky stop of every theme ×
  appearance; adjust stops, not the text.
- Night (any theme): a handful of slow twinkling star/firefly dots (Canvas,
  ≤12 points, 0.5fps opacity wobble).

### C2. Weather = ambience, visible

A single `AmbientSceneView` layered above the sky, below the UI, active
**only** while the timer runs and that ambience is selected (the same rule
[`refreshAmbience()`](../Pawmodoro/TimerEngine.swift) already applies to
sound — visuals and audio switch together):

- **rain** — 25–35 falling streaks, two depth layers, theme-tinted.
- **fireplace** — 10–15 ember motes rising with flicker + a barely-visible
  warm pulse on the lower gradient stop.
- **ocean** — two slow sine shimmer bands drifting horizontally.
- **forest** — 6–8 drifting leaves with lazy rotation.
- **cafe** — 3 steam wisps curling from the bottom corner.
- **purr** — occasional floating hearts (shares Phase A's `fx_heart`).
- Implementation: one `Canvas` + `TimelineView(.animation(minimumInterval:
  1/30))`; a plain-struct particle system, no allocations per frame; hard cap
  40 particles; driver stops when `runState != .running`, when backgrounded,
  and under Reduce Motion (falls back to a static, very subtle tint).
- Shader garnish (optional, keep behind a small flag in code): a
  `distortionEffect` droplet-on-glass pass for rain — iOS 17 SwiftUI Metal,
  still zero dependencies. Cut it the moment it fights the pixel aesthetic.

### C3. Parallax garnish

`CoreMotion` tilt shifts sky ±2pt, particles ±4pt, buddy ±1pt. Off under
Reduce Motion, off when idle. One `MotionSource` object, low update rate
(10Hz), stopped on background.

### Done when

- Screenshot of every (theme × appearance × day-part) reads as the same
  brand; text contrast re-measured ≥4.5:1 everywhere.
- Rain visibly rains while a rain-ambience focus runs; nothing moves when
  the timer is idle; CPU stays quiet (spot-check: no TimelineView firing
  when `runState == .idle` — assert in debug).
- `-PawmodoroStillScene` (new flag) freezes all scene motion for stable
  screenshot comparison; `-PawmodoroClock <hour>` (new flag, value read via
  `UserDefaults.standard.integer` — simctl's `-Key value` form) pins the
  day-part for checking all four quickly.

**New debug flags:** `-PawmodoroStillScene`, `-PawmodoroClock <0-23>`.

---

## Phase D — Presence beyond the app ← next

**Goal:** the buddy exists on the lock screen and in the Dynamic Island.
Highest-visibility feature per line of code; the recipe already exists in
[LIVE_ACTIVITY.md](LIVE_ACTIVITY.md).

### D1. The widget-extension target

The one step that genuinely wants Xcode: **File → New → Target → Widget
Extension**, name `PawmodoroWidgets`, "Include Live Activity" checked, per
LIVE_ACTIVITY.md Step 1. Hand-editing a second target into
`project.pbxproj` is possible but that doc's own warning stands — one slip
can make the project unopenable. **Recommended split:** the user performs the
30-second target creation; the implementing session does everything else.
(`NSSupportsLiveActivities` can be added as the
`INFOPLIST_KEY_NSSupportsLiveActivities = YES` build setting on the app
target — the project uses generated Info.plists, so that part *is* a safe
text edit.)

### D2. Beyond the doc's baseline

The doc's version uses emoji (☕️/🐾) — which both hits the simulator font gap
and undersells the brand. Upgrade:

- Mini buddy sprites in the activity: compact-leading shows the buddy
  asleep (focus) / awake (break). The extension needs its own asset copies —
  extend `generate_sprites.py` to also emit
  `PawmodoroWidgets/Assets.xcassets` with the two base poses per buddy
  (small, ~40KB total).
- Lock-screen presentation: sprite + phase title + `Text(timerInterval:)`
  countdown + `ProgressView(timerInterval:)` bar — all system-animated, zero
  updates from the app, which matches the absolute-end-date engine exactly.
- Tint from the active theme: pass the three accent RGB values through
  `ActivityAttributes` (fixed at start) so the island matches the app.
- Engine hooks exactly as LIVE_ACTIVITY.md Step 5 (start/update on `start()`,
  end on `pause/reset/skip/completePhase`). Add a `liveActivityEnabled`
  setting (default on) → lenient decoding.

### D3. Home-screen widget (small, same target, stretch)

Today's paws + streak + buddy sprite, `TimelineProvider` refreshing on day
change and via `WidgetCenter` pokes from `SessionLog.add()`. Requires an App
Group **only** if it reads live data — simplest v1: reload on app foreground,
no App Group. If an App Group is added, `StorageKeys` moves to
`UserDefaults(suiteName:)` — a deliberate, separate commit.

### Done when

- Start a focus session, ⌘L in the simulator: lock-screen activity with
  sprite + live countdown. iPhone 15 Pro+ sim: island compact shows buddy +
  time; long-press expands correctly.
- Pause/reset/skip/complete all end or update the activity — no orphaned
  activities after force-quit (staleDate covers it).
- App still builds and runs when the extension target is *absent* (all hooks
  behind `#if canImport(ActivityKit)` + availability checks won't cover a
  missing target — instead: keep shared files in the app target compiling
  standalone; the extension is additive).

---

## Phase E — Bond & keepsakes

**Goal:** a reason to return tomorrow that isn't guilt. The buddy's bond
grows with completed sessions; milestones unlock accessories it actually
wears.

### E1. Bond level

- Derived, not stored: thresholds over `log.totalSessions`
  ([SessionLog.swift](../Pawmodoro/Model/SessionLog.swift)) — 10 / 30 / 75 /
  150 / 300 → levels 1–5 with names ("acquainted" → "inseparable").
- Shown as a small heart meter on the stats screen
  ([StatsView.swift](../Pawmodoro/Views/StatsView.swift)) and in the
  celebration card when it advances.

### E2. Accessories

- Generator work: 5 accessories (red bandana, night-cap, scarf, tiny crown,
  round glasses) drawn once per *posture family* per buddy as transparent
  overlay imagesets (`acc_{name}_{species}_{posture}`) — the Phase A
  head-anchor constraint makes them line up across frames.
- `BuddySprite` composites the chosen accessory above the base frame.
- Unlocks: bandana at bond 1, night-cap at 2, scarf at 3 — free. Crown +
  glasses ship in a **Plus "wardrobe" pack** (padlock in the picker, opens
  the paywall; `applyEntitlement` reverts a Plus accessory to none on
  revocation).
- Chosen accessory persists as a new `accessory` field in
  `PomodoroSettings` (lenient decoding), picker row in
  [SettingsView.swift](../Pawmodoro/Views/SettingsView.swift) using the
  existing `PlusPickers` padlock pattern.
- Unlock moment rides the Phase B celebration card ("Mochi's bond grew —
  the red bandana!") with the buddy immediately wearing it for the happy
  burst.

### E3. No economy

Deliberate scope cut: no coins, no shop, no consumables. Bond = sessions,
full stop. It keeps the app honest, keeps App Review simple, and the
restraint *is* the brand.

### Done when

- `-PawmodoroBond <sessions>` (new flag, `-Key value` form seeding the
  session log length) previews every level and unlock without grinding.
- Accessory aligns on every frame of every pose for cat + dog (full frame
  sets) and on base poses for the Plus buddies.
- Plus revocation path: with a Plus accessory equipped, launching without
  entitlement reverts to none (same pattern as buddy/ambience/theme in
  [TimerEngine.applyEntitlement](../Pawmodoro/TimerEngine.swift)).

**New debug flags:** `-PawmodoroBond <n>`.

---

## Cross-cutting engineering notes

**Performance budget.** One `TimelineView` owner per concern (animator,
scene); all of them gate on `scenePhase == .active` and stop when their
subject is idle. Particle caps: 40 scene, 40 confetti, 3 hearts. Sprite
loops ≤2fps, bursts ≤8fps, particles ≤30fps. Debug-assert that no driver
fires while `runState == .idle` and the scene is unmounted.

**Verification loop.** Every phase: `tools/run-sim.sh --demo --headless`,
drive the changed screen, screenshot light + dark
(`xcrun simctl ui <UDID> appearance dark`) × all four themes for visuals.
Fast timers make full cycles 25s. Haptics need a device pass — collect them
at the end of Phase B and Phase A's petting. Release config must build clean
at every phase boundary (`-configuration Release`) since all flags compile
out.

**New debug flags summary** (all follow the `LaunchOptions` pattern; valued
flags read through `UserDefaults` which parses simctl's `-Key value` form
natively): `-PawmodoroCelebrate`, `-PawmodoroStillScene`,
`-PawmodoroClock <hour>`, `-PawmodoroBond <sessions>`. Add each to the table
in [CLAUDE.md](../CLAUDE.md) as it lands.

**Settings fields added across phases** (`breatheOnBreaks`,
`liveActivityEnabled`, `accessory`): each is `decodeIfPresent` with a
fallback, added to `CodingKeys`, and — being inside `pawmodoro.settings` —
needs no new storage key. Only genuinely new keys (none currently planned)
touch `StorageKeys`.

**Sprite pipeline ownership.** Every pixel continues to come out of
`tools/generate_sprites.py` / `generate_assets.py` — edit the script, never
the PNG. The Phase A refactor (pose deltas, fixed head anchors, a
`build_frames(buddy)` driver) is what keeps 5 buddies × ~8 frames × 5
accessories tractable.

---

## Backlog (after E — noted, not yet planned)

- StandBy mode (landscape charging = bedside buddy clock) — needs the widget
  target from Phase D.
- Alternate app icons per buddy (generator emits them; Settings row).
- Onboarding v2: the buddy walks between pages, reacting to swipes — cheap
  once the animator exists.
- Apple Watch companion.
- Opt-in strict focus ("Mochi stirs if you leave") — design carefully against
  the no-guilt rule.
- App Store preview video choreography (the five signature moves, 15s).
- Lo-fi ambience track — synthesized, to stay license-free.

## Suggested session plan for the implementing model

| Session | Scope | Riskiest bit |
|---|---|---|
| 1 | A0–A2 (pipeline fix, frames, animator) | generator refactor regressing existing sprites |
| 2 | A3–A4 + polish pass (petting, tofu fixes) | gesture vs. scroll conflicts |
| 3 | B1–B3 (dial, squish, haptics) | dial math at the 0/12-o'clock wrap |
| 4 | B4–B5 (celebration, breathing) | overlay z-order with sheets |
| 5 | C1–C2 (sky, ambient scenes) | contrast re-measurement across 32 combos |
| 6 | C3 + perf audit | battery/CPU when idle |
| 7 | D (user does the 30s Xcode step first) | target membership + asset duplication |
| 8 | E (bond, accessories) | overlay alignment across frames |

Each session ends with: simulator screenshots (both appearances), Release
build check, CLAUDE.md flag-table update, and a commit.
