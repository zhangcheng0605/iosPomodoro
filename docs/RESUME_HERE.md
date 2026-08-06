# Resume here

**Written 6 Aug 2026 from a Windows laptop, for the Mac evening that follows
it.** Phase 0 is built except its Mac sitting, and **eight more phases went in
on top of it in the same day**: weather, the old snail, the Drift, the Cabinet
of Clocks, and all four altitudes of the Long Now — the Homestead included,
both its halves.

**None of it has been through a compiler.** That is not a warning about
quality — eleven checkers are green and every sprite was rendered and looked at —
it is a statement about what tonight is for. Expect a handful of errors, fix
them, and then look at the things no checker can judge.

**A fifth plan document now exists** — `docs/HEARTH_PLAN.md`, the owner's
monetization era (currency, cart, accessories, dens, interactions, photos,
macOS) — and **seven of its eight phases are built or part-built**: the acorn
pouch, the Magpie's Cart, the Wardrobe, the Dens, the interaction era's touch
vocabulary and keepsakes, the Scrapbook, and the writable half of macOS. They
are blind like everything else here, and sections 12 to 17 are their
walkthroughs. Only the iCloud crossing has not started.

**macOS needs a Mac sitting of its own**, listed in section 17 — the target,
signing and entitlements cannot be created from Linux, so that phase is code
waiting for a compiler that does not exist yet rather than code waiting for a
compiler that does.

**The next session is at the MacBook.** The section headed *"Tonight, at the
Mac"* is a running order, not a list.

---

## The one line to paste

> read docs/RESUME_HERE.md and do the Mac evening: build it, fix what the
> compiler finds, then walk the new screens in order. the listening pass last.

---

## Where things actually stand

**The app is on the App Store.** Version 1.0, submitted; build 2 (the music
crash fix) archived and uploaded. `docs/NEXT_UPDATE.md` is the standing list
of what the next release owes users.

**Phase 0 is code-complete except 0e, which is a Mac sitting.**

| Piece | State |
|---|---|
| 0b `Chronicle` — the append-only event log, `-PawmodoroSeedChronicle` | **done**, verified on device |
| 0c `WorldCalendar` — one opinion about "today", `-PawmodoroDate` | **done**, verified on device |
| 0d conventions in CLAUDE.md | **done** |
| 0d the dream-pool backfill | **built, never compiled** — today |
| 0a `AlbumView` rasterization | **built, never compiled** — today |
| 0a the iPad decision | **made** — `"1"`, iPhone only, see below |
| 0e the Mac-and-device sitting, four gates | **open** — tonight |
| **V-slice-1** — weather: veils, particles, the suggestion glow | **built, never compiled** |
| **V5** — the old snail | **built, never compiled** |
| **X1** — the Drift, the open hour | **built, never compiled** |
| **Y3** — the year ring | **built, never compiled** |
| **Y1** — the shelf of hours | **built, never compiled** |
| **Y2** — the Sunday Post | **built, never compiled** |
| **Y4** — the Homestead: the grove *and* the residents | **built, never compiled** |
| **X2** — the Cabinet of Clocks | **built, never compiled** |
| **V3** — wave 4: the journal 41 → 63 species, gated on the sky | **built, never compiled** |
| **V4** — the Flyway: 8 migration windows, 63 → 71 species | **built, never compiled** |
| **V6** — Tidewater: the sea at Harbor Isle, 71 → 77 species | **built, never compiled** |
| **X1** — the deep-drift species, 77 → 81, and Phase X is finished | **built, never compiled** |
| **Hearth 5, tier 2** — the greeting, and the three treats | **built, never compiled** |

### What today added

**Phase 0 finished.** The dream-pool backfill (six new `Dream` cases, gated on
the systems they came from, taking the diary from 50 possible dreams to 128),
the `AlbumView` rasterization fix (`Postcard` is `Transferable` now, so nothing
is drawn until somebody shares), and the iPad decision — `"1"`, iPhone only.

**Phase V, slice 1 — weather.** Nine weathers rolled per calendar day per place
out of `WorldCalendar.seed`. Never real weather: no permission, no network, the
meadow has its own sky. A theme-aware veil plus a particle layer, so the scene
pipeline stays 8 places × 4 hours rather than × 9. Plus the suggestion glow.

**Phase V5 — the old snail.** Six months to cross a place, six months
elsewhere. Five places; Cloudspire, Harbor and the Onsen have no continuous
ground, which was measured rather than decided.

**Phase X1 — the Drift.** Hold play: no end time, no alarm. The ring counts up
and lays a tree ring per lap. Banks one session per completed lap, so the
journey moves exactly as far as the countdowns it replaced.

**Phase X2 — the Cabinet of Clocks.** Five more faces (sand, candle, water,
incense, shadow) as generated frame strips, earned by counters the app already
keeps.

**Phase Y — all four altitudes.** Y1 the Shelf of Hours, Y2 the Sunday Post,
Y3 the Year Ring, Y4 the Homestead — the grove, and the eight residents that
move into the yard in front of it. All of them backfill from history the
moment they arrive, which is the return on having built the Chronicle first.
Y4 is finished: the four time-of-day grades are applied at draw time from
`FilmStock` (which has held the scene generator's own numbers since the
Scrapbook, so they cost no new art), and the hundred-hour panorama is a
`Postcard.Occasion` drawing the extracted `HomesteadScene`.

**Six new checkers, and they earned it.** Five real bugs were found before a
compiler saw any of this:

| Found by | What it was |
|---|---|
| `check_weather.py` | Two storms running showed **golden on both days**, and the second storm was never shown at all — the rarest weather eaten by the second-rarest, ~30 times a decade |
| `check_grove.py` | Trees *n* and *n+89* stood 0.0097 apart — both layout axes were golden-ratio-derived and re-phased at Fibonacci intervals |
| `check_clocks.py` | The candle and the incense **ran backwards** on their last frame, because the flame counted as "the part that grows" |
| `check_yearring.py` | The plan's own tinting made a night session's day measure ΔE 1.3 from a day nobody focused — indistinguishable, in one theme, forever |
| `check_residents.py` | Every homestead resident was **80–100 % buried** once the grove hit capacity — the beehive at 0 %. Invisible until a hundred and twenty hours of focus |
| `check_species.py` | The **Grey Heron has been letterboxed since wave 2** — drawn 19×18 inside a 34×40 frame, so eight points of every heron shipped as dead space. Two new rows had it too |

**And four the checkers missed**, all caught by rendering the thing and looking
at it: the grove came out in diagonal stripes at thirty trees, the water clock
tapered the wrong way, the homestead's lantern sat directly on top of its well
(and the beehive on the bench), and the well lost a bite to the card's rounded
corner. That is now a convention in CLAUDE.md — *a green checker is not a
look.*

---

## Tonight, at the Mac

### 1. Build it, and expect errors

```sh
cd ~/Desktop/…/iosPomodoro          # wherever the repo lives
git fetch origin && git checkout claude/phase-0-dream-backfill-j9sbmo && git pull
python3 tools/check_swift.py         # should print "all pass" before you start
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/simulator \
    CODE_SIGNING_ALLOWED=NO build
```

`check_swift.py` is not a type checker. **A handful of errors here is the
expected outcome, not a sign something is wrong.** In likelihood order:

0. **The nine new SwiftUI files.** `WeatherView`, `SnailView`, `YearRingView`,
   `ShelfOfHoursView`, `SundayPostView`, `HomesteadView`, `ClockFaceView`,
   `PostcardExport`, and the changes inside `TimerRingView` and `ContentView`.
   `Canvas`, `TimelineView` and `GeometryReader` are all shapes the app
   already uses, so most should be quiet. `YearRingView` has the most novel
   geometry (`Path.addArc` twice per wedge) and `ContentView`'s
   `.onLongPressGesture` on a `Button` is the one interaction pattern not used
   anywhere else in the app.
1. **`Pawmodoro/Views/PostcardExport.swift`.** `Transferable`,
   `DataRepresentation`, `SharePreview` and `ShareLink` are exactly the
   argument-label-and-inference class the checker is blind to. If one line has
   to go, it is `.suggestedFileName("Pawmodoro postcard.png")` — delete it and
   the representation still works. If `Postcard` is refused as non-`Sendable`,
   the fix is `struct Postcard: Codable, Equatable, Identifiable, Sendable`.
2. **`Dream.swift`'s multi-pattern arm** in `TimerEngine.daysSinceMeeting`:
   `case .memory(let species), .regular(let species):`. Both bind `Species`, so
   it should be legal; if the compiler disagrees, split it into two arms.
3. **Implicit members in switch expressions** — `Visitor.reachedAt` returns
   `Stray.Stage` as bare `.edge`, `Yours.reachedAt` returns `Bond` as bare
   `.friendly`. `Stray.Stage.scenePresence` already does this and compiles, so
   this should be fine.
4. **`bond >= .acquainted`** and **`stage >= visitor.reachedAt`** — both types
   are `Comparable` and both already use `<` elsewhere.

Then Release, which is where a missing `#if DEBUG` stand-in would show up.
Six new flags today — `fillDreams`, `forcedWeather`, `forcedSnail`, `drift`,
`driftLaps`, `forcedClockFace` — and all six stand-ins are in place;
`check_swift.py` verifies that, and it is one of the rules it was proved on:

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
    -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build
```

### 2. Look at the dream diary — the one screen that changed

The diary lives at the bottom of the stats sheet: tap the paw-print button,
then scroll past the almanac, bond, chart, postcards, star atlas and journal.

**Every tile at once**, which is the only way to see the new art:

```sh
tools/run-sim.sh --demo --headless -PawmodoroFillDreams
```

(`run-sim.sh` passes anything starting `-Pawmodoro` straight to the app, so the
flag lists below can be appended to that same line verbatim.)

128 tiles — the full `Dream.everything`. What to actually check, in this
order:

- **The thirteen new sprites read at 62pt.** They were looked at on Linux at
  8× on a cream card and they read there; 62pt on a phone is the real test.
  The five sounds are the risk — they are drawn as *sounds*, not as whales and
  owls, so they are abstract by design and either land or don't.
- **Silhouettes.** `companion` and `visitor` tiles reuse full-colour sprites
  rendered as silhouettes. If any of them shows up in colour, `isSilhouette`
  missed a case.
- **Both appearances and all four themes.** `xcrun simctl ui "$UDID"
  appearance dark`.

**Then that the gates actually gate**, which `-PawmodoroFillDreams` cannot
tell you because it bypasses them. Each of these should end a focus phase with
the named kind in the diary:

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroBond 150 -PawmodoroDream yours                     # your chair/door/desk
$S -PawmodoroFillJournal 5 -PawmodoroDream regular              # the one you keep meeting
$S -PawmodoroFillJournal -PawmodoroDream sound                  # only ever heard
$S -PawmodoroStray 3 -PawmodoroDream visitor                    # the cat, still outside
$S -PawmodoroBond 150 -PawmodoroUnlockPlus -PawmodoroDream companion
$S -PawmodoroSeason autumn -PawmodoroDream season               # the time of year
$S -PawmodoroBond 125 -PawmodoroDream neighbour                 # the homestead's own
```

The bubble itself appears over the sleeping buddy between 40 % and 70 % of a
focus phase — about 10–21 s in under `--demo` — but do not try to catch it with
a screenshot loop; tool round-trips are ~9 s. Let the phase finish and read the
diary tile instead, which is the durable result.

Two rules to confirm hold, because both are load-bearing and neither is
obvious from the code:

- **A season is only dreamable during that season.** Without
  `-PawmodoroSeason`, `-PawmodoroDream season` should find nothing at all for
  most of the year. That is correct behaviour, not a broken flag.
- **The stray's `visitor` dreams stop when she comes in.** At
  `-PawmodoroStray 5` they should be gone, and `companion` should have gained
  "the cat who came in" instead.

### 3. The weather, and the snail

Both are new since the last Mac session and neither has been compiled.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroWeather storm      # the darkest veil, plus the flash
$S -PawmodoroWeather mist       # the lightest, and the fog banks
$S -PawmodoroWeather golden     # only ever follows a storm, so it needs the flag
$S -PawmodoroWeather rain       # then tap the rain ambience chip — it should be ringed
$S -PawmodoroSeason winter -PawmodoroWeather rain    # should come out as snow
$S -PawmodoroSnail 50           # the old snail, halfway across
$S -PawmodoroDate 2026-12-21    # everything date-driven at once, honestly
```

What to look at:

- **The veil in all eight themes and both appearances.** The contrast numbers
  say it is safe (922k measurements) but the numbers are dominated by the text
  capsules — what a bad veil actually costs is the *place* disappearing behind
  its own weather, and only an eye sees that. `storm` and `mist` are the two
  to judge.
- **The storm flash.** Eleven seconds apart, a third of a second long, soft.
  If it reads as a strobe at all, lower the opacity in `WeatherView.flash` —
  do not shorten the period.
- **The snail.** `tools/check_snail.py --preview /tmp/snail.png` draws her
  whole crossing on one strip from Linux, and it looked right; the thing to
  confirm on a phone is that eighteen points is big enough to notice and small
  enough not to be a mascot.
- **The almanac's today line**, which is the one place the weather is named in
  words.

### 4. The open hour

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroDrift              # cast off on launch
$S -PawmodoroLaps 5             # five rings deep already
$S -PawmodoroLaps 40            # far past the six-hour question, which should fire
```

**Hold** the play button for 0.6 s to cast off, and hold it again to come back.
Under `--demo` a lap is 25 seconds, so rings appear fast enough to watch.

What to check:

- **The tree rings.** One per lap, inside the track, stopping at eight. If they
  crowd the countdown text, raise the padding step in `TimerRingView.treeRings`.
- **What it banks.** End a five-lap drift and the stats screen should gain five
  sessions and 125 minutes; the paw row should gain five prints. Under one lap
  should bank nothing at all — that is the rule, not a bug.
- **The six-hour question.** `-PawmodoroLaps 40` puts it past the threshold;
  background and foreground the app to fire `syncAfterWake`. Both answers are
  meant to feel equally reasonable.
- **A sighting at the top of a lap.** `-PawmodoroSighting stag -PawmodoroDrift`
  and wait through two laps: the stag should come round twice.

### 5. The year ring

It sits in the stats sheet, above the postcards.

```sh
tools/run-sim.sh --demo --headless -PawmodoroSeedStats -PawmodoroSeedChronicle
tools/run-sim.sh --demo --headless -PawmodoroSeedStats -PawmodoroClock 22
```

The second one forces every seeded session to read as a night session, which
paints the whole ring at the dark end of the ladder — the fastest way to see
that the ladder is doing what it claims.

`check_yearring.py` says the four steps are separable in all sixteen
theme/appearance combinations (worst ΔE 10.4 against a bar of 8), so what is
left for an eye is whether 365 one-pixel wedges look like a year or like
noise. If they look like noise, widen the wedge gap (`+ 0.35` in
`YearRingView.wheel`) before touching any colour — the colours are measured
and the gap is not.

### 6. The shelf, and the letter

Both are in the stats sheet — the letter at the very top, the shelf under the
year ring.

```sh
tools/run-sim.sh --demo --headless -PawmodoroSeedStats -PawmodoroSeedChronicle
```

`-PawmodoroSeedStats` seeds a fortnight, so there *is* a finished week behind
today and the letter has something to say. Without it the letter correctly
does not appear at all — that is the design, not a missing view.

- **The letter** should be five or six sentences and read like an animal wrote
  it. If any line reads as a status report, the fix is the sentence, not the
  layout. `check_post.py` guards the register mechanically but it cannot tell
  you whether a sentence is any good.
- **The shelf** should show a cluster of lit candles around whatever hours the
  seeded history used, and a dark rim elsewhere. Check there is no count
  anywhere on it — that is the anti-goal, and it is the kind of thing that
  gets helpfully added back later.

### 7. The homestead

Stats sheet, under the week chart. It is the one surface where two different
clocks are drawn into the same picture, and the only one where an eight-frame
loop runs all at once.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroBond 200 -PawmodoroSeedStats   # all eight residents, a wood behind them
$S -PawmodoroBond 30                        # two residents, a nearly empty yard
```

`-PawmodoroBond n` seeds n sessions of 25 minutes, so it sets the trees and
the residents together: 200 gives all eight neighbours and about eighty-three
trees. There is no residents flag on purpose.

`check_residents.py` has already proved they never overlap, never leave the
card, clear its rounded corners and read against every theme. What is left is
what a checker cannot ask:

- **Does the loop disappear?** Eight residents at 2fps is meant to be
  something you notice on the third visit, not motion. If the card reads as
  busy, the number to change is `Resident.frameSeconds`, not the sprites.
- **Do eight loops cost anything?** The `TimelineView` is only mounted when
  somebody lives there, so an empty homestead should be free — but scroll the
  stats sheet with all eight running and watch for a stutter. If there is one,
  the answer is a `Canvas`, which means giving up `.interpolation(.none)` and
  redrawing the sprites at 1× instead.
- **Does the yard read as a yard, or as a shelf?** This is the judgement the
  render could not settle. Two rows, offset by half a slot; if it still looks
  like a row of icons along the bottom edge, the band wants to be deeper
  rather than the sprites bigger.
- **The arrival caption.** `-PawmodoroBond 29`, then finish one focus phase:
  the buddy's line should become "… has noticed — somebody has moved into the
  birdhouse" and stay that way for the whole break, then go back to normal
  when you start the next session. Nothing else should announce it — no card,
  no confetti, no notification.

### 8. Wave 4 — the sky's own animals

Twenty-two new species and three new sounds, all gated on the world's weather.
`check_species.py` has proved every one is reachable more than eight days a
year, that no two unarrangeable gates are stacked, and that every frame now
matches the art in it. What is left is what an eye and an ear have to judge.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroWeather rain  -PawmodoroSighting gardensnail
$S -PawmodoroWeather mist  -PawmodoroSighting roedeer      # the palest sprite
$S -PawmodoroWeather storm -PawmodoroSighting stormpetrel
$S -PawmodoroWeather snow  -PawmodoroSighting ermine       # white on a white veil
$S -PawmodoroWeather breeze -PawmodoroSighting redkite
$S -PawmodoroWeather rain  -PawmodoroStray 3               # she shelters
$S -PawmodoroFillJournal                                   # all 63 tiles at once
```

- **The white ones over the weather veil.** Ermine, Snow Fox, Ghost Slug and
  Fog Moth are all near-white by design, and they are shown *under a veil of
  their own weather* — a white animal in a mist veil is the one combination
  `check_contrast.py` does not cover, because it measures text capsules rather
  than sprites. If any of the four vanishes, the fix is a darker outline in
  `generate_wildlife.py`, not a lighter veil.
- **The stray in the rain.** `-PawmodoroWeather rain -PawmodoroStray 3`: she
  should be on the *left* rather than her usual right, facing in, and should
  already be there when the phase starts. Both columns are proven ground
  everywhere she goes; what nobody has seen is whether the swap reads as her
  moving or as a bug.
- **The three new sounds**, with the other five, in the listening pass. Thunder
  is shaped noise under a 400 Hz cutoff with two swells; the foghorn is one
  held note; the geese are fourteen scattered calls. All three are the
  furthest this generator has gone from a tone, and none has been heard.
- **First Thunder.** Not verifiable tonight unless it is spring — it is gated
  on the month, one chance a year. `-PawmodoroDate 2027-04-02
  -PawmodoroWeather storm` will do it, and the journal tile should then stay
  filled and not offer a second one until next April.

### 9. The clock faces

Settings → The cabinet of clocks. Two of the six are earned by places that
take a hundred sessions, so use the flag.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroClockFace incense -PawmodoroUnlockPlaces
$S -PawmodoroClockFace sand
$S -PawmodoroClockFace shadow -PawmodoroNightSessions 60
```

`check_clocks.py` has already proved every face runs forward, never stalls,
and finishes when the phase does — 960 sprite/dial pairs, faintest 7.79:1. So
what is left for an eye is one question the checker cannot ask: **does a face
read at 46 % of the dial, over scenery, with the digits sitting on top of it?**
Under `--demo` a lap is 25 seconds, so all twelve frames go past in half a
minute.

If a face is too busy under the digits, the fix is
`.frame(height: diameter * 0.46)` in `TimerRingView`, not the art — the art is
measured and the size is not.

### 10. Share a postcard

`-PawmodoroPostcard` puts one in the album. Long-press it in the stats sheet →
Share. The share sheet should show a text title like "Whispering Woods, 12 Aug"
rather than a picture — **that is the change**, not a regression: an image
preview is an eager render, which is the thing being removed. What lands in
Messages or Files must still be the full 640pt PNG.

### 11. The four gates of 0e — the actual reason for a Mac evening

These gate all of Phase W and have been waiting since the plan was written.

1. **The listening pass.** All 50 tracks, 5 one-shots and 6 ambiences, **on a
   device, with headphones**. Notes per track. Anything broken gets fixed or
   pulled. *Nobody has ever heard any of it* — and this is the surface that
   shipped 100 %-broken on device while flawless in Simulator. This is the
   single biggest untested thing in the repo.
2. **Install the iPhone SE runtime** and walk the rows in the old feature
   table that need a short phone.
3. **Create the Widget Extension target** — File → New → Target → Widget
   Extension, name `PawmodoroWidgets`, tick "Include Live Activity". Then
   delete Xcode's generated files, drag in
   `PawmodoroWidgets/PawmodoroLiveActivity.swift`, and tick
   `Pawmodoro/LiveActivity/PawmodoroActivityAttributes.swift` for **both**
   targets. Five minutes. `docs/LIVE_ACTIVITY.md` has the detail. It ships in
   Phase Z, not now — this is just getting the one-time step done while the
   Mac is open.
4. **Register the App Group container**, write the migration behind a flag,
   leave it dormant until Z.

---

## The iPad decision, made

**`TARGETED_DEVICE_FAMILY` is now `"1"`** — iPhone only, on purpose. Two
occurrences in `Pawmodoro.xcodeproj/project.pbxproj`, lines 273 and 303. It is
the Deep Time plan's recommendation and the honest description of what the app
is: at iPad size the layout has a dead band of scenery through the middle and
the transport controls sit on top of the house.

**One thing to know before you archive.** The app is already live declaring
iPad support, so anyone who installed 1.0 on an iPad cannot update to the next
version. On a just-launched app that is close to nobody — which is why now was
the cheap moment. Undo is two characters on those two lines.

Revisit when Phase Y's Homestead panorama earns a big canvas.

### 12. The pouch and the cart — the economy's first outing

Settings → *The magpie's cart*. Every padlock in the app now opens the unlock
sheet instead of going straight to the paywall, so this touches four pickers.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroBond 200          # a full pouch, honestly earned
$S -PawmodoroAcorns 30         # too poor for anything — the distance lines
$S -PawmodoroOwnEverything     # every owned state at once
$S -PawmodoroCart              # straight into the cart
$S                             # a clean install: an empty pouch
```

`check_catalog.py` has proved the fixture holds, every item has art, and the
economics sit inside both fences (25 days for the dearest thing, 300 for the
lot). What is left for an eye:

- **The unlock sheet's balance of voice.** The Trade button and the "Or
  everything, at once" line under the rule are the whole commercial argument.
  If Plus reads louder than the thing you came to look at, the sheet has
  stopped selling the thing — the fix is the Plus block's weight, not the
  price.
- **The distance lines.** `-PawmodoroAcorns 30` then open a buddy: it should
  say "a few weeks of afternoons away", never a number of sessions and never
  a progress bar. Check the wording does not read as a target.
- **The magpie at 46pt.** She was drawn and looked at on Linux; the head-tilt
  loop runs at 1.5s and should read as a bird ignoring you, not as a UI
  element blinking.
- **That the timer screen still has no balance on it anywhere.** Fence 8. If
  an acorn count has crept onto the countdown, it goes.
- **Trade something, then check the four pickers.** The traded buddy should
  be selectable everywhere immediately, and the padlock gone.

### 13. The wardrobe

Settings → *Your buddy* → the two accessory rows.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroOwnEverything -PawmodoroWear sunhat,bow
$S -PawmodoroOwnEverything -PawmodoroWear knittedcap,scarf -PawmodoroBuddy owl
$S -PawmodoroOwnEverything -PawmodoroWear crown,bellcollar -PawmodoroBuddy penguin
$S -PawmodoroAcorns 5                   # the locked state, with prices showing
```

`check_accessories.py` has cleared 1180 piece-on-frame placements: nothing
floats, nothing clips off the top or the sides, and everything reads at 2:1
against the fur it sits on. What is left is what only an eye settles:

- **Watch a full animation cycle wearing a hat.** The anchors are measured per
  *frame*, so the hat should ride the blink, the bounce and the stretch without
  sliding. If it slides, the frame it slides on has the wrong anchor and the
  fix is in `generate_accessories.py`, never in `BuddyAnchors.swift` — that
  file is generated.
- **The sleeping poses.** The curled-up poses are where a collar is most
  likely to look wrong, and they are the pose the buddy holds for twenty-five
  minutes at a time.
- **The bounce.** `BuddySprite` pads its clip upward by 30 % so a hat survives
  `happy_1`. Finish a focus session wearing the sun hat and watch the top of
  it. If the brim is cut, raise `BuddySprite.headroom` — the checker parses
  that constant, so it will follow.
- **The one-time remark.** Put a piece on for the first time: the caption
  should say it once, then go back to normal on the next session, and never
  say it again for that piece even after a relaunch.

### 14. The dens

Stats sheet → the homestead. One den shows at a time: the current buddy's.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroDen igloo -PawmodoroBond 200 -PawmodoroClock 22   # occupied, at night
$S -PawmodoroDen igloo -PawmodoroBond 200 -PawmodoroClock 13   # empty, midday
$S -PawmodoroDen oakhollow -PawmodoroBond 200 -PawmodoroClock 13  # the owl inverts it
```

`-PawmodoroDen` grants the den *and* switches to its owner, because a den
belongs to a species. `check_residents.py` has already cleared every den
against all eight neighbours, the near band, the rounded corners and the
footprint, and confirmed each pair of frames actually differs.

- **The occupied frame at 22pt.** Each den's second frame is a light, a tail
  or a muzzle a few pixels across. If you cannot tell occupied from empty at
  the size it ships, the fix is more contrast in `generate_dens.py`, not a
  bigger den — the footprint ceiling is measured.
- **The owl's inversion.** `-PawmodoroClock 13` with the owl should show her
  *in* the oak hollow, and at 22 should show it empty. Backwards means
  `Den.isOccupied` has lost the nocturnal flip.
- **The homestead line.** With a den owned it should read "There is the pond,
  … and an igloo, which nobody questions." — no count anywhere.
- **The first night.** Finish one session with `-PawmodoroClock 22` and a new
  den: the Sunday Post should carry that den's line the following week, once,
  and never again.

### 15. Touching the buddy, and what it brings back

The timer screen. This is the one section here that cannot be checked from
Linux at all — it is a gesture.

```sh
S="tools/run-sim.sh --demo --headless"
$S                                       # tap the buddy's head, nose, chin, tummy
$S -PawmodoroBuddy penguin               # the tummy is its favourite
$S -PawmodoroKeepsakes 4                 # the shelf, in the stats sheet
```

`check_touch.py` has cleared 458 regions across 118 frames: nothing is off the
animal, nothing is too small to aim at on a pose the buddy holds, no two
regions collapse onto each other, and all twelve favourites are findable. What
is left:

- **Does a tap land where you think it did?** Touch the four spots in turn and
  read the caption. The regions are generous and they tile, so a near-miss
  should land on a neighbour rather than on nothing — if a tap anywhere on the
  buddy produces no spot line at all, the grid conversion in
  `BuddyView.gridPoint` is wrong.
- **The favourite.** Each buddy has one, hinted nowhere. `Buddy.favouriteSpot`
  is the answer key — but try finding one without it first, because that is
  the experience.
- **Stroking.** A slow drag re-fires on a 0.4s throttle. It should feel like
  scratching an animal, not like a button repeating.
- **That focus is still sacred.** Start a focus phase and touch the buddy: it
  should stir, not react by spot, and say nothing about your hand.
- **The keepsake shelf.** `-PawmodoroKeepsakes 4` puts four on it. Nothing
  anywhere should badge or announce them — if there is a "new" dot on the
  stats button, it goes.

### 16. The Scrapbook

Settings → *Where you were*. The first feature in this app that touches the
filesystem, the photo library and Core-Image-shaped colour work, so it is the
one most likely to have a compile error in it.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroSeedScrapbook                       # three generated samples
$S -PawmodoroSeedScrapbook -PawmodoroOwnEverything   # every stock unlocked
$S                                               # empty, and the + button
```

The simulator has no camera and its library is three wallpapers, hence the
seed flag. `check_film.py` has proved the stocks *are* the world's own light —
the three time-of-day grades match `generate_scenes.py` coefficient for
coefficient and "Pressed" matches the journal's sepia — plus nine fixture rows.
What is left:

- **Does `filmStock(_:)` actually look like the grade?** It is built from
  `.saturation`, `.colorMultiply` and a `.plusLighter` overlay, which is the
  SwiftUI approximation of the affine transform the checker verifies
  arithmetically. If a stock looks washed out or blown, that modifier is where
  it is wrong — not `FilmStock`, whose numbers are proved.
- **The swatch row.** Each swatch previews the stock on *that photograph*. If
  they all look identical the `.compositingGroup()` is in the wrong place.
- **Import a real photograph** from the library and check the orientation. A
  portrait photo coming back sideways means the renderer draw in
  `SnapshotImport` is not baking the EXIF rotation.
- **The permission flow.** `PhotosPicker` should show the system sheet with
  *no* prompt of its own. If iOS asks for library access, the picker has been
  swapped for something else somewhere.
- **Remove one, then relaunch.** The file should be gone and the grid should
  not show a gap — and `prune()` should quietly clear anything orphaned.

### 17. The Mac target — a sitting of its own

**Nothing in this section has been near a compiler on either platform**, and
that is structural: the target does not exist. This is the one-time Xcode work,
same shape as the widget extension in Phase Z.

1. **File → New → Target → App**, name it `Pawmodoro Mac`, and give it the
   **same bundle identifier as the iOS app**. Universal purchase requires it
   and it cannot be changed after the first archive — get this right first
   time.
2. Add the whole `Pawmodoro/` group to the new target's membership. It is a
   file-system synchronized group, so this should be one checkbox.
3. Sandbox on; add the **user-selected file** entitlement (the Scrapbook's
   picker) and **camera** only if a camera path is ever added.
4. Build. Expect errors, and expect most of them in three places:
   - `Platform.swift`'s AppKit half — `NSColor(name:dynamicProvider:)`, the
     `CGContext` bitmap path in `renderJPEG`, and
     `NSImage.cgImage(forProposedRect:context:hints:)` are the three calls
     written from documentation rather than from a compiler.
   - `MenuBarExtra` and `.menuBarExtraStyle(.menu)` in `PawmodoroApp`.
   - Anything still reaching for UIKit that `check_swift.py`'s new guard rule
     did not catch because it was inside an existing `#if`.
5. **The listening pass, on real Mac output, headphones and speaker.** Before
   any archive. `AVAudioEngine` on new hardware is the exact class that
   shipped fifty tracks broken on iPhone while the Simulator smiled — the
   pre-mixed single-node law is the protection, the pass is the proof.
6. Then the things only a Mac can show: does the buddy read at sixteen points
   in the menu bar? Does the countdown keep time after the app has been idle
   long enough for App Nap to throttle it? (It should — the countdown derives
   from an absolute end `Date` — but that is the claim, and this is the test.)

---

### 18. The Flyway — eight fortnights a year, so bring the flag

Nothing about this is visible on an ordinary day, which is the point and also
the problem: on 6 August the only passage open is the comet, and only in a
year divisible by four with remainder two. **`-PawmodoroPassage <id>` is the
only practical way to see any of it** — it holds one window open and every
other one shut.

```sh
tools/run-sim.sh --demo --headless \
    --args "-PawmodoroPassage snowgeese -PawmodoroSighting snowgoose \
            -PawmodoroPlace meadow -PawmodoroClock 14"
```

Ids: `swans`, `cuckoo`, `paintedladies`, `salmon`, `redwings`, `snowgeese`,
`waxwings`, `comet`.

What to look at, in order:

1. **The sprites in the scene**, which is the only place four of them are
   *movements* rather than animals. The skeins (swans, geese), the salmon run
   and the painted ladies are drawn as several small shapes going one way, and
   they are the first sprites in this app that have to read as a group at
   sighting size. `-PawmodoroSighting <species>` puts one on screen; the
   species ids are `whooperswan`, `cuckoo`, `paintedlady`, `salmonrun`,
   `redwing`, `snowgoose`, `waxwing`, `comet`.
2. **The almanac's "On the flyway" section**, which is the whole design and is
   defined by what it does *not* say. With the flag set and the species seen,
   it should name the passage and print its present-tense line. With the
   species **never** seen it must print **nothing at all** — no row, no
   padlock, no countdown. That absence is the feature; check it deliberately,
   because a bug here looks exactly like an empty section.
3. **The afterword.** Harder to reach: it needs a passage that is closed *and*
   whose species has been seen. `-PawmodoroFillJournal` plus
   `-PawmodoroDate 2026-12-15` should give a past-tense line about the geese.
4. **The journal hint** under an unseen migrant: "Some years, around late
   February" and nothing more precise. If it ever names a date, the fence has
   moved.
5. **The dream**, `-PawmodoroDream flight.going`.

One compile risk specific to this: `Passage.window` uses
`Calendar.ordinality(of: .day, in: .year, for:)`, which returns `Int?`. Both
call sites unwrap it in a `guard`; if the compiler complains it will be about
the `DateComponents` build above it rather than the ordinality itself.

### 19. Tidewater — the shore, and the first thing that moves in hours

`-PawmodoroTide` is the flag; the tide turns every six hours and a spring low
is a couple of hours twice a day for a few days a fortnight, so waiting for one
is not a plan.

```sh
tools/run-sim.sh --demo --headless \
    --args "-PawmodoroPlace harbor -PawmodoroTide springlow \
            -PawmodoroSighting octopus -PawmodoroClock 14"
```

Values: `springlow`, `low`, `mid`, `high`, or a bare number 0–1.

1. **The shore strip, at all four states, in all four themes and both
   appearances.** This is the one piece of Tidewater no checker can judge: it
   is `Theme.bark` at 55% over whatever the Harbor scene draws there, and
   whether that reads as *wet mud* or as *a grey smear* is a question only a
   person can answer. Try `springlow` and `high` back to back — the difference
   should be visible but should not make the place look like two places.
2. **That it does not touch the paw capsule.** The strip tops out at 0.79 of
   the screen and the capsule sits at 0.718. Checked arithmetically by
   `check_tide.py`, but on a short phone (SE) the layout is tighter than the
   fractions suggest and this is worth one look.
3. **The tide curve in the almanac** — a sinusoid with a dot on it, at Harbor
   Isle only. Open it on two consecutive days: the curve should visibly shift
   by about fifty minutes, which is the thing it exists to teach.
4. **The six new sprites**, ids `starfish`, `anemone`, `hermitcrab`, `curlew`,
   `oystercatcher`, `octopus`. The curlew and the oystercatcher share one
   `wader` template and are told apart only by their bills; that separation is
   the one to check at sighting size.
5. **The seal changed.** She is now `[.mid, .high]` — the only shipped species
   this phase touched. `-PawmodoroTide high -PawmodoroSighting seal`.
6. **A dream**, `-PawmodoroDream tidal.pools`.

### 20. The Crossing — arithmetic only, and nothing to look at

`Pawmodoro/Model/Crossing.swift` is the **merge**, with no transport behind
it: no CloudKit, no `NSUbiquitousKeyValueStore`, no network call. There is
nothing to drive in a simulator and nothing on screen changes. What tonight
owes it is one thing only: **that it compiles.** It is model code with no
SwiftUI in it, so if it builds it is almost certainly right — everything else
about it is already tested by `tools/check_crossing.py`, which runs 400 pairs
of generated worlds through a Python port of it.

Two compile risks worth knowing before you look at the error list:

- `Dictionary.values.sorted(by:)` with a `(T, T) -> Bool` method reference —
  `sorted(by: inOrder)` passes a static function where a closure is wanted.
  It should infer, but this is the kind of thing that needs a `{ inOrder($0,
  $1) }` if it doesn't.
- `SightingRecord`'s memberwise initialiser is called with all six labels in
  declaration order, including the optional `weather`. If a field is ever
  added to that struct this call breaks, which is the correct outcome.

**When you do build the transport** — a separate sitting, and the plan says
last — read the doc comment on `merge(journal:)` first. It records a decision
that is deliberately conservative (counts take the max, so a two-device user
undercounts rather than a retried sync overcounting) and names the correct
replacement: a per-device counter, which needs a stored-shape change to
`SightingRecord` and a per-install id. That is transport-phase work, and the
note in the Swift is addressed to whoever does it.

---

## Verification loop (every session)

```sh
python3 tools/check_swift.py             # every session, Mac or not
python3 tools/check_weather.py           # any date-rolled feature
python3 tools/check_yearring.py          # after touching a palette or the ring
python3 tools/check_post.py              # after any Chronicle kind or letter copy
python3 tools/check_grove.py             # after touching the grove layout
python3 tools/check_residents.py         # after moving a resident or its art
python3 tools/check_species.py           # after any roster or weather-gate change
python3 tools/check_catalog.py           # after any price, earn rate or fence
python3 tools/check_accessories.py       # after any buddy sprite or wardrobe change
python3 tools/check_touch.py             # after any anchor or touch-region change
python3 tools/check_film.py              # after any scene grade or film stock
python3 tools/check_clocks.py            # after touching any clock face
python3 tools/check_contrast.py          # must print "all pass"
python3 tools/check_stray.py             # must print "all pass"
python3 tools/check_snail.py             # after moving her or redrawing a scene
python3 tools/check_crossing.py          # after ANY new store, storage key or merge
python3 tools/check_flyway.py            # after any passage, window or migrant species
python3 tools/check_tide.py              # after the tide model, a tide gate or the shore strip
python3 tools/check_greeting.py          # after ANY change to what the buddy says on a new day
python3 tools/check_treats.py            # after any treat, preference or offering gesture
tools/run-sim.sh --demo --headless
xcodebuild … -configuration Release …    # the Release build catches what Debug won't
```

All twenty were green when this was written: 922,032 contrast pairs, 20,736
stray pairs, 483,840 snail pairs, 29,200 place-days of weather, 400 pairs of
merged worlds, 105 Swift files and 625 imagesets. `check_snail.py` takes about
18 seconds; the rest are quick.

The reason to keep running them is that several paid for themselves on their
very first run — `check_weather.py` found a logic bug in the golden-day rule,
`check_residents.py` found every homestead resident buried under a grown wood,
and `check_crossing.py` found the journal merge double-counting every sighting
on a retried sync. None of the three had been compiled at the time.

`check_crossing.py` is the one to run after work that looks unrelated to it.
Its first part is not about the merge at all: it walks every store class in
the app and fails on any operation that makes a store smaller without a
written reason. A new feature with a counter that goes down passes every other
checker here.

---

## Building without a Mac — the normal condition

Most of this app was written this way. The rules that make it work:

### What `check_swift.py` catches

Unbalanced brackets; `#if DEBUG`/`#else` drift in `LaunchOptions` (a flag
missing its Release stand-in builds fine in Debug and only fails Release);
asset names with no imageset; **dream sprite names expanded from their enum**;
`StorageKeys` missing from `.all`; `Theme.`/`LaunchOptions.` members that don't
exist; constellation links to stars that don't exist; and non-exhaustive
switches over the app's own enums, **including the ones inside an
`extension`**. Every rule was verified by deliberately breaking the code.

### What it cannot catch

Argument labels, type inference, SwiftUI misuse. A worked example from the
Chronicle session: `chronicle.add(.bond, bond.rawValue)` passed the checker and
was still wrong — `Bond` is `Int`-raw and the parameter wanted a `String`. Only
the compiler found it. **When you add an enum case or touch a raw value, write
out the type in your head.**

### Safe to build blind

Model code and pure logic; captions, copy, roster data, new enum cases; the
Python generators in `tools/`, whose checkers verify the output *pixels*; plan
and documentation work.

### Not safe

Anything touching `AVAudioEngine` — the Simulator lies about audio formats, and
that is how fifty tracks shipped unplayable. New layout: it compiles and looks
wrong. Anything you would want to *see* before believing.

### Art, specifically

New sprites are safe to draw blind **if you render them and look at the PNG**
— that is real verification, not a guess. Two traps, both hit today:

- **Regenerating art moves pixels you didn't touch.** Running
  `generate_sprites.py` rewrote 69 existing PNGs on a newer Pillow. All 69 were
  byte-different and **pixel-identical**; they were checked and reverted, so
  the commit contains only the thirteen new ones. Always compare pixels rather
  than trusting `git status`.
- **Never `git checkout --` a file you haven't committed.** A test script used
  it to undo a deliberate one-line break and threw away an hour of uncommitted
  work in `Dream.swift`. Commit before you break things on purpose.

---

## Two traps that cost an hour each when forgotten

- **This repo lives on the iCloud-synced Desktop.** The sync service stamps
  `com.apple.FinderInfo` on the built bundle and `codesign` refuses it
  ("resource fork, Finder information, or similar detritus not allowed").
  Always build and archive with `-derivedDataPath` pointing **outside** the
  synced folder. Xcode's own Product → Archive menu item hits this.
- **Never click into the Bundle Identifier field in Xcode.** It was left
  focused once, picked up a stray keystroke and silently became
  `com.pawmodoro.zhangchenso-`. A wrong bundle ID uploads fine and then fails
  to match the App Store record.

---

## Reference: the plan documents

| Doc | What it covers | State |
|---|---|---|
| `docs/DEEP_TIME_PLAN.md` | Phases V–Z: weather, sound, the open hour, the long now, widgets | **current work**; Phase 0 built except 0e |
| `docs/NEXT_UPDATE.md` | What the next App Store release owes users | standing list |
| `docs/CONTENT_PLAN.md` | The world: places, cast, journal, themes, postcards | built out |
| `docs/DELIGHT_PLAN.md` | The feel: living buddy, tactile timer, living scene | A–C built, D needs the Xcode target, E2 open |
| `docs/SOUND_ALMANAC.md` | The fifty tracks and the mixer | built, **never listened to** |

Every phase carries an **As built** section recording where the code and the
plan diverged. Read the relevant one before touching that code — several
record a decision that looks arbitrary until you know why.

**Do not start Phase V.** Weather touches scenery, veils and the contrast
matrix, and the first slice explicitly wants a week on a real phone before
anything lives in it. **Do not start Phase W** until the listening pass has
notes: that is a hard gate, not a caveat.

---

## Known gaps, stated plainly

- **Nobody has heard the music.** Fifty tracks and five one-shots, verified
  structurally, never listened to — on the surface that shipped 100 %-broken on
  device. Gate 1 of 0e above.
- **Today's two commits have never been compiled.** Everything else in this
  file has.
- **Never verified on any device**: scene toys, the night firefly,
  eye-tracking, the snow-globe shake, organic micro-encounters, the iPhone SE
  layout.
- **iPad support is now dropped** — decided, not overlooked. Read the section
  above before the next archive.
- The app's own screens say "Pawmodoro" while the App Store listing says
  "Paawmodoro" (the shorter name was taken). Apple permits it; it is explained
  in the App Review notes; decide whether you want it.
- `docs/MONETIZATION.md`'s product table is stale. `CONTENT_PLAN.md`'s M
  section is authoritative.
