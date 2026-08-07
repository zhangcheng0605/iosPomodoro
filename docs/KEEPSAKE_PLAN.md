# Pawmodoro Keepsake Plan — the app gives things back

> **Status: planned, not yet built.** Drafted August 2026, after the
> Companion and Clockwork waves (both written, both awaiting their first
> Mac build). Fifth plan document. The first four built inward — feel,
> world, relationship, time. This one builds **outward**: the records,
> poems, cards and home-screen presence the app hands back after two
> waves of quietly keeping notes. Its references are the most-copied
> famous features in modern apps, each with its dark half amputated as
> usual.

## The thesis: the artifact is the feature

The analysis is unambiguous: the era's most-copied app features — Spotify
Wrapped, BeReal's daily moment, Duolingo's home-screen widget, Wordle's
share grid — all do one thing: they **produce an artifact worth keeping**.
Not a metric. A thing. Pawmodoro now tracks a small civilization of state
(tastes, tricks, letters, stars, fortunes, photographs) and gives almost
none of it back as objects. This wave mints them:

| Famous feature | What it becomes here |
|---|---|
| Spotify Wrapped / Stardew's Grandpa | The Season's Letter + A Year, Kept (AJ) |
| Wordle's share grid | Kept cards, shared as images (AK) |
| Duolingo's widget / Widgetable | The buddy on the home screen (AL) |
| Ghost of Tsushima's haiku | The Haiku Bench (AM) |
| Usagi Shima's BunBook / Webkinz papers | The Buddy Book (AN) |
| PowerWash Simulator's one clean stroke | Frost Mornings (AO) |
| BeReal's daily moment | The Golden Hour Call (AP) |

Anti-goals: everything standing, plus this wave's own — **no score in any
artifact** (a letter recounts, never rates), **no social features** (the
share sheet is the user's; the app never posts, never phones home), and
**every giveback is derived** from state that already exists, in the
Stray's tradition.

---

## Phase AJ — The Season's Letter, and A Year, Kept (the flagship)

Stardew's Grandpa evaluation is remembered with love only because of the
love — the candles were judgment, and they die here. Spotify Wrapped is
the same loop annualized: a guaranteed rich parcel at a known cadence.

- **The Season's Letter.** On the first open after a real season turns
  (five a year, the existing calendar), a letter waits on the doorstep in
  the house voice — no totals compared to anything, just a recounting
  assembled from what actually happened: *"This spring: forty-one quiet
  hours. Luna learned the spin, mostly. The pale fox crossed once — you
  were there. Three letters came home; the callflower bloomed twice."* A
  near-empty season gets a shorter, warmer letter ("A quiet summer. The
  garden waited with you."). Letters archive beside the mailbox.
  Sources: the widened log, journal, repertoire, drawer, mailbox, garden,
  photos, setlist, timetable — a pure summarization pass; the cost is
  sentences, not systems.
- **A Year, Kept.** On the anniversary of the first session ever (the
  stored anchor from AA), a fuller thing: a sequence of five or six
  full-screen cards — hours together, the rarest thing seen, the sky you
  built (star count, any comet nights), what the buddies learned, the
  strangest keepsake's provenance — each in the postcard's visual
  language, each exportable through AK. Once a year, and only ever
  additive: year two's cards can say "more than last year" but never
  less-shaped sentences.
- **Guilt-proof:** the letter's grammar has no comparative against the
  user — only against nothing. The engine cannot see missed days (the
  anniversary engine's rule, inherited). No candles, no grade, no "you
  could have".

**New flags:** `-PawmodoroSeasonLetter <season>` (compose now),
`-PawmodoroYearCard` (the annual sequence, from seeded stats).

---

## Phase AK — Kept cards, shared (Wordle's real invention)

Wordle's grid did more for Wordle than Wordle did. The share-sheet image
is the era's cheapest, most honest growth surface — and the app already
mints beautiful moments with nowhere to go.

- An `ImageRenderer` pass turns any of these into a clean 1080-wide PNG
  in the app's own visual language: a developed photograph, a postcard,
  a haiku (AM), a season letter, each Year card.
- One small share icon on each, `ShareLink`, system sheet, done. The app
  never posts, never networks; the sheet is the user's own.
- Every card carries one quiet line of provenance ("Pawmodoro — dusk at
  the Harbor, Aug 2026") — the Wrapped signature, minus any URL bait.
- **Guilt-proof / brand-proof:** nothing is framed as an achievement;
  cards are captioned exactly as their in-app originals are. No streaks,
  no counts on any exported card.

**New flags:** none — rides the existing card flags.

---

## Phase AL — The buddy on the home screen (Duolingo's lever, Widgetable's proof)

The widget is Duolingo's single most effective retention surface, and
Widgetable built an entire hit app from one insight: **a pet that lives
on the home screen is checked on all day.** Pawmodoro's version, honest
to its fiction:

- **Small widget, v1 — zero plumbing.** The buddy at this hour: asleep at
  night, up at dawn, watching (Luna) after dark — a pure function of the
  wall clock and the season, exactly like the skies. No App Group, no
  shared state, no refresh problem: a `TimelineProvider` over day-part
  boundaries and the bundled sprites the Live Activity assets already
  ship. Seasonal dressing included (a night-cap in December).
- **v2, behind the App Group** (a separate, deliberate commit per Phase
  D's note): today's paws and the sill state join the picture.
- **The target situation, honestly:** this code lives in
  `PawmodoroWidgets/` beside `PawmodoroLiveActivity.swift` and rides the
  SAME one-time Widget Extension target step Phase D has been waiting
  on. One 30-second Xcode step now unlocks both the Live Activity and
  the home-screen buddy. It is written Linux-blind like everything else
  and compiles as part of the extension when the target exists.
- **Guilt-proof:** the widget never shows a number that can disappoint —
  v1 shows no numbers at all. Duolingo's melting-icon guilt trick is the
  amputated half.

**New flags:** none (widgets take no launch arguments; preview via the
widget gallery).

---

## Phase AM — The Haiku Bench (Ghost of Tsushima)

The most-loved five minutes in a fifty-hour samurai epic was sitting
still and picking three lines. That is nearly a Pomodoro already.

- While idle, a small bench chip near the toys (off-hours only): open it
  and compose a haiku by choosing one of three lines, three times. Line
  pools are seeded by (place, season, day-part) — the Harbor at dusk
  offers different first lines than the Peaks at dawn — so places read
  differently on the page, which is the Tsushima trick.
- The buddy sits beside the bench while you choose (watch frame),
  considers the finished poem (slow blink), and the poem files into a
  small anthology in the almanac with its date and place. Exportable as
  a card via AK.
- Weeks later, a finished haiku's middle line can surface once as an
  idle-vignette caption — the buddy, quoting you back to yourself. The
  anniversary engine gains poems as a memory subject.
- **Guilt-proof:** no prompts, no streaks, no poem-a-day; the bench is
  furniture, not homework. Line pools never rhyme-shame; every
  combination parses.

**Art:** one bench chip sprite. The rest is text and existing frames.
**New flags:** `-PawmodoroBench` (open it on launch),
`-PawmodoroAnthology` (seed three poems).

---

## Phase AN — The Buddy Book (Usagi Shima's BunBook, Webkinz's papers)

Usagi Shima's players screenshot the BunBook — each bunny's little
dossier — more than the island. Pawmodoro already knows everything a
dossier needs and shows none of it in one place.

- One page per buddy, all derived, zero new state: the day you met (the
  widened log's first record with that buddy — or "before the notes got
  good"), sessions together, the discovered tastes ("loves sardines;
  regards yuzu as a practical joke"), tricks and their tiers, the
  journeys taken and what came back, one dry line for the fives ("has
  learned you'll be there"), the quirk stated as fact ("works nights").
- At the top, **the papers**: an adoption-certificate block — name (and
  given name), species, first day together — in the postcard language,
  exportable via AK. Soot's papers say what only hers can: *"Arrived on
  her own recognizance. Twelve days in the hedge. Stays because she
  decided to."*
- Lives behind a tap on the buddy in Settings' picker, and from the bond
  card.

**Guilt-proof:** the book states what happened; blank lines render as
"still finding out", never as empty slots with counts.
**New flags:** none — every existing seed flag already fills it.

---

## Phase AO — Frost Mornings (PowerWash Simulator, one stroke of it)

PowerWash Simulator became a hit on one sensation: the clean stroke.
Pawmodoro's pane is glass; winter gives it frost.

- On winter and late-autumn mornings (season × dawn/early day, real
  calendar), the scene wakes lightly frosted — a soft white Canvas veil
  with crystal specks. Wipe with a finger: the stroke clears a path,
  crisp scene underneath, one soft haptic per stroke; the buddy's eyes
  follow your hand (the tracking already exists).
- Unwiped, it melts on its own by mid-morning — the anti-obligation. No
  record is kept of whether you wiped; the pleasure IS the feature.
  This also finally ships the cozy half of the backlog's Breath on the
  Glass, without its message system.
- During a running focus the frost is already gone (it melted while you
  worked — the fiction holds and the rule holds).
- Reduce Motion: the frost renders pre-cleared in a soft vignette;
  nothing needs wiping to see.
- One free extra in the same commit, from Stray (the game, 2022's most
  famous cat mechanic): a new idle vignette line — *"nudges the pebble
  toward the edge of the shelf. Slowly. While watching you."*

**New flags:** `-PawmodoroFrost` (frost now, any season or hour).

---

## Phase AP — The Golden Hour Call (BeReal, opted into)

BeReal's whole company was one notification: *now is the moment.* The
app's no-spam rule stands, so this ships **off by default**, a setting
beside the settle-in toggle:

- When enabled: at most one quiet notification a day, at a
  deterministic-but-varying minute inside the day's best light window —
  dusk, or dawn if the log says the user is a morning person (the
  fortune's mirror trick again) — and only on days the camera's shot is
  still unspent: *"The light at the Harbor is about to do something.
  Bring the camera."*
- Taking the photo, or letting the minute pass, both end the matter;
  no follow-up, no "you missed golden hour", and the notification never
  fires two days in a row with the same wording.
- The interlock is the point: it aims the BeReal moment at One Shot and
  Clockwork knowledge, and it is the only feature in five waves that
  invites an open — which is why it asks permission first.

**Guilt-proof:** off by default, one a day at most, silent when the
photo's already taken, and structurally incapable of mentioning a missed
one.
**New flags:** `-PawmodoroGoldenHour` (arm today's call in 10 seconds).

---

## Backlog additions (with their references, for later waves)

- **The Tinker Bench** (Dwarf Fortress artifacts × Animal Crossing DIY) —
  leave two keepsakes on the bench overnight; morning brings a made
  thing with a droll generated description ("a bell on a ribbon.
  Menaces with cozy."). Held because the overnight slot is now
  genuinely crowded (visits, letters, develops, consolidation).
- **The Daily Wish** (Cozy Grove's gentle dailies) — one small stated
  preference a day ("Mochi would like to see the Harbor"). Held: the
  fortune slip already angles the day, and two pointers is a to-do list.
- **Hide and Seek** (Usagi Shima) — held on the free-placement rule
  until a prop-anchor harness exists.

## Rejected on principle

- **Duolingo's sad icon and every variant of comeback pressure** — the
  amputated half of the widget.
- **Wrapped leaderboards / percentile lines** ("top 3% of focusers") —
  a score in a party dress; the letter recounts, never ranks.
- **BeReal's default-on notification and two-minute deadline** — the
  call ships opt-in or not at all; deadlines belong to the timer.
- **Share-gated content of any kind** — nothing in the app ever asks to
  be shared; AK is a door, not a toll.

## Suggested build order

| Session | Scope | Riskiest bit |
|---|---|---|
| 1 | AN Buddy Book + AK share pass | ImageRenderer output fidelity |
| 2 | AJ Season's Letter (sentence bank + trigger) | the house voice at length |
| 3 | AJ A Year, Kept (card sequence) | card layouts in both appearances |
| 4 | AM Haiku Bench | line pools reading well in every combination |
| 5 | AO Frost Mornings + vignette line | wipe strokes vs the toy gesture stack |
| 6 | AL widget (code into PawmodoroWidgets/) | building blind against the absent target |
| 7 | AP Golden Hour Call | notification scheduling honesty |

Each session ends the standard way: checkers green, flag table updated,
As built notes, commit.
