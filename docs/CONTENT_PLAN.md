# Pawmodoro Content Plan — a world, not a wallpaper

Companion to [DELIGHT_PLAN.md](DELIGHT_PLAN.md) (which covers *feel*: the
living buddy, the tactile timer, the visible ambience — phases A–C built,
D–E pending). This document is the *content* expansion: worlds, sound, cast,
seasons, keepsakes. It exists to answer one question — **why would someone
pick Pawmodoro over every other pomodoro app, and keep opening it?**

## The edge: focus is a journey

Every pomodoro app counts down. Forest grows a tree. Finch walks a bird.
Nobody does this:

> **Your buddy is a tiny traveler. Every focus session is a leg of a voyage
> across a hand-built world.** While you focus, a little boat (or balloon, or
> night train) crosses the scene — its position *is* the timer. Finish
> sessions and you arrive somewhere new: a harbor isle, a deep wood, a castle
> in the clouds. Places you unlock stay yours to focus in. Arrivals mail you
> a postcard.

This reframes the whole product. The countdown becomes a crossing. The streak
becomes a travelogue. The reward for focusing isn't a number going up — it's
*getting somewhere*. That is the sentence for the App Store page:
**"The focus timer that takes you somewhere."**

Everything below serves that frame or deepens the existing one (a pet with a
personality, art that answers touch).

### Reference images — mood only, never shipped

Five reference paintings live with the product owner (island castle at sea; a
top-down forest with a river; a pastel bunny village; a white-stone castle
town; a floating sky-island). Two are signed by their artists. **They are
mood boards: palette, composition, and feeling.** Nothing is copied, traced,
or embedded. Every shipped asset continues to come out of `tools/generate_*.py`
as original procedural pixel art — the same "nothing to license" stance the
README already commits to. When a scene below cites an image, it cites the
*idea* (an island, a waterfall, a floating rock), which no one owns.

---

## Phase F — Worlds & the Journey (the centerpiece) ✅ built

### F1. The scenery pipeline

New generator `tools/generate_scenes.py`, same discipline as the sprite
pipeline: indexed-palette drawing on a logical grid, nearest-neighbour
upscale, emitted into the asset catalog.

- **Grid:** 132×286 logical pixels (iPhone portrait aspect), upscaled ×3 to
  396×858. Chunky pixel scenery matches the buddy's 40×40 art and dodges the
  uncanny gap between painted backgrounds and pixel sprites.
- **Indexed palettes, like the sprites:** each scene draws into a grid of
  palette indices (SKY, SEA, FOAM, GRASS, TREE, TRUNK, STONE, ROOF, WINDOW,
  SNOW, …), then `to_png` maps indices → RGBA. This is what makes day-part
  variants nearly free: **each scene exports four PNGs (dawn/day/dusk/night)
  from one drawing and four palette dicts**, plus a night-only pass that
  lights the windows (WINDOW index → warm glow at night). Lit windows after
  dark are the single highest-charm-per-pixel trick in the whole plan.
- **Two layers per scene:** `scene_{id}_{part}` (background) and an optional
  `scene_{id}_fg` foreground strip (a dock post, grass fringe, branch) drawn
  at the bottom edge. The buddy and controls sit between the layers → instant
  depth, and the existing CoreMotion parallax (DELIGHT C3) moves them at
  different rates.
- **The text safe zone — a hard rule:** all scenery detail lives in the
  bottom ~38% and the top ~12% of the canvas. The middle band, where the
  ring, countdown and captions sit, stays sky/water gradient. The generator
  *enforces* this (assert no non-sky index in the band); `check_contrast.py`
  grows a scene mode that loads every exported PNG, samples the text band
  under every day-part, composites the existing ring glow, and fails under
  4.5:1 — same promise, now measured against real pixels.
- **Layer order in `ContentView`:** phase gradient → sky wash (existing) →
  scenery background → weather particles (existing `AmbientSceneView`, which
  is hereby the *weather* layer) → UI → scenery foreground strip. Scenery is
  a static image: zero per-frame cost.
- **Buddy perch:** each scene declares a perch offset + optional prop
  (`perch_{id}` sprite: a dock edge, a mushroom cap, a castle ledge, a spring
  tub). The buddy naps *in the scene*, somewhere different each place.

### F2. The eight scenes

Free route — **The Home Waters** (unlock by cumulative natural focus
sessions, `log.totalSessions`: 0 / 6 / 16 / 30):

1. **Meadow Home** (0 — the new default). Rolling hills, one crooked-chimney
   cottage, a fence, wildflowers. The buddy's house. Replaces the bare
   gradient as the out-of-box experience.
2. **Whispering Woods** (6). Pines, birches, a stream cutting the bottom
   third, mushroom clusters, a log bridge. Perch: a big mushroom cap.
   *(Mood: the top-down forest reference.)*
3. **Harbor Isle** (16). Open sea, sparkle-dot waves, two small islets with a
   stub tower, gulls as 2-px chevrons. Perch: dock planks with a rope post.
   *(Mood: the island-castle reference.)* **Vignette: a sailboat.**
4. **Blossom Village** (30). Pastel hillside village, terraced flowerbeds,
   a waterfall thread, paper lanterns (lit at night). Perch: a veranda
   cushion. *(Mood: the bunny-village reference.)*

Plus route — **The Far Isles** (45 / 65 / 90 / 120; padlocked on the scene
picker, tap → paywall, per house rules):

5. **Sunstone Keep** (45). White-stone stairs and towers, teal domes, banner
   flags, ivy. Perch: a sun-warmed wall ledge. *(Mood: the castle-town
   reference.)*
6. **Cloudspire** (65). A floating rock island trailing roots, one spire
   castle, clouds drifting *below* the island. Perch: the grass fringe at
   the rock's edge. *(Mood: the sky-castle reference.)* **Vignette: a hot-air
   balloon.**
7. **Starfall Peaks** (90). Night-leaning mountain ridge; meteor streaks join
   the starfield timeline (one every ~40s — rare enough to feel lucky).
   **Vignette: the night train**, windows lit, crossing a viaduct.
8. **Moonlit Onsen** (120). Stone hot spring, steam wisps (reuse café steam),
   snow monkeys? no — **capybaras in the far pool** (2 tiny background
   sprites). Perch: the buddy's own tub. Pairs with the capybara buddy (H).

### F3. The travel vignette — the second hand of the clock

While a focus session runs, a small vehicle sprite crosses the scene's
horizon line, position lerped by `engine.progress` — **the boat's position is
the countdown**. Glance at the screen from across the room and the boat tells
you where you are. It docks exactly on the chime. Break phases drift it back
out. Implementation: one 16×10 sprite per route vehicle (sailboat, balloon,
train), drawn by the sprite generator; position updates ride the existing
0.25s ticker redraw — no new timeline. Reduce Motion: vehicle appears at
waypoints (¼, ½, ¾) instead of gliding.

### F4. Journey bookkeeping

- `scene` field in `PomodoroSettings` (lenient decoding, as ever), scene
  picker row in Settings — unlocked scenes selectable, locked show progress
  ("6 more sessions") for the free route or a padlock for Plus.
- Unlocks derive from `log.totalSessions` — nothing new persisted, nothing to
  corrupt, `-PawmodoroResetState` keeps working for free.
- A one-time "arrival" moment when a session's completion crosses a
  threshold: the celebration card says "You've reached Harbor Isle", the new
  scene fades in behind the confetti. Arrival = the scene switches to the new
  unlock automatically (changeable after).
- Debug: `-PawmodoroScene <id>`, `-PawmodoroUnlockScenes` (all eight),
  and the existing `-PawmodoroSeedStats` already sets totalSessions.

**Done when:** all 8 scenes × 4 day-parts pass the extended contrast check;
the vignette docks on the chime under `-PawmodoroFastTimers`; every perch
places the buddy plausibly in light and dark; scene switching never moves the
ring or controls by a pixel.

---

## Phase G — The Sound Studio

Today: six synthesized ambience loops, one channel. The upgrade: **music as a
second channel, and mixing as the fancy bit.**

### G1. New loops (all synthesized in `generate_assets.py` — recipes below
keep them license-free)

Music (new category):
- **Paws & Chill** — lo-fi study loop, ~70bpm, 8 bars: Rhodes-ish chords
  (sine + 2 detuned overtones, slow pitch LFO for tape wobble), vinyl
  crackle (sparse filtered pops), soft kick (40Hz sine thump) and brushed
  snare (short noise burst, band-passed).
- **Music Box** — a sparse lullaby over I–vi–IV–V; plucked sine with fast
  exponential decay + 2 harmonics; celesta register.
- **Night Train** — rhythmic double clack (~52bpm, band-passed noise taps),
  brown-noise rumble underneath, a distant two-note horn every ~25s. Made
  for Starfall Peaks; works everywhere.
Ambience (extend the existing six):
- **Bamboo Grove** — breathy filtered wind with slow swell, a resonant
  bamboo knock every ~8–12s (shishi-odoshi), sparse high bird chirps.
- **Snowfall** — near-subliminal low-passed noise bed, occasional soft gust,
  one tiny glockenspiel note a minute.

### G2. Two channels, one mixer

`SoundPlayer` grows a second looping player (`music`) alongside `ambience`.
Both duck under the chime. The ambience chip row stays the quick picker;
**long-press the row (or a new ear icon) opens the Sound Studio sheet**: two
wheels (ambience × music) + two volume sliders. Rain + Paws & Chill is the
combo half of YouTube listens to all day — now it's two taps, offline, in a
timer that pets back.

- Free: any *one* channel at a time (pick ambience *or* music).
- **Plus: layer both + the volume sliders.** This is a genuinely wanted
  feature as a paid line-item, and it degrades gracefully.
- Settings persist in `PomodoroSettings` (`music`, `mixVolumes`), lenient as
  ever; `applyEntitlement` drops the second channel if Plus lapses.

**Done when:** loops are seam-free (inspect waveform ends), both channels
survive backgrounding/foregrounding, the mix respects the ringer switch, and
the paywall copy is updated (see M).

---

## Phase H — The Cast (four new buddies, each with a quirk)

More buddies is content; buddies with *quirks* are character. Each new buddy
gets the full frame set from `build_frames` **plus one signature behavior**
nobody else has — the quirk is what people tell their friends about.

| Buddy | Name | Quirk |
|---|---|---|
| **Capybara** | Tofu | On breaks, soaks in a tiny hot-spring tub (own perch prop, steam wisps). The internet's calmest animal, in the calmest app. |
| **Red panda** | Maple | Naps hugging its tail like a pillow (distinct asleep silhouette); petting makes it raise both arms — the famous startle, played as delight. |
| **Penguin** | Pebble | Doesn't sit — waddles in place on idle (2-frame shuffle); happy = a little belly-slide arc across the perch. |
| **Owl** | Luna | **Nocturnal.** After dark (existing `DayPart`), Luna is *awake through your focus* — "Luna keeps watch" — and dozes through daytime breaks. The one buddy that inverts the core fiction, and only at night. |

- Sprite work: same 40×40 grid, palettes per species, quirk frames are 2–3
  extra poses each. Follow the head-anchor rule so Phase E accessories fit.
- `BuddyAnimator` learns two small things: a per-buddy idle override (Pebble's
  waddle) and a day-part-aware fiction flip (Luna). Both are switch arms, not
  new architecture.
- Gating: **Pebble the penguin joins the free tier** (cat, dog, penguin —
  free tier gets visibly more generous, which is the cheapest goodwill
  available). Tofu, Maple, Luna join Plus → "nine buddies in total".
- **Name your buddy** (small, beloved): a text field in Settings, default
  stays the given name; stored in settings; every caption already routes
  through `buddy.name` → route through the custom name instead.
- Backlog if appetite remains: fawn ("Fern"), axolotl ("Rosy"), black cat
  (seasonal October star).

**Done when:** all four have breathing/blink/wake/happy + quirk frames in
both appearances across all scenes; Luna's nocturnal flip verified with
`-PawmodoroClock 22`; paywall + onboarding picker updated.

---

## Phase I — Four new themes

Cheap, high-visibility, and the contrast tool makes tuning mechanical: adjust
values until `python3 tools/check_contrast.py` passes (it now also checks
scenes — run after both).

| Theme | Feel | Gate |
|---|---|---|
| **Snowdrift** | paper white / ice blue; dark = deep polar navy | Free (second free theme — generosity again) |
| **Ember** | sunset amber and coral over warm charcoal | Plus |
| **Lavender** | lilac dusk, the "aesthetic" screenshot magnet | Plus |
| **Ink** | sumi-e: warm greys, one vermilion accent — the bold one | Plus |

Eight themes × eight scenes × four day-parts is a combinatorial wardrobe —
the content *multiplies* rather than adds.

---

## Phase J — Toys, seasons, and small magic

**Scene toys** (breaks and idle only — focus stays sacred):
- **Pond ripples** — touch water in Woods/Onsen: expanding rings (Canvas).
- **Skipping stones** — swipe across water in Harbor/Woods: 1–4 skips with
  haptic ticks and rings; a toy, not a game — no score, ever.
- **Firefly** — after dark, one firefly trails your finger, then wanders off.
- **Petal gust** — swipe in Blossom Village: petals scatter and resettle.
**Buddy magic:**
- **Eye-tracking** — drag a finger near an awake buddy and its pupils follow
  (two pupil-offset frames per buddy; absurd charm for ~20 lines of Python).
- **Snow-globe shake** — shake the phone: current scene's particles swirl
  once and resettle (motion event already available via CoreMotion work).
**Seasonal dressing** (date-driven, procedural, all reuse the particle system
and small prop sprites; `-PawmodoroSeason <name>` to force):
- Sakura drift (late Mar–mid Apr), summer fireflies (Jul–Aug), maple leaves +
  pumpkins by the perch (mid–late Oct, bats at night Oct 24–31), snow +
  night-cap on the buddy (Dec), paper lanterns (Lunar New Year window).
  A pomodoro app that quietly knows it's autumn is a pomodoro app people
  screenshot.
**Alternate app icons** — one per buddy (generator emits them); picker in
Settings; free icons for free buddies, Plus buddies' icons with Plus.

---

## Phase K — Postcards (the shareable keepsake)

When you *arrive* somewhere (scene unlock) and on each completed cycle, the
buddy sends a postcard: the current scene at its current day-part, the buddy
posed on its perch, a stamp (paw print), a date line, and a handwritten-style
caption ("Made it to Harbor Isle — 4 sessions today. — Mochi"). Rendered
offline by compositing existing generated assets with SwiftUI `ImageRenderer`;
saved to an **Album** grid on the stats screen; share-sheet export.

Postcards are the growth loop: they're the first artifact of this app anyone
would voluntarily post, and every one carries the art style. Debug:
`-PawmodoroPostcard` grants one on launch.

---

## M — Monetization restatement (one Plus, fatter on both sides)

Same single non-consumable, no subscription. After this plan ships:

- **Free:** 3 buddies (cat, dog, penguin), 2 themes, 4 scenes (the whole Home
  Waters route), 3 ambiences, 1 music loop (Paws & Chill — the hook), one
  sound channel, seasonal events, postcards, naming, toys.
- **Plus:** 9 buddies total, 8 themes, the Far Isles route (4 scenes), all
  sounds, **the mixer**, accessory wardrobe (Phase E), all alternate icons.

Paywall copy rewrite: "A bigger, cozier world" becomes literal — *"Four far
isles, six more buddies, the sound studio, and every theme."* Update
[MONETIZATION.md](MONETIZATION.md) and `PaywallView` counts together.

---

## Guardrails (unchanged, now with more surface)

Anti-goals hold: no effect soup, no guilt, no coins, no battery tax, no
dependencies, no a11y regression. New surfaces inherit them: scenery is
static art (zero per-frame cost); vignettes ride the existing ticker; toys
mount their canvases only while a finger is down; seasonal layers cap at the
existing particle budgets; every new text placement is measured, not eyeballed.

## Build order for the executing session

| # | Scope | Size | Note |
|---|---|---|---|
| 1 | [REVIEW_FINDINGS.md](REVIEW_FINDINGS.md) fixes + Phase D (Live Activity) | S | needs the user's 30s Xcode target step first |
| ~~2~~ | ~~F1 pipeline + scenes + vignette~~ — **done**, all 8 places shipped | L | |
| ~~3~~ | ~~F2 scenes + journey unlocks + arrivals~~ — **done** | L | |
| 4 | H cast (four buddies + quirks + naming) | M | |
| 5 | G sound studio (five loops + mixer) | M | |
| 6 | I themes + M paywall/monetization copy | S | contrast tool makes this mechanical |
| 7 | K postcards + album | M | |
| 8 | J toys + seasons + icons | M | shippable in slices |
| 9 | E bond & accessories (from DELIGHT_PLAN) | M | benefits from the larger cast |

Every session ends the standard way: `tools/run-sim.sh --demo --headless`,
screenshots light/dark, `python3 tools/check_contrast.py`, Release build,
CLAUDE.md flag table updated, commit.
