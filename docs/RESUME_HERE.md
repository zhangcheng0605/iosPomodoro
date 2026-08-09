# Resume here — paused 10 Aug 2026, mid-submission

Everything is committed and pushed. `git status` is clean, `HEAD` is
`5843090`, and the remote matches. Nothing was lost by stopping.

## Where this stands

**The code is done and green.** All 25 checkers pass. iOS Debug, iOS Release,
macOS Debug and macOS Release all build. Five adversarial verifiers ran
against the five parallel fixes and **none was disputed**.

The two facts that matter most for the submission, both proved rather than
assumed:

- **The promo code is out of the Release build.** `zac888` exists in Debug so
  Cheng can test Plus without buying it from himself, and is absent from both
  Release binaries. Verified on both sides — digest, `Redeem`, `promo`,
  `keeper`, `PromoCodes`, `showRedeem` all present in Debug and absent in
  Release — and then photographed: Settings ▸ Pawmodoro Plus has four buttons
  in Debug and three in Release.
- **The macOS app icon ships.** `CFBundleIconName` is present and the rendered
  icon matches the true 1024 rendition to a mean of 0.002/255 (against
  1.86/255 for a 256px upscale), so macOS is drawing our art rather than a
  placeholder. Nothing local would have caught its absence: an earlier archive
  had no icon at all and Xcode's own `-validate-for-store` passed.

Also landed: the Scrapbook's macOS import control (a Mac sheet has no toolbar,
so `.topBarLeading` had been rendering nothing and the feature was
unreachable); the snail no longer standing on the ambience row; Mac hover
states, tooltips, context menus and a toolbar that does not collapse into a
chevron; `NSSupportsLiveActivities` conditioned per-SDK; and the doc and
checker debt an adversarial verifier found around the icon.

## What was interrupted, and is therefore NOT done

Two agents were running when this stopped. Neither had produced a result, so
there is nothing to recover — just work to redo:

1. **The macOS App Store screenshots.** The existing eight at 1440x900 in
   `docs/MAC_STORE_ASSETS.md` § 2 **still predate the menu-bar fix** and show
   the 418pt buddy. They must be re-shot before upload. The lead shot should
   be the menu bar extra — it is the thing the phone cannot do. Engine:
   `mas-assets/final/shot.py` (in the session scratchpad, which does not
   survive — it may need rebuilding on `tools/mac_probe.py`).
2. **A pre-submission walk.** Nobody has yet driven the *combined* result of
   five parallel changes end to end. This is where this app has historically
   broken, so it is worth doing before upload rather than after a rejection.

## How to drive the Mac build

**Do not use the mouse.** Cheng works at this machine and has said so twice.
`tools/mac_probe.py` is built for exactly this — read its docstring, which
records what is measured rather than assumed, including the two traps that
have already been paid for (`HOME` does not isolate the app; `defaults export`
returns a partial view that destroys state) and the one thing it genuinely
cannot do (hover cannot be synthesised).

## What only Cheng can do — the real critical path

None of this depends on any further code.

1. **Add Platform → macOS** on the existing **Paawmodoro** record. **Never a
   new app** — a second record permanently loses Universal Purchase and
   orphans the paying iOS users. Reversible until the Mac version is
   *approved*, not until the click.
2. **Paid Applications Agreement, banking and tax must all be active.** This
   is the slowest item on the entire list because it involves his bank, and if
   it is not green then Plus and the tip jar cannot sell however good the
   build is. The bank account holder name must match the developer account
   exactly (an individual account: Cheng Zhang).
3. **App Store Small Business Program** — 15 % commission instead of 30 %. It
   is not automatic; it must be applied for, and nothing prompts you.
4. **Pricing and Availability → "iPhone and iPad Apps on Mac"** — with
   `TARGETED_DEVICE_FAMILY = 1` the iOS build may already be offered on Apple
   Silicon Macs, and two Pawmodoros in one search result looks bad.
5. **macOS metadata** — description (lead with the menu bar), keywords,
   category Productivity, support URL, review notes.
6. **Validate before uploading** — `altool --validate-app` or the Organizer's
   Validate button. Needs an app-specific password, so it cannot be done from
   here. It is the last cheap failure before an irreversible upload.
7. **The listening pass on real hardware.** Headphones *and* built-in
   speakers, changing the output device **while a track is playing**. This is
   build 2's scar: all fifty tracks were unplayable on every real iPhone and
   no simulator could show it. A Mac's output device is 48 kHz or 44.1 and
   changes mid-session. Nobody but the owner has ears on this machine.

## One honest note

Before `mac_probe.preserve()` existed, test launches seeded the **Mac** app's
state (bond, journal) in
`~/Library/Preferences/com.pawmodoro.zhangcheng.plist`. The iPhone was never
touched, the container is intact, and nothing in this app decays — but if that
Mac state should be pristine, `-PawmodoroResetState` clears it.
