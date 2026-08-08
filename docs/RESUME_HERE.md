# Resume here

**Paused 9 Aug 2026, ~03:10 SGT, cleanly.** Branch
`claude/pet-interactions-retention-7caoj8`, everything committed and pushed,
working tree clean, all 24 checkers green, Debug and Release both build.
Nothing is lost.

## The one line to paste next session

> Read docs/RESUME_HERE.md. Finish the two paused features — the buddy
> acrobatics and the Dynamic Type fix — then walk docs/NEXT_UPDATE.md.

---

## Two features are half-built and NEITHER has been seen on screen

They are committed because the tree is coherent, not because they work.
`5d1b017` is the pause commit and its message has the detail.

### 1. Buddy acrobatics — sprites done, wiring done, never watched

The owner asked for buddies to do real tricks when tapped instead of just
smiling. 29 sprites are generated, `Antics.swift` exists, `Antic:7` is in the
enum, `BuddyView` carries the state, everything compiles.

**Nobody — no human and no agent — has watched a single buddy move.**

First job: finish the debug flags that play a move on demand. Without them,
checking this means tapping a buddy six times to reach its signature, for
twelve buddies. Then drive all twelve and *look at the frames in order* — a
tumble that smears at 8fps is a failure even when every frame is right alone.

Watch specifically: the owl (flaps, does not somersault), the hedgehog (rolls
into a ball, reusing its sleeping frame), the penguin's bellyslide, and the
capybara — whose signature is that it **refuses to move**, which must read as
a deliberate joke rather than a bug. Also put a hat and collar on a buddy
mid-tumble: anchors are measured per frame, and a new frame without one sends
the hat somewhere.

### 2. Dynamic Type — partial, and this is the one that should block a release

At the largest **ordinary** text size — no accessibility setting, on a 6.3"
phone — the transport row is clipped by the screen edge and **the start button
is partly unhittable**. At accessibility sizes it is entirely off screen and
nothing scrolls. A Pomodoro timer whose start button cannot be pressed is a
serious bug for anyone who bumped their text size, which is a lot of people.

Two more from the same root cause (a plain centred `VStack` with no
`ScrollView`, overflowing at both ends): the phase chip renders *under* the
toolbar reading "…cus", and ambience glyphs outgrow their backing badly enough
to measure **1.00:1** against scenery and hide the selected-state pill.

**The constraint on resume: the default layout must come out pixel-identical.**
Build the pre-fix source separately and diff it. Do not assert it.

---

## Waiting on the owner — only he can do these

1. **The five regressed ambience loops.** `snowhush` and the three `raintent`
   variants measured *toward* noise after re-voicing; `storm_v2` marginally.
   Numbers cannot settle it — snowhush was near a pure tone before, which may
   have sounded like an artificial drone, so 0.27 flatness may be better
   despite the worse figure. **Listen, then say keep or revert.** One commit
   back either way.
2. **Alternate icons: does switching work twice on a real phone?** On the
   Simulator only the *first* change per install succeeded; later taps never
   reached `setAlternateIconName` at all. Unknown whether that is a wedged
   Simulator or a real bug. One minute to settle.
3. **The Mac App Store** still needs: the sandbox entitlement wired to the
   macOS build, screenshots, and StoreKit tested under sandbox. See
   `docs/MAC_APP_STORE.md`.

---

## What landed on 8-9 Aug (all committed and pushed)

- **The sky answers a finger.** Trace constellations star by star; the moon
  answers by phase. All 48 links across all 7 figures verified working. The
  atlas is still earned by nights — a link is only drawable once one of its
  stars is lit, so no sequence of taps shortcuts it.
- **The sky leans when you tap a chip.** Real parallax, verified by tracking
  24 stars and solving back to the source constants. A sun was drawn because
  there was none. **Clouds cannot move** — they are painted into the scene
  PNGs; that would be a generator change.
- **Crickets and cicadas re-voiced.** 80 % of the old files was inaudible
  sub-150 Hz rumble that set the level for everything else. Flatness 0.375 →
  0.026. Eight other loops re-voiced alongside.
- **Phase Z shipped** — home-screen widget and Live Activity, after the owner
  added the Widget Extension target.
- **The Mac is a real platform** — native macOS, universal binary. It was
  "Designed for iPad" before, which is why every `#if os(macOS)` block in the
  repo was dead code.
- **The Mac audio was never broken.** Measured signal reaching the mixer. The
  Sound Studio was drawing a *sounding* speaker beside a track that had never
  been asked to play, because both channels follow the timer by design.
- Five app icons chosen by CIELAB measurement; a promo code (`zac888`) that
  **cannot reach the App Store** — compiled out of Release entirely, proven by
  grepping both bundles.
- **Two checkers that were lying** — `check_postcard.py` was checking the
  model instead of the card, and `check_swift.py` walked one target of two.
  Both fixed and broken deliberately to prove they catch anything.
- **The 45 MB ceiling was retired**, with the reasoning recorded in
  `CLAUDE.md`. It was never researched — a round number picked while planning
  the audio phase. What survives is the discipline: measure the device Release
  `.app`, say the number, and give growth a reason.

**Device Release: 42.83 MB**, of which 26.9 MB is the 169 `.m4a` files.

---

## How this session worked, and what to repeat

Every builder agent had an **adversarial verifier** behind it, defaulting to
REFUTED. That doubled the wall-clock and was worth it: it caught three
constellations that could never be traced, a sparkle layer burning seven times
the app's entire idle CPU, and a checker that passed while the bug it existed
to catch was present. All three would have shipped.

Each agent gets its **own simulator**, created and deleted by itself — sharing
one causes agents to install builds over each other mid-verification.

**Never drive the Mac app with the mouse.** The owner cannot use his computer
while that happens. Use `AXPress`, or better, add a launch flag so there is
nothing to click.

## Standing traps

- iCloud Desktop breaks codesign: always `-derivedDataPath` outside the repo.
- Generators churn encodings: byte-compare outside the three MP4 timestamp
  atoms (offsets 50-56, 166-172, 266-272) before believing a file changed.
- The Simulator lies about audio formats and cannot hear.
- Transient UI outruns a screenshot: burst-capture, or read durable state from
  the container plist — and note that plist lags `cfprefsd` by tens of
  seconds, so read it with `defaults export` while the app is running.
- `git add -A` sweeps up other agents' in-flight files. Use targeted paths.
