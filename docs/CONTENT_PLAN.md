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

## Phase G — The Sound Studio → grown into the Sound Almanac

> **Superseded and expanded:** the five-loop version below grew into a
> fifty-track procedural music system — ten mixtapes, journey-earned
> collections, a gapless AVAudioEngine player, radio mode. The build spec is
> [SOUND_ALMANAC.md](SOUND_ALMANAC.md); the mixer idea below survives inside
> it. Build from the almanac, not from this section.

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

## Phase H — The Cast (four new buddies, each with a quirk) ✅ built

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
- **Home turf** (pairs the cast with the journey): each buddy has a favourite
  place, and being there swaps its perch pose for a signature one — Tofu's
  onsen tub is already planned; Pebble belly-slides at Starfall Peaks; Luna
  keeps watch from a Woods branch; Maple curls on Blossom's veranda. One
  extra frame each, plus a caption line ("Tofu is exactly where he wants to
  be"). Cosmetic only — no bonuses, per the no-guilt rule.
- **Second wave** (after the journal ships, since both trade on the same
  charm): otter "Pip" — floats on his back during Harbor breaks, holding a
  pebble like a treasure; hedgehog "Bramble" — its asleep pose is a perfect
  ball, the best silhouette in the app. Backlog beyond that: fawn ("Fern"),
  axolotl ("Rosy"), black cat (seasonal October star).

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
caption ("Made it to Harbor Isle — 4 sessions today. — Mochi"). If a journal
sighting happened that day, the postcard mentions it ("We saw a whale!") —
the two keepsake systems feed each other. Rendered
offline by compositing existing generated assets with SwiftUI `ImageRenderer`;
saved to an **Album** grid on the stats screen; share-sheet export.

Postcards are the growth loop: they're the first artifact of this app anyone
would voluntarily post, and every one carries the art style. Debug:
`-PawmodoroPostcard` grants one on launch.

---

## Phase L — The Field Journal (stillness attracts wildlife) — wave 1 ✅ built

The app's core fiction is *be still, be quiet, don't wake the buddy*. Extend
that outward and it becomes a thesis no other pomodoro app can copy:

> **While you hold still, the world comes out.** Shy animals appear in the
> scenery mid-session — a stag stepping between the pines at dawn, an otter
> rolling in the harbor, a whale that only surfaces for the long hauls. Leave
> the session and they slip away, unrecorded. Finish it and the sighting is
> pressed into a field journal.

Forest grows a tree for focusing. Pawmodoro *shows you something* for
focusing — and what appears depends on where you are, what time it is, how
long you committed, and even the phase of the real moon. The existing content
matrix (8 places × 4 day-parts) suddenly has gameplay stretched across it:
the journal's hint lines ("Seen at dawn, in the Woods…") are literal reasons
to come back and focus at a different hour, in a different place.

### L1. The sightings engine ✅ built

- At `start()` of a focus phase, roll once against the pool of species
  eligible for (place, day-part, session length, moon). On a hit, schedule
  the appearance at 40–70% of `engine.progress` — it rides the existing
  ticker like the vignette does; no new timeline.
- The animal enters, lingers (loop of 2 frames), and leaves *before* the
  chime. Completing the session naturally logs the sighting; abandoning means
  it simply leaves — nothing lost, nothing said. No-guilt holds.
- First session in a newly reached place guarantees a common sighting, so the
  system teaches itself. Commons land ~1 in 3, uncommons ~1 in 8, rares ~1 in
  12 eligible sessions; mythics are condition-gated, not luck-gated.
- Sighted species persist under a new `pawmodoro.journal` key (registered in
  `StorageKeys.all`): species id, place, day-part, first-seen date, count.
- Reduce Motion: animals fade in/out in place instead of walking on.
- Debug: `-PawmodoroSighting <id>` forces one this session,
  `-PawmodoroFillJournal` completes the journal, `-PawmodoroMoon full` pins
  the moon.

### L2. The roster (wave 1 — Home Waters, free) ✅ built

All drawn by the generator on small grids in scene coordinates, 1–2 frames
each — wildlife is an order of magnitude cheaper than a buddy (no frame set,
no quirks), which is exactly why the menagerie can be *large*.

| Species | Where | When | Behaviour | Rarity |
|---|---|---|---|---|
| Butterfly | Meadow, Blossom | day | flutters; may land on the napping buddy's nose | common |
| Robin | Meadow | dawn | hops the fence line, pecks | common |
| Red squirrel | Woods | day | spirals up a pine trunk | common |
| Frog | Woods stream | dusk | hop + ripple ring | common |
| Stag | Woods | dawn | steps from the treeline, grazes, lifts its head | uncommon |
| Gull dive | Harbor | day | one gull breaks from the chevrons and dives | common |
| Otter | Harbor | day | floats on its back, cracks a shell | uncommon |
| Dolphin pair | Harbor | day | two arcs between the islets | uncommon |
| **Whale** | Harbor | sessions ≥ 40 min | spout, then a slow fluke — the long-haul reward | rare |
| Lantern moth | Blossom | night | orbits a lit lantern | common |
| Koi | Blossom pool | day | surface ring, orange flash | uncommon |
| Crane | Blossom | dawn | stands one-legged in the waterfall pool | uncommon |

### L3. Wave 2 — Far Isles (reached via Plus places) + phenomena

| Species | Where | When | Behaviour | Rarity |
|---|---|---|---|---|
| Dove lift-off | Keep | dawn | the flock rises past the towers | common |
| Peacock | Keep | day | the tail fan — the showpiece frame | uncommon |
| Kestrel | Cloudspire | day | hovers dead-still in the wind, then stoops | uncommon |
| **Stray sheep** | Cloudspire | day | grazing on the floating island; no explanation given | rare |
| Mountain hare | Peaks | dusk | white-on-white bound across the snowfield | uncommon |
| Ibex | Peaks | dawn | silhouette on the far ridge | rare |
| Tanuki | Onsen | night | waddles to the spring's edge, warms its paws | uncommon |
| **Moon rabbit** | any water/lantern place | full-moon night | sits in the reflection; gone by morning | mythic |

The moon is computed offline from the synodic period — no network, a dozen
lines. A pomodoro app that quietly knows the real moon is full is the kind of
thing screenshots are made of.

The journal's last page is **phenomena**, same rules: meteor shower (Peaks at
night — already drawn), a rainbow (finish a daytime session that ran rain
ambience ≥ half its length), aurora (Peaks, night, rare). Deterministic
conditions, so they feel *earned*, not rolled.

### L4. Journal UI ✅ built

A grid on the stats screen, one page per place. Unseen species render as dark
silhouettes (the generator emits these for free — same grid, outline-only
palette) with a hint line: *"Seen at dawn, in the Woods."* Seen species render
as **sepia field-sketches** (same grid again, sketch palette), with first-seen
date and count. The silhouette-plus-hint is the retention hook and honours
the house rule: locked things are shown, never hidden.

### L5. Micro-encounters (no journal, pure charm)

Three tiny moments that need no collection system: the butterfly that lands
on the sleeping buddy's nose (~60% through a Meadow/Blossom day session, and
leaves at the chime); a robin that perches on the top of the timer ring for a
few seconds; a snowflake that settles on the buddy's nose during Snowdrift
season. Rare enough to be told about, cheap enough to ship in an afternoon.

---

## Phase N — The Travelogue (the map that shows the why)

The stats screen gains a header strip: the eight places as tiny thumbnails
joined by a dotted route, the boat marker sitting between your last unlock
and the next, captioned "12 sessions to Blossom Village". The scene picker
already renders places small, so this is composition, not new art. It turns
`totalSessions` from a number into a *position* — and positions ask to be
advanced.

---

## Phase O — The Almanac page (absorbs N)

The wildlife system, the moon, the seasons and the journey each produce
"conditions" — and conditions want a forecast. The stats screen gains an
**Almanac** header, the daily-open surface this app has been missing (and a
retention driver that needs zero notifications):

- **Today**: date, season, and the real moon phase (computed offline; the
  same dozen lines wave 2's moon rabbit needs — build it here first).
- **About now**: which species are possible *right now* in the current place
  at the current day-part, shown as sketch (seen) or silhouette+hint (not) —
  a live answer to "is it worth focusing here at this hour?" It reads
  straight from `Species.isEligible`; no new state.
- **Elsewhere today**: one line per other reached place with possible
  species counts — "Whispering Woods: 2 about at dawn."
- **The travelogue strip** (Phase N folds in here): the eight places joined
  by a dotted route, boat marker between last unlock and next, "12 sessions
  to Blossom Village."
- Wave 2 hook: when the moon is full, a teaser line — "a good night for the
  water's edge."

## Phase P — Gentle streaks (the boat stays anchored)

Streak apps run on guilt; this one won't. **One missed day per calendar week
does not break the streak** — the stats screen says "the boat stayed anchored
on Tuesday" and the count keeps breathing. Implementation is a pure change to
`SessionLog.currentStreak` (derived from records; nothing new persisted), a
copy pass on the stats cards, and an almanac line. Debug:
`-PawmodoroSeedGap` seeds a history with a one-day hole to eyeball both
states. The best-streak stat keeps its strict definition so the number still
means something.

## Phase Q — The settle-in (three breaths before the boat leaves)

An optional start ritual, off by default: pressing play first plays **three
slow breaths** (~12s) — the ring swells with the existing breath animation,
the buddy circles and settles into its nap, then the countdown begins.
Entirely a UI-layer overlay: the engine's `start()` is simply deferred, so
the absolute-end-date timer logic is untouched. Tap anywhere to skip.
`settleInBeforeFocus` in settings, lenient decoding. Reduce Motion: a plain
3-2-1 fade. This is the cheapest "this app feels different" moment in the
whole plan — competitors start with a click; Pawmodoro takes a breath.

## Phase R — Expeditions & the Action Button

- **Expedition presets**: three named recipes on the dial — Classic 25/5,
  Deep Dive 50/10, Sprint 15/3 — as chips under the ring while idle. One tap
  re-lengths all three phases; the dial still fine-tunes. Buddy caption
  acknowledges: "a long crossing, then."
- **App Intents**: a `StartFocusIntent` ("Start a focus session in
  Pawmodoro") exposes the timer to Siri, Shortcuts, the Lock Screen — and
  the **Action Button** on Pro iPhones. "Press the side button and the boat
  sails" is an App Store screenshot caption, and it's ~40 lines.
- Both are small; ship them together.

## M — Monetization restatement (one Plus, fatter on both sides)

Same single non-consumable, no subscription. After this plan ships:

- **Free:** 3 buddies (cat, dog, penguin), 2 themes, 4 scenes (the whole Home
  Waters route), 3 ambiences, **25 of the 50 music tracks** (5 on day one +
  a five-track mixtape with every Home Waters arrival), one sound channel,
  seasonal events, postcards, naming, toys, gentle streaks, the settle-in,
  the almanac, **and the whole field journal** — Far Isles species come with
  the Far Isles places, so the journal deepens the existing Plus gate
  without adding a new one.
- **Plus additions from the Sound Almanac:** all 50 tracks instantly, the
  two-channel mixer, and radio mode (the auto-DJ that scores your day).
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
| ~~1a~~ | ~~[REVIEW_FINDINGS.md](REVIEW_FINDINGS.md) fixes~~ — **done** (`345c995`) | S | |
| 1b | Phase D (Live Activity) | S | needs the user's 30s Xcode target step first |
| ~~2~~ | ~~F1 pipeline + scenes + vignette~~ — **done**, all 8 places shipped | L | |
| ~~3~~ | ~~F2 scenes + journey unlocks + arrivals~~ — **done** | L | |
| ~~4~~ | ~~H cast (four buddies + quirks + naming + home turf)~~ — **done**, nine buddies ship | M | second wave (Pip, Bramble) still at #11 |
| ~~5~~ | ~~**L journal, wave 1**~~ — **done**: engine, 12 species, journal UI | L | micro-encounters (L5) not yet built |
| 6 | **G+ Sound Almanac, slices 1–3** ([SOUND_ALMANAC.md](SOUND_ALMANAC.md)): engine + gapless player + Studio + 50 tracks + radio | L | the headline; three commits |
| 7 | I themes + M paywall/monetization copy | S | contrast tool makes this mechanical |
| 8 | K postcards + album | M | picks up sighting mentions from L |
| 9 | **L wave 2** (Far Isles roster + moon + phenomena) | M | moon maths arrives with O if built first |
| 10 | **O almanac page** (absorbs N travelogue map) | M | the daily-open surface |
| 11 | J toys + seasons + icons | M | shippable in slices; migrations join the seasonal layer here |
| 12 | **P gentle streaks + Q settle-in + R expeditions/Action Button** | S | three small wins, one session |
| 13 | E bond & accessories (from DELIGHT_PLAN) + H second-wave buddies (Pip, Bramble) | M | benefits from the larger cast |

Every session ends the standard way: `tools/run-sim.sh --demo --headless`,
screenshots light/dark, `python3 tools/check_contrast.py`, Release build,
CLAUDE.md flag table updated, commit.
