# Pawmodoro Companion Plan — the pet that knows you

> **Status: built end to end on Linux (Aug 2026), never compiled.** All of
> V–Z and the small-magic wave are written, one commit per phase, with every
> divergence recorded in an **As built** section at the bottom of this file.
> `check_swift.py`, `check_contrast.py` and `check_stray.py` all pass; the
> wave still needs its first Mac build, the Debug *and* Release compile, and
> a walk of the flag table — same as every Linux-authored wave before it.
> This is the third plan document: [DELIGHT_PLAN.md](DELIGHT_PLAN.md) made
> the app feel alive, [CONTENT_PLAN.md](CONTENT_PLAN.md) gave it a world,
> and this one gives the buddy a *relationship*.

## The thesis: Tamagotchi, inverted

In 1996 the Tamagotchi's genius was that the pet **needed** you: feed it,
clean it, tuck it in, or it sickened and died. Thirty years of virtual pets
have copied the need and called it engagement. The need is the part this app
must never copy — Pawmodoro's one law is that the buddy is never sad *at*
you, and nothing can decay.

So invert it. The buddy never needs you. It **knows** you.

Every mechanic in this plan converts *presence into memory*, never *absence
into damage*. You don't feed the buddy to keep it alive — you feed it to find
out, over weeks, that Yuzu the fox loses her mind over cloudberries and
regards the rice cracker as a practical joke. You don't tuck it in or it
suffers — you tuck it in and *tomorrow morning* the dream diary is one entry
richer. Care is a language here, not a debt. That is the never-before-seen
part: a Tamagotchi where the pet keeps score of nothing except how well the
two of you know each other.

Today the buddy has exactly one interaction: petting. (There is no feeding in
the shipped app — the tip jar's "keeps Mochi in treats" is a caption, not a
mechanic.) This plan gives it ten more, each owning a different moment of the
user's day.

### The retention map

Every feature exists to own one slot. No two features compete for the same
one — the workshop's biggest finding was that good ideas cluster, and
clusters must be merged before they're built.

| Moment | Feature | The pull |
|---|---|---|
| First open of the day | Doorstep Hello (X1) | you never know which hello you'll get |
| Open after hours away | Carried Home (X2) | what did it find while I was gone? |
| Session completes | High Five at the Bell (W1) | the paw is only up for three seconds |
| A break | The Snack on the Sill (V) | today's snack ≠ yesterday's; the taste page is unfinished |
| Evening, idle | Tuck-In (W2) | the payoff is only visible tomorrow morning |
| Across days | Repertoire (Y) | she practices in her sleep — the spin is better *tomorrow* |
| Across months | On This Day (Z) | three weeks since the stag, and only the buddy remembered |

### Anti-goals (as binding as ever, plus new ones this plan earns)

- **No guilt mechanics.** Each phase below carries an explicit guilt-proof.
  If a future change makes any of these able to shame, the change is wrong.
- **No economy.** Nothing in this plan is counted, stockpiled, or spent. The
  snack sill holds *one* snack, not a number of them. The moment a feature
  grows an inventory, it has left the brand.
- **No new sensors.** No microphone, camera, location, or motion classifiers.
  The workshop killed three lovely ideas (a held-phone tremor detector, a
  knock-through-the-table listener, a tilt-to-tuck-in ramp) for one shared
  reason: the risky artifact is the classifier itself, which cannot be tuned
  blind on Linux or driven in the simulator pane. Touch and clock only.
- **Focus stays sacred.** Every gesture below works while idle or on a break
  and does nothing during focus. The sill, the blanket, the trick cues — all
  of it is out of reach while the buddy naps, behind the same rule that
  already deafens the scene toys.
- **No fourth shelf.** Finds, burrs, and fetch-objects all bank into **one**
  Keepsake Drawer. The app has enough collection screens; it does not need
  one per feature.

### Cost rules the whole plan obeys (the ×12 tax)

One new pose costs twelve generator drawings — one per buddy. The plan stays
affordable by spending poses only where a pose is the point, and using the
four established cost-collapsers everywhere else:

1. **Shared overlays** anchored to existing poses: the blanket over the
   asleep frame, the munch effect near the head anchor, a burr at a per-buddy
   attachment point. One sprite reaches all twelve buddies.
2. **Derived frames**: the generators already derive journal silhouettes and
   sepia sketches from frame 0 by palette transform. Bliss eyes, trick
   silhouettes and the wobble tier come out of the same trick.
3. **`BuddyFrames` nil-fallback**: a buddy without a bespoke frame falls back
   to the ordinary pose, so per-buddy character frames ship as drip content,
   never as a launch blocker.
4. **No free placement over scenery.** `check_stray.py` exists because the
   one screen-positioned sprite sat on the open sea. Everything here sits at
   a per-buddy data anchor, on the existing buddy cell, or on a UI-layer
   strip — never at an arbitrary point over eight places × four times of day.

Also, learned from the feasibility pass: **there is no walk cycle.** Nothing
below requires locomotion. Wherever a concept said "the buddy walks over",
the shipped behaviour is the Reduce Motion path promoted to default: a fade
or slide-plus-bob beside the destination. If a transit primitive ever earns
its keep, it is one shared slide+bob of the awake frame, added once.

---

## Phase V — The Snack on the Sill (feeding, done Pawmodoro-style)

**Goal:** the feeding the app never had. Finishing a focus session sets out a
snack; on a break you give it to the buddy and *watch what it does*; over
weeks you learn this particular animal's tastes. Feeding as taste discovery —
zero meters, zero shop.

### V1. The supply rule (the shape that keeps it out of the economy)

- Completing a focus session sets out **one snack on the sill** — a small
  strip at the scene edge, UI layer, themed backing like every other chip.
- The sill holds **one snack at a time**. Finish three sessions without
  feeding and the sill still holds one snack. Nothing accumulates, nothing is
  counted, no number exists anywhere. (The workshop's first draft had a
  three-snack sill; the brand judge correctly called a capped counted stack
  "the pool's one smuggled economy" and it died.)
- The snack's flavor is a pure function of `(date, place, season)` — decided
  once, like a sighting. Woods days lean acorn; Harbor days lean sardine; a
  sakura-season day can mint sakura mochi regardless of place. About ten
  kinds at launch, each a 12–16px generator sprite:
  acorn, sardine, yuzu, rice cracker, cloudberry, honeycomb, dried minnow,
  sakura mochi (spring), roasted chestnut (autumn), snow cookie (winter).
- A snack left overnight is set out for the wildlife — gone by morning, and
  once in a while the morning hello (Phase X) catches a robin taking it,
  which can tick the journal. Generosity, not waste.

### V2. The gift

- Drag the snack from the sill to the buddy (idle/break only — during focus
  the sill is out of reach, same gate as the toys). The buddy's eyes already
  track a finger; they now track the snack it's carrying, for free.
- The reaction resolves from a per-buddy **taste table** — pure data on
  `Buddy`, exactly like the quirk frames, covered by `check_swift.py`'s
  exhaustive-switch rule:
  - **Favorite** (one per buddy): the bliss reaction — a happy-frame variant
    with closed-smiling eyes (derived in the generator from the existing
    happy pose via the shared `eyes()` helper, *not* twelve new drawings),
    hearts, the deep purr, and a unique caption.
    Pip + dried minnow: he eats it floating on his back, because of course.
  - **Liked** (most pairings): a shared munch overlay near the head anchor,
    a contented nibble, standard purr.
  - **Not their thing** (one per buddy): a polite nudge-back and a dry gag —
    the joke is always at the flavor, never at the user. "Luna regards the
    yuzu as a category error." The snack stays on the sill.
- Three snacks eaten in a day and the buddy pats its belly and contentedly
  waves the rest off until dawn. Fullness is drawn as satisfaction, never as
  the user's failure to ration.

### V3. Tastes, learned

- A **Tastes** card per buddy (on the buddy card / almanac, journal-style):
  each reaction the user has actually seen fills in a line. Twelve buddies ×
  ten snacks × seasonal rotations is weeks of small experiments, each needing
  a finished session first — feeding stays tied to the app's core loop.

**Guilt-proof:** there is no hunger. An unfed buddy is identical to a
daily-fed one, forever. The sill can't back up, refusals are flavor comedy,
and the taste card only ever gains lines.

**State:** `sillSnack` (id or nil), `snackAppetite` (count + date),
`tastesSeen` (per buddy). All in `StorageKeys` + `.all`.

**New flags:** `-PawmodoroSnack <id>` (stock the sill), `-PawmodoroFillTastes`.
Valued flags read `ProcessInfo` via `LaunchOptions.value(after:)` — the
order-sensitivity lesson is already learned.

**Done when:** a fast-timer session mints a snack; each reaction tier is
forceable and screenshot-verified in light/dark; the Tastes card fills; three
snacks hit the contented cap; Release builds with all flags compiled out.

---

## Phase W — The Bookends (the day's first and last touch)

Two tiny features that own the two hottest moments the app already has:
the session-complete peak and the end of the evening.

### W1. High Five at the Bell

The completion choreography plays *at* you; this makes it a two-way moment.

- When a focus session completes naturally, the buddy wakes, stretches — and
  holds one paw up for **three seconds** (a window that is a pure function of
  the celebration timeline; no timer). Tap the paw: a slap frame, one
  synchronized hop, a slightly bigger first confetti burst, the purr haptic.
- Miss it and the paw simply comes down and the normal celebration plays.
  Nothing records the miss — **the streak that silently resets was cut** in
  review as a hidden loss mechanic. The only state is `lifetimeFives`, an
  int that only rises and is displayed nowhere (at most one dry line on the
  buddy card).
- At five lifetime fives, the payoff: the buddy starts raising its paw **a
  beat before the chime** — the animal has learned you'll be there. Earned
  once, kept forever.
- Art: one raised-paw frame per buddy (this is a pose that *is* the point —
  the ×12 is spent deliberately), slap shared as an effect burst + the
  existing happy frame.

**Guilt-proof:** the window is an offer, not a test. A missed five changes
nothing, is stored nowhere, and the pre-empt can never be lost.

**New flags:** rides `-PawmodoroCelebrate`; add `-PawmodoroFives <n>` to
preview the pre-empt.

### W2. Tuck-In

Tamagotchi's most-remembered care action — lights out — with the punishment
replaced by a *planted reveal*.

- After sunset (the sky clock the app already keeps), while idle, a small
  folded blanket sits at the scene edge. Drag it over the buddy: it burrows
  in with a sigh, and the caption timestamps the moment —
  **"Tucked in at 11:04. Mochi has no notes."**
- The blanket is a shared overlay drawn over the existing asleep pose,
  positioned by a per-buddy anchor — zero new poses. Seasonal palettes
  (star-quilt in winter, light cotton in summer) via the palette-transform
  trick.
- The payoff arrives **tomorrow**: the first launch after midnight upgrades
  the (already deterministic) dream roll to a guaranteed vivid diary entry
  that names the blanket — "Under the star-quilt, Mochi sailed the Harbor
  mist." One gesture at night, one reason to open the app in the morning,
  and the payoff lands inside a system that already shipped.
- Luna is data, not a branch: nocturnal buddies get a **daybreak** tuck-in
  window instead, and her vivid entry rolls on her next *daytime* nap — the
  owl rule (no dreams at night) holds untouched.

**Guilt-proof:** an untucked buddy sleeps perfectly, dreams normally, and no
caption ever notes which nights lacked a blanket. Miss the window and the
identical blanket is simply there tomorrow evening. No chain exists.

**State:** `tuckedOn` (date). **New flags:** `-PawmodoroTucked` (force the
morning payoff); the window itself is already reachable via
`-PawmodoroClock 22`.

**Done when:** blanket drag works at night and is absent by day; the morning
entry lands and names the blanket; Luna's daybreak variant verified with
`-PawmodoroBuddy owl -PawmodoroClock 5`; both appearances screenshot-checked.

---

## Phase X — The Doorstep (the first five seconds of every open)

**Goal:** opening the app becomes a small event. You catch the buddy
mid-life, and if you've been away, it has something for you.

### X1. Doorstep Hello

- On the **first open of each calendar day**, one short greeting vignette
  (2–4 frames, 3–6 seconds) plays before settling into idle: a huge
  yawn-stretch, a pounce after a moth (one tiny fx sprite), peeking around
  the timer face, asleep in a new spot, a whole-body shake. Rarely: it trots
  up with a leaf held out like a bouquet.
- The draw is seeded from `(date, buddyId)` — decided once at launch, then a
  pure function of elapsed time, per the house pattern. Second open of the
  day: plain idle, no lever to re-pull.
- Launch with **eight vignettes** (six common, two rare), built almost
  entirely from existing frames + captions; any vignette needing a new pose
  is cut to caption + existing frames until proven. Rare hellos land as a
  line on the buddy card. Captions never tease the rare tier — a hello is a
  hello, not a slot-machine near-miss. The variable-reward psychology is in
  there, but wearing the app's clothes.

### X2. Carried Home (finds and burrs, one drawer)

- **Finds:** if six or more real hours have passed since the last open, the
  hello *is* an arrival: the buddy appears with something at its feet. The
  find table is keyed by **(yesterday's last place, season)** — sea glass
  after a Harbor day, a gold maple leaf in autumn — so the gift is a receipt
  from your own logged history, with a provenance line to match: "Sea glass.
  Harbor Isle, the day after the kingfisher." Hard cap: **one find per day,
  regardless of absence length** — a weekend away and six months away yield
  the same single warm gift. (The workshop's "yesterday's focus minutes buy
  rarer finds" rule was vetoed on brand: this house does not price affection
  by output.)
- **Burrs:** some mornings the buddy turns up with yesterday still attached —
  a burr after the meadow, one sakura petal glued to an ear, salt after
  Harbor, snow on the nose. A 4–8px overlay at the per-buddy anchor. Tap it:
  it pops off with a shake (three shared frames via the fallback rule) and a
  pleased wiggle. Ignore it: the buddy shakes it off itself after ~90
  seconds and it banks anyway. The anti-dirty-state — the "mess" is a single
  droll souvenir of where you actually were yesterday, and it curates itself.
- Both bank into the **Keepsake Drawer** — one journal-pattern grid, each
  item with date, finder, and place. This drawer is the *only* collection
  surface this plan adds; later backlog features (the fetch stick) feed it
  rather than growing their own.

**Guilt-proof:** every hello in the table is warm or funny — there is no "I
missed you" draw, and a month-long gap gets the same joyful distribution as a
daily streak. Finds make absence *generative* instead of punishable. No
backlog, no droop, no mention of the gap, ever.

**State:** `lastOpenDate` , drawer contents, `lastFindDate`, `lastBurrDate`,
rare-hellos-seen. **New flags:** `-PawmodoroHello <id>`,
`-PawmodoroFind <id>`, `-PawmodoroBurr <id>`, `-PawmodoroFillDrawer`.

**Done when:** every vignette, find, and burr is forceable and shot in both
appearances; the 6-hour and one-per-day gates verified by editing
`lastOpenDate` via flag; drawer renders with provenance lines; Reduce Motion
paths (final-pose crossfade + caption) verified.

---

## Phase Y — Repertoire (the flagship: tricks learned in its sleep)

**Goal:** the deepest never-before-seen system. You choreograph a trick by
*drawing its motion*; the buddy is charmingly bad at it today — and it
practices in its sleep. The improvement only ever arrives with tomorrow.

### Y1. The cue

- On a break or while idle, trace a shape on the scene: a **circle** cues a
  spin, an **arc** cues a leap. Two tricks at launch; the vocabulary
  (zigzag → dash-dash, figure-eight → weave) grows later — sprites, not
  recognition, are the bottleneck.
- The recognizer is ~100 lines of dependency-free geometry ($1-recognizer
  style: resample the stroke, template match). Pure Swift, deterministic,
  fully reasoned about on Linux; `-PawmodoroTrick <id> <tier>` pins any
  state for the Mac pane in minutes.

### Y2. The mastery ratchet

- Per `(buddy, trick)`: tiers 0–3 — *charming failure* → *wobbly* → *almost*
  → *mastered, with flourish*. The attempt renders at the current tier.
- **Practicing today never levels the trick today.** The tier rises on the
  first launch of a new day after a practiced day, and the caption sells the
  fiction: "She was practicing in her sleep — ask for the spin again."
  Overnight consolidation is real animal biology, it makes the app
  structurally un-bingeable, and it turns the day-gate into the pet's doing
  rather than a cap.
- Mastery never decays. A trick half-learned in March is exactly as
  half-learned in June, waiting patiently.
- **Bond levels unlock trick slots** — the five-level bond ladder finally
  pays out something concrete at each step.

### Y3. Woven back in

Mastered tricks stop being a feature and become texture:
- The session-complete celebration sometimes features one (chosen by date
  hash — deterministic).
- A mastered trick can surface as a dream-diary line ("dreamed of the spin,
  nailed on the first try").
- When buddy visits ship (backlog: The Knock), a buddy shows a visitor its
  best trick.

### Y4. The art strategy (what makes it affordable)

Trick frames are **silhouette-shared**: the generator derives each trick's
frames from a buddy's frame 0 by the same transform pipeline that already
makes journal silhouettes and sepia sketches — every buddy performs the
trick in its own outline from day one. The wobble tier is a dither/offset
variant emitted by the generator, never runtime rotation (which would break
the pixel grid). Bespoke per-buddy style frames — the penguin's spin as a
belly-slide twirl — ship later as drip content through the `BuddyFrames`
fallback, exactly like quirk poses do today.

**Guilt-proof:** proficiency only rises, nothing rusts, failure animations
exist only at low tiers where they are the endearing point, and a paused
month pauses learning exactly where it stood.

**State:** per-(buddy, trick) tier + last-practiced date.
**New flags:** `-PawmodoroTrick <id> <tier>`.

**Done when:** both launch tricks recognized reliably in the pane; all four
tiers forceable and shot; the overnight step verified by flag-simulated day
rollover; a mastered trick appears in a celebration; Release builds clean.

---

## Phase Z — On This Day (the buddy keeps your history)

**Goal:** the app already writes a diary it never reads — journal sightings,
postcards, star nights, Soot's arrival, first visits. This phase gives the
buddy the memory. The single strongest possible answer to "this animal knows
me", built almost entirely from data the app already persists.

- At the first idle open of a day, an **anniversary engine** — a pure
  function over stored dates — scans for hits: exactly N weeks or months
  since the first session ever, each buddy's first day, the first sighting
  of each species, Soot's joining, each place reached, a notable star night.
  It ranks by rarity, surfaces **at most one**, decided once for the day.
- It renders as the buddy beside a small thought-bubble: the bubble's
  thumbnail is the journal's existing sepia sketch or silhouette (the
  derived-art pipeline, at thumbnail size — near-zero new art). Tap it to
  open the referenced journal page, postcard, or constellation.
- The caption does the remembering, in the house voice:
  *"Three weeks ago today: the stag, at Harbor. Mochi maintains it was
  taller than reported."*
- Surfaced memories are recorded so nothing repeats within its tier. The
  deeper a user's history, the more often the animal proves it was paying
  attention — this is the phase that makes veterans the richest users.

**Guilt-proof — the structural kind:** the engine's input is a list of
things you *did*. It has no representation of missed days and cannot mention
what it cannot see. A sparse history means fewer memories, never a remark
about their absence.

**State:** surfaced-memory ids. **New flags:** `-PawmodoroRemember <daysAgo>`
(back-dates one journal entry so a hit lands today); `-PawmodoroSeedStats`
already provides the history.

**Done when:** each memory source (species, place, star, Soot, buddy-day)
forceable; bubble thumbnail + caption capsule pass contrast in all themes;
tap-through lands on the right page; nothing repeats across relaunches.

---

## The small-magic wave (anytime, between phases)

Three tiny features, each near-zero cost, each buildable in an afternoon
when a phase needs a palate cleanser:

- **Last-Second Pounce.** In the final ten seconds of a *break*, the
  countdown digits become prey: crouch at T-10, haunch-wiggle at T-3, pounce
  at zero, batting the digit off the screen. Pure `f(engine.progress)` on the
  `rollSighting` pattern; a `pounceFrame` data slot with a shared crouch
  fallback; a 1-in-7 rolled variant lets the digit escape ("Mochi is still
  thinking about that one"). One hard rule from review: the pounce resolves
  **before** the focus face mounts — it never delays the timer by a frame.
  No timer app has ever made the countdown itself the pet's toy.
- **The Slow Blink.** Press-and-hold on the buddy (≥0.8s, distinct from the
  petting stroke): it meets your eye and returns a long, deliberate slow
  blink — the existing blink frames, retimed at 2fps, so the art is already
  in the catalog. Hold past 3s and it settles where it stands. Past bond
  level 3, the flip: on the first open of a day, once, the buddy slow-blinks
  at *you*, unprompted. "Mochi blinked first. Make of that what you will."
- **Summit Nap.** Open the stats screen and the buddy is already there —
  asleep on the tallest bar of the weekly chart, paw dangling over
  Wednesday. A flat week means napping in a sunbeam at ground level, exactly
  as contentedly. A personal-best week plants a tiny flag that stays in that
  week's chart forever. Existing sleep + shuffle frames, one 8px flag
  sprite, static layout math.

---

## Backlog (strong second wave, with review fixes recorded)

Held, not killed. Each carries the fix it must ship with:

- **The Knock.** On a rolled break, one of your *other* buddies visits; the
  two idle side by side in their quirk poses; a guest book logs first
  meetings. Fix applied: this replaces the workshop's "Playdates" concept
  outright — no summoning UI, no 78 grindable friendship pairs. Needs 2+
  owned buddies, so it waits until the core wave proves out.
- **The Usual.** Five same-hour sessions in fourteen days and one day the
  buddy has it set up already — pre-dialed timer, kettle track cued, one
  caption: "The usual?" Derived from the session log on a rolling window;
  nothing stored, nothing breakable. Reuses the expedition card UI. Decline
  and it shrugs — nothing is recorded.
- **Field Notes on a Human.** The buddy keeps a diary about *you*, one dry
  line per shared day: "Day 41. The human skipped a stone four times today.
  I pretended not to be impressed." Pages are numbered "Day N of knowing
  you" — shared days are the only calendar, so absence is structurally
  unrecordable. Ships after Z (it is On This Day at daily granularity, and
  the cost is authorial: a few hundred lines that must all land in the house
  voice).
- **The Secret Handshake.** Press-and-hold two fingers: the buddy purrs a
  short signature rhythm into your palm through `HapticsDirector`; answer it
  with taps. Fix applied: capped at ~7 beats forever (flourishes vary
  instead of lengthening — the app never sets an exam). Gated on a device
  session: whether a haptic rhythm *feels* learnable cannot be tuned in the
  simulator.
- **Breath on the Glass.** Hold a finger low on the scene and the buddy
  noses the inside of the glass under it; a fog patch blooms; days later a
  paw-print reply appears in the morning fog. Fix applied: the buddy fogs
  the glass itself once, unprompted, to teach the mechanic — undiscovered
  hooks retain no one.
- **Hearthside.** Plugged in and charging while open after sunset: a small
  ember-glow hearth, the buddy curled beside it. Fix applied: the caption
  only claims what the app witnessed ("was toasting her paws when you left"),
  since iOS can't observe an overnight charge.
- **Warm Spot / Doorstep Cairn.** Both re-scoped in review (quantized
  pre-verified anchors per place; cairn stones mean shared idle presence,
  never hesitation). Both parked until a `check_stray`-style anchor harness
  exists for props.

## Rejected on principle (recorded so nobody rebuilds them)

- **Anything that decays** — including the workshop's fluffed-coat-that-
  expires-at-midnight. Decay wearing a party dress is still decay; "nothing
  decays" has no bonus-shaped exception.
- **Counted inventories** — the three-snack sill died for this. If a feature
  needs a number of things, it is a shop waiting to happen.
- **Output-priced affection** — focus minutes must never buy rarer gifts.
  Sessions flavor the world; they do not grade the user.
- **Hidden loss ledgers** — the consecutive high-five streak that silently
  reset. The brand keeps no secret record of misses.
- **Raw sensor classifiers** — tremor detection, knock detection, tilt
  ramps. Unverifiable without a device in hand, against the Linux-first
  discipline, and permission creep besides.
- **Friendship levels between buddies** — 78 grindable pairs is a systems
  game this app doesn't play. Visits stay vignettes.

---

## Cross-cutting engineering notes

**State.** Every new key goes in `StorageKeys` and `StorageKeys.all` so
`-PawmodoroResetState` keeps working. Everything derived that *can* be
derived (the anniversary engine, The Usual) is derived, not stored — the
Stray set the pattern: derived state cannot corrupt, regress, or be lost.

**Determinism.** Every roll is decided once — at session completion, at
first-open, at launch — then everything on screen is a pure function of
progress or elapsed time. No new Timers anywhere. This is what makes every
feature forceable by flag and verifiable days later on the Mac.

**Flags.** All new flags follow `LaunchOptions` conventions: valued flags
read `ProcessInfo` via `value(after:)` (the ordering lesson), every flag has
its Release stand-in (`check_swift.py` enforces the `#if DEBUG` parity), and
each lands in CLAUDE.md's table as it ships.

**Checks, every session:** `python3 tools/check_swift.py`,
`check_contrast.py` (the sill strip, the drawer, the thought-bubble backing
are new text-over-scenery surfaces — each needs the standard capsule),
`check_stray.py` if anything moves near the scene floor. Generators run
bare or with `2>&1` — never with stderr piped away.

**Reduce Motion** is the default arrival path (fade/crossfade + caption)
for everything in this plan, then motion is layered on where it's cheap —
not the other way round. That choice is what made half these features
affordable at all.

**Accessibility.** Every gesture gets a labelled custom action (the sill:
"Give Mochi the acorn"; the paw: "High five Mochi"; the blanket: "Tuck
Mochi in"), same pattern as petting today.

## Suggested build order

| Session | Scope | Riskiest bit |
|---|---|---|
| 1 | V (sill, tastes, reactions) | drag-and-drop over the existing gesture stack |
| 2 | W1 + W2 (high five, tuck-in) | celebration timeline insertion without delaying the chime |
| 3 | X1 (hellos) | vignettes staying inside existing frames |
| 4 | X2 (finds, burrs, drawer) | one drawer serving two features cleanly |
| 5 | Y1–Y2 (recognizer, ratchet) | recognizer thresholds tuned blind |
| 6 | Y3–Y4 (weaving, silhouette frames) | derived trick art reading clearly at 40px |
| 7 | Z (anniversary engine) | ranking so the *right* memory surfaces |
| 8 | Small magic + polish pass | the pounce never touching the focus face |

Each session ends the standard way: checkers green, `--demo` walk of the
changed screen, light + dark screenshots, CLAUDE.md flag table updated,
commit.

---

## As built (one Linux session, Aug 2026 — not yet compiled)

Where the code diverged from the plan above, and why. Everything else
shipped as written.

**Art, generally.** All new art lives in `tools/generate_companion_props.py`,
which imports the sprite helpers but never re-emits shipped imagesets — the
container's Pillow is newer than the one that authored the catalog, and
re-running the old `__main__` would have moved pixels this wave never
touched. 38 new imagesets; a contact sheet was eyeballed and one sprite (the
feather, which read as a pane of glass) redrawn.

**V — the sill.** As planned, with one shape change the brand judge forced
early: the sill holds **one** snack, not a capped stack — `setOut` is a
no-op while a snack is waiting. The eating animation is the snack chip
flying and shrinking plus the existing happy burst; the planned shared
munch overlay was cut as unnecessary once the flight read as eating. A snub
leaves the snack on the sill and still fills the Tastes card — a refusal is
knowledge too.

**W1 — the five.** The raised paw is a `pawUpFrame` frame slot with bespoke
art for cat, dog and Soot only; everyone else holds `happy_1` (up on the
toes) until drawn — the `BuddyFrames` drip-content rule, applied on day
one. The "slightly bigger confetti burst" was cut: the slap, hop and hearts
carry the moment, and the celebration overlay stays untouched. The pre-empt
gates on lifetime fives, never consecutive — the reviewed-out hidden-streak
reset never existed in code.

**W2 — tuck-in.** The blanket is one shared overlay drawn over any asleep
pose (all twelve fill the lower half of the same grid) — zero per-buddy
frames. The morning payoff is a guaranteed dream roll for the whole blessed
day plus the morning caption; the diary entry itself is not annotated with
the blanket (that needed a diary schema change for one adjective). A tuck
after midnight blesses the *following* day — noted as a quirk, accepted.

**X — the doorstep.** Burrs pop with a shake and a caption but bank
nothing: salt in a drawer is an absurdity the one-collection rule didn't
need. Rare hellos are recorded in state but have no page yet — the drawer
card was enough collection UI for one wave. The find takes the greeting
slot (`Hello.carriedHome`) rather than stacking a hello *and* a gift.
An untapped find is replaced by the next day's decisions: unwitnessed, it
simply never happened, like a visit.

**Y — repertoire.** The plan's generator-derived silhouette trick frames
became **runtime transforms over existing frames**: the spin is a mirror
scale through zero width (reads as a paper-doll turn; rotation would break
the pixel grid), the leap is offset arcs. Zero new art, all twelve buddies
perform from day one, bespoke style frames remain the drip-content path.
Tricks surface in the celebration; the dream-diary and buddy-visit weaves
wait for their host features. `-PawmodoroTrick` takes `spin.2` (dotted, one
token) because valued flags read one token by design.

**Z — on this day.** Sources: journal first-sightings, the stray's two
dates, and the first session ever. Postcards and constellation completions
were left out — postcards duplicate journal/arrival dates, and figure
completion dates aren't stored (derived star counts have no calendar). The
bubble is not tap-through to the referenced page; a tap acknowledges with a
heart. Both cuts are v2 candidates.

**Small magic.** Summit Nap is the static nap plus the best-week flag,
derived entirely from the log — the tap-to-shuffle and the flat-week
sunbeam were cut. The slow blink's initiation fires after the day's first
hello (bond ≥ close), which also means Reduce Motion skips it along with
the vignettes — worth revisiting so the caption at least lands. The
pounce's escaped-digit caption plays immediately rather than on the next
focus phase.

**Unwalked, stated plainly.** Nothing in this wave has been compiled or
seen running. Beyond the usual first-build errors, the rows that most want
real eyes: the blanket overlay's fit across all twelve asleep silhouettes,
the burr anchors (same class of bug as the stray's hot-spring seat), the
sill drag threshold under pane latency, the stroke recognizer's thresholds
against real fingers, and every caption's fit in the capsule on an SE-width
screen.
