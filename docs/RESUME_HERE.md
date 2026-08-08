# Resume here

**8 Aug 2026 — the two branches are merged and the merged app has been
walked.** Branch: `claude/pet-interactions-retention-7caoj8`. The merge was
11 conflicts over ~2,000 lines and is committed as "Merge the two branches:
one app again".

Walking it found **seven bugs, all now fixed, reproduced first and seen fixed
on screen** — a fatal crash on "Share the papers", 36 species that could roll
a pale coat with no sprite (an invisible animal on the rarest event in the
app), the celebration card sitting on top of the high five, every postcard
cropping to a band of sky, the drift clock wrapping out of the dial, the
homestead burying its own caption, and a renamed buddy signing postcards with
its factory name. `docs/NEXT_UPDATE.md` has the table, the severities and the
one item still open (the Harbor/Cloudspire postcard ground — a design call,
with the measurement already done).

Two checker rules were added and **deliberately broken first to prove they
catch anything**. Device Release is 37.7 MB. (The 45 MB ceiling was retired in Aug 2026 — see `CLAUDE.md`. Measure and justify rather than trip over a number nobody could explain.)

## Where things stand

**The whole Deep Time plan (V, W, X, Y) is built** plus the owner's first
playtest batch. Today's Mac session: 9 compile errors fixed across the blind
commits, four real bugs found by looking (inverted tide, wood-on-black,
earless lynx, Debug-only symbol in Release), then Phase W built end to end —
found-gating, ambience→AAC on a new single-node AmbienceLoop player, four
circadian grades per loop, rain-family variants, the Bell of Hours with its
24-hour clock ring, and Music III (catalogue 65, three found mixtapes incl.
Soot's Tape). Then nine playtest orders: paw row removed, ambience row made
scrollable (was a plain HStack — ends unreachable), bright phase-correct
yellow moon + brighter stars at night, inverted-photo fix (CGContext.draw in
a y-down renderer), take-a-photo + camera glyph on the main screen, tip jar
surfaced with owner-brief copy, 4 free accessories + 2 free clock faces
(bloom, lantern), drag-the-food feeding with the buddy watching/perking/
eating, and the rain family retuned ~25% gentler.

Verification discipline held throughout: 22 checkers green, Debug AND
Release clean at every commit, features driven on screen (agents' screenshots
preserved in the session scratchpad), Release 41 MB vs the 45 ceiling.

## What remains, exactly

1. **W2 remnant (small, buildable anywhere):** the field-recording cards —
   almanac line "You have heard the forest at dawn" + a sepia card when all
   four grades of a loop have been heard. Needs per-grade listening recorded
   (a Chronicle kind or subject scheme) + an almanac row. Everything else in
   W is done.
2. **Phase Z (blocked on the owner, 5 min in Xcode):** File → New → Target →
   Widget Extension, name `PawmodoroWidgets`, tick "Include Live Activity".
   Then the Phase D/Z code (already written) activates. Do NOT hand-write
   the target into project.pbxproj.
3. **The listening pass (owner's ears, ~1 hour):** 120 ambience grades, 16
   bells, 65 tracks — never heard by anyone. Priorities: the retuned rain
   family; Rain + "Windowpane Study" together (the whole Rainy Day Tapes
   claim is that they duet); one bell at night volume.
4. **Older-plan opens:** E2's full accessory wave and the "Now playing" radio
   chip were both taken on 8 Aug — see the commits. **Alternate app icons**
   are still open; the investigation is done, so this is a short job now:

   - There is exactly one `AppIcon.appiconset`, and `project.pbxproj` sets
     `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` twice (lines 250 and 281,
     Debug and Release).
   - Adding alternates needs two more build settings on both configurations:
     `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (space-separated) and
     `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`. That is an
     additive settings change, not a target change — unlike the Widget
     Extension it does **not** need Xcode's GUI, and it reverts by deleting
     the two lines.
   - `tools/generate_assets.py:672 make_icon()` already draws the icon and
     writes it to `ICONSET`; alternates want that parameterised by palette
     rather than a second function, so the seasonal icons come out of the
     same drawing the shipped one does.
   - Runtime is `UIApplication.shared.setAlternateIconName(_:)`, which must
     go behind `Platform.swift`'s fence like every other UIKit call, and
     wants a picker in Settings beside the theme row.
   - iOS shows a system alert every time the icon changes and there is no
     supported way to suppress it. Decide whether that is acceptable before
     building the picker — it may argue for tying the icon to the theme
     rather than offering a separate control.
5. **On-device checks that needed a real phone:** camera shutter→keep round
   trip, the new-moon night, Reduce Motion eat-fade, haptics.

## How this session worked (worth repeating)

Sequential fresh-context builder agents against the house rules, each gated
on all 22 checkers + both build configurations + driving its change on
screen, with no commit rights; the main session verified independently and
committed. Writers must stay sequential in one tree (they share ContentView,
TimerEngine, the generators) — use worktrees if you want parallel writers.

## The one line to paste next session

> read docs/RESUME_HERE.md; build the W2 field-recording cards, then walk
> docs/NEXT_UPDATE.md and prep the App Store update

## Standing traps

- iCloud Desktop breaks codesign: always -derivedDataPath outside the repo.
- Never click into Xcode's Bundle Identifier field (it once became
  com.pawmodoro.zhangchenso-).
- Generators churn encodings: byte-compare and revert what didn't really
  change before committing.
- The Simulator lies about audio formats and cannot hear: AVAudioEngine
  changes need the device, and "verified" never means "listened to".
- Transient UI (captions ~3.5s) cannot be screenshot-verified: use
  `simctl launch --console-pty` and print, or read durable state.
