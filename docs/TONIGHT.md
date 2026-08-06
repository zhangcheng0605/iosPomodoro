# Tonight, at the MacBook

> ## ✅ Done — 6 Aug 2026, on the Mac
>
> Nine blind commits produced **eight compile errors** (six of them two
> repeated mistakes) and Release found a ninth. Four real faults were found
> by looking, three of which no checker could have caught:
>
> | | |
> |---|---|
> | **The tide was inside out** | Mud drawn *below* the waterline and only at high water. Both fractions run downward, so the high-water mark is the smaller number. Fixed and seen both ways. |
> | **The hundred-hour wood stood on black** | `HomesteadScene` left the ground to its callers; the stats card drew one, the postcard did not. Ground moved inside the shared view. |
> | **The lynx had no ears** | Tufts drawn upward from a grid with no room above the head — three of their four pixels clipped. Grid 15→19 rows. |
> | **A Debug-only symbol named from Release code** | `SnapshotSeed`. `check_swift.py` now has a rule for it, verified by reintroducing the bug. |
>
> The treats work — tap *and* drag, right reception table. The apparent
> failure was mine: taps landing on the ambience row, and a 3.5-second
> caption that is shorter than a screenshot round-trip. **Use
> `simctl launch --console-pty` for anything transient; screenshots cannot
> see it.**
>
> Everything else in Step 2 walked clean: greeting, panorama, tide curve,
> flyway absence, shelf of hours, graded homestead, sprite legibility.
> Debug and Release both build; all 20 checkers green; installed on the phone.


**Written 6 Aug 2026 from a Windows laptop, at the end of a long Linux day.**
Nine commits went onto `claude/phase-0-dream-backfill-j9sbmo` today and **none
of them has been near a compiler.** This is the running order for the evening.

`docs/RESUME_HERE.md` is the long version — it has the full walkthrough for
every screen and the history of why things are the way they are. This file is
just tonight: get it building, look at the things no checker can judge, stop.

---

## The line to paste

> read docs/TONIGHT.md and do the Mac evening: build it, fix what the compiler
> finds, then walk the new surfaces in order. the listening pass last.

---

## Step 0 — get the branch, and confirm the baseline (2 minutes)

```sh
cd ~/Desktop/…/iosPomodoro
git fetch origin && git checkout claude/phase-0-dream-backfill-j9sbmo && git pull
for f in tools/check_*.py; do python3 "$f" >/dev/null || echo "FAILED: $f"; done
```

**Twenty checkers, all green when this was written.** If one fails here, before
you have changed anything, it is an environment problem (a Pillow version, a
Python version) rather than a code problem — don't start fixing code.

That loop takes about half a minute. `check_snail.py` and `check_contrast.py`
are most of it.

---

## Step 1 — build, and expect errors

```sh
python3 tools/check_swift.py     # should say "all pass" before you start
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/simulator \
    CODE_SIGNING_ALLOWED=NO build
```

**A handful of errors is the expected outcome, not a sign something is wrong.**
`check_swift.py` is not a type checker: it cannot see argument labels,
inference or SwiftUI misuse.

### Ten new files, in the order they are likely to break

| # | File | What to expect |
|---|---|---|
| 1 | `Views/TreatTray.swift` | A `DragGesture` and an `.onTapGesture` on the same view. Should resolve — the drag has `minimumDistance: 4` — but if the tap never fires, wrap the drag in `.simultaneousGesture` or move the tap to a `Button`. **Keep both**; `check_treats.py` fails if the tap goes away, and it is the only path VoiceOver has. |
| 2 | `TimerEngine.offered` | A **labelled tuple** stored on an `@Observable` class, read by `BuddyView` as `.onChange(of: engine.offered?.reception)`. If the macro objects, promote it to a small `struct Offering: Equatable` — three fields, no other change needed. |
| 3 | `Model/Crossing.swift` | `byID.values.sorted(by: inOrder)` passes a static func where a closure is wanted. It should infer; if not, `{ inOrder($0, $1) }`. Also calls `SightingRecord`'s memberwise init with all six labels — if a field is ever added to that struct this breaks, which is the correct outcome. |
| 4 | `Views/TideCurveView.swift` | A bare `Canvas` with `canvas.stroke(_:with:style:)` and `canvas.fill(_:with:)`. Novel-ish shapes for this app but not new API. |
| 5 | `Views/HomesteadScene.swift` | Extracted out of `HomesteadView` today. Both call sites were checked by hand; the risk is the `.filmStock()` modifier landing on a `GeometryReader`. |
| 6 | `Model/Passage.swift` | `Calendar.ordinality(of:in:for:)` returns `Int?` and both call sites guard it. If the compiler complains it will be about the `DateComponents` build above it, not the ordinality. |
| 7 | `Model/Tide.swift` | Plain arithmetic. `MoonPhase.age(on:)` was verified to exist. |
| 8 | `Views/TideView.swift` | Two rectangles and an offset. Should be quiet. |
| 9 | `Views/FilmStockGrade.swift` | The `.filmStock()` extension, moved out of the bottom of `ScrapbookView.swift`. If you get "invalid redeclaration", the old copy did not get deleted — it should have. |
| 10 | `Model/Greeting.swift`, `Model/Treat.swift` | Model-only, no SwiftUI. If these fail it is something small. |

### Two things I checked by hand, so don't chase them

- **`Species.Spec` memberwise init argument order.** The struct gained
  `tides`, `deepLaps` and `passage` today, and Swift requires memberwise
  arguments in declaration order. All **81** rows were verified in order by a
  script. If you get an argument-order error here it is a row *you* just
  edited.
- **`Grove.Tree` and `Resident.allCases`**, which the new panorama postcard
  leans on. Both exist with those names.

---

## Step 2 — walk the new surfaces

Ordered by *how likely I am to have got it wrong*, not by importance. The
first four are the ones where a checker was structurally unable to help.

### 1. The shore strip at Harbor Isle — the least-verified thing in the branch

```sh
tools/run-sim.sh --demo --headless \
    -PawmodoroPlace harbor -PawmodoroTide springlow -PawmodoroClock 14
```

Then `-PawmodoroTide high` and compare. This is `Theme.bark` at 55 % over
whatever the Harbor scene draws at 0.79–0.88 of the height, and **whether that
reads as wet mud or as a grey smear is a question only a person can answer.**
Check all four themes and both appearances.

- It should be *visible* but should not make the place look like two places.
- It must not touch the paw capsule at 0.718. The arithmetic clears it by
  seven points and `check_tide.py` guards that, but on a short phone (SE) the
  layout is tighter than the fractions suggest.

### 2. The treat drag

```sh
tools/run-sim.sh --demo --headless -PawmodoroClock 14
```

Let a focus phase end so a break starts, or just leave it idle. Three treats
sit under the paw row.

- Drag one **upward** — more than 30pt — and it should be offered. That
  threshold was picked blind and is the single most likely thing to feel
  wrong: too eager, or unreachable on a small screen.
- Tap one. Same result. **Both paths must work.**
- Find a favourite: the fox wants the berry, the otter and the penguin want
  the fish, the dog wants the biscuit. Only the favourite bounces.
- The tray must **not** appear during a running focus phase.

### 3. The greeting

```sh
tools/run-sim.sh --demo --headless -PawmodoroGreet gladder
```

Also `daily`, `away`, `first`. The buddy plays the existing `waking` one-shot
— stretch, look up, bounce — and the caption holds for 3–4.5 s depending on
warmth.

The thing to judge: **does the caption outlast the animation awkwardly?** The
hold is longer than the bounce on purpose, so a gladder greeting lingers. If
it reads as a stuck caption rather than as a pause, shorten `Warmth.seconds`.

### 4. The hundred-hour panorama

```sh
tools/run-sim.sh --demo --headless -PawmodoroPanorama
```

Open the album. It is the whole wood at 320×168 with the buddy in front. A
hundred trees plus eight residents on a postcard is the densest composition in
the app and `check_residents.py` says they fit — but "fit" and "reads as a
wood" are different questions.

### 5. Everything else, briefly

| Flag | What to look at |
|---|---|
| `-PawmodoroPassage snowgeese -PawmodoroSighting snowgoose` | Four of the eight migrants are drawn as *movements* (skeins, a salmon run, two butterflies). Do they read as a group at sighting size? |
| `-PawmodoroSighting octopus -PawmodoroTide springlow -PawmodoroPlace harbor` | Six new shore animals. The curlew and the oystercatcher share one template and differ only by their bills. |
| `-PawmodoroSighting lynx` / `whitestag` / `sunfish` / `mantaray` | The deep-drift four. The lynx took two drafts and is the one I trust least. |
| `-PawmodoroDrift -PawmodoroLaps 3` | Deep drift, so those four become eligible. |
| `-PawmodoroDream tidal.pools` / `flight.going` / `adrift.deep` | The seven new dreams. |
| Almanac at Harbor | The tide curve — a sinusoid with a dot. Open it two days running: it should shift ~50 minutes. |
| Almanac anywhere | "On the flyway" must show **nothing** for a passage never seen. That absence is the feature; a bug here looks exactly like an empty section. |
| Stats sheet | The homestead card is now graded by time of day. `-PawmodoroClock 22` vs `-PawmodoroClock 12`. |

---

## Step 3 — the Release build

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release …
```

Today added **five** new launch flags — `-PawmodoroPassage`, `-PawmodoroTide`,
`-PawmodoroPanorama`, `-PawmodoroGreet`, and `Greeting.Warmth` as a flag type.
Every one needs its `#else` stand-in or Release fails while Debug is fine.
`check_swift.py` guards exactly this and is green, but the Release build is
the only real proof.

---

## What is blocked tonight, and why

| | Why |
|---|---|
| **Phase W — sound** | Hard-gated on 0e's listening pass. Nothing starts until that has notes. |
| **Phase Z — widgets** | Needs an Xcode extension target that does not exist. |
| **The macOS target** | Same: target, signing and entitlements cannot be made from Linux. `docs/RESUME_HERE.md` §17 is the one-time sitting. |
| **Tier 2's brushing and tucking-in** | Each needs art plus a gesture I would have no way to see. Two of tier 2's four are done. |
| **The Crossing's transport** | CloudKit. The *merge arithmetic* is written and tested; read the doc comment on `merge(journal:)` before starting, it records a decision to revisit. |

---

## What I could not check at all, being honest

Everything in Step 2 is there because a checker was structurally unable to
judge it. Beyond that:

- **No SwiftUI was compiled or rendered.** Every layout number in the ten new
  files is reasoned, not seen.
- **The 30pt drag threshold** was picked with no device in hand.
- **Sprite legibility at real size.** Every new sprite was rendered and looked
  at as a contact sheet at 8–10×; three were redrawn because of it (the
  painted lady, the lynx, the starfish). None has been seen at 30pt on a
  phone.
- **Anything you verify by ear.** Unchanged from before — no audio was touched
  today.

The checkers found four real bugs before a compiler saw any of this: a journal
merge that doubled every sighting on a retried sync, two devices that would
have remembered different afternoons forever, a migration window that opened
on day −2 of the year, and a spring-low-at-dawn combination that lines up four
hours a year. They cannot find a layout that looks bad.
