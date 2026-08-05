# First-Time App Store Launch Guide (step by step)

You've never shipped an app before — this is everything, in order. Total cost: **$99/year**.

## What you need

| Thing | Cost | Why |
|---|---|---|
| A Mac | — | Xcode only runs on macOS. Any Apple Silicon Mac works. |
| Xcode 16+ | Free (Mac App Store) | Builds, signs, and uploads the app. ~10 GB download. |
| Apple ID | Free | Basis for everything below. |
| Apple Developer Program | $99/year | Required to distribute on the App Store. |
| An iPhone (recommended) | — | You can develop on the free simulator, but test on real hardware before submitting. |

> **No Mac?** There's no good way around it for iOS. Cloud Macs (MacStadium,
> Scaleway) exist but are clunky for beginners. A used M1 Mac mini is the
> cheapest real option.

## Step 1 — Run the app (today, free)
Full instructions with exact commands are in **[`XCODE_WORKFLOW.md`](XCODE_WORKFLOW.md)**.
The short version:

1. Install **Xcode 16+** from the Mac App Store.
2. Clone this repo and open `Pawmodoro.xcodeproj`.
3. Press **⌘R** — the app launches in the iPhone simulator. That's it, no account needed.
4. To run on your own iPhone: plug it in, select it as the run target, and sign in
   with your Apple ID under **Xcode → Settings → Accounts**. Free "personal team"
   signing lets you install on your own device (app expires after 7 days, reinstall as needed).

## Step 2 — Join the Apple Developer Program (~1–2 days)
1. Go to [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll).
2. Enroll as an **Individual** (companies need a D-U-N-S number — skip that hassle).
3. Pay $99. Approval usually takes 24–48 hours. You'll need government ID sometimes.
4. Individual accounts show your **legal name** as the seller on the App Store. Fine for v1.

## Step 3 — Set your app's identity in Xcode
1. Click the project → **Signing & Capabilities** tab.
2. Set **Team** to your (now paid) developer account.
3. Set **Bundle Identifier** to something you own, reverse-DNS style:
   e.g. `com.pawmodoro.zhangcheng`. This is permanent once published — choose carefully.
4. Check the app name: "Pawmodoro" must be unique on the App Store. Search the store first;
   the display name is set in App Store Connect later and can differ from the project name.

## Step 4 — Create the app record in App Store Connect
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps → + → New App**.
2. Fill in: platform (iOS), name, primary language, your bundle ID, and an SKU (any string, e.g. `pawmodoro-001`).

## Step 5 — Prepare the listing (do this while polishing the app)
You'll need:
- **App icon**: already done — `Pawmodoro/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  is a 1024×1024 opaque PNG with no rounded corners (Apple rounds it for you).
  Regenerate or restyle it with `python3 tools/generate_assets.py`.
- **Screenshots**: required for 6.9" iPhone (1320×2868). Take them in the simulator
  (**⌘S** saves a screenshot) — one set is enough; Apple scales for smaller phones.
  Tools like AppMockUp let you add cute captions/device frames for free.
- **Description** (up to 4000 chars) + **subtitle** (30 chars, e.g. "Cozy focus timer with pets").
- **Keywords** (100 chars): `pomodoro,focus,timer,study,cozy,cute,cat,dog,productivity,adhd`
- **Privacy policy URL**: required even if you collect nothing. The text is written for you
  in [`PRIVACY.md`](PRIVACY.md) — that file also explains how to publish it free via
  GitHub Pages to get the URL App Store Connect asks for.
- **Privacy "nutrition label"**: in App Store Connect, declare **"Data Not Collected"**
  (true for this app — everything stays on device).
- **Age rating** questionnaire: all "No" → rated 4+.
- **Category**: Productivity (primary), Health & Fitness or Lifestyle (secondary).

## Step 6 — TestFlight beta (recommended, 2–3 days)
1. In Xcode: **Product → Archive**, then in the Organizer window click **Distribute App → App Store Connect → Upload**.
2. In App Store Connect → TestFlight, add friends by email as internal/external testers.
3. External testers require a lightweight "beta review" (usually < 24h).
4. Fix what they find, bump the build number, upload again.

## Step 7 — Submit for review
1. In App Store Connect, select your uploaded build, fill in every listing field.
2. Pricing: set **Free** (you can add IAP later).
3. Click **Submit for Review**.
4. **Review time: usually 24–48 hours** (Apple states ~90% of submissions are reviewed
   within 24 hours). First apps sometimes take longer or get an extra look.

### Common first-timer rejections (and how this app avoids them)
- **Guideline 2.1 (crashes/bugs)**: test on a real device, background/foreground the timer.
- **Guideline 4.2 (minimum functionality)**: a bare timer can be flagged as "too simple."
  The buddy, paw prints, stats, streaks, ambience, and onboarding are what lift Pawmodoro
  above that bar — don't strip them back to just a countdown.
- **Placeholder identifiers**: the repo ships `com.pawmodoro.zhangcheng` and an empty
  `DEVELOPMENT_TEAM`. Both must be yours before you archive (see Step 3).
- **Missing privacy policy URL**: see Step 5.
- **Screenshots that don't match the app**: keep captions honest.

If rejected: don't panic. You reply in Resolution Center, fix, resubmit — the re-review
is usually faster. Almost everyone gets rejected at least once; it's a normal loop.

## Step 8 — Release
Choose **automatic release** after approval, or manual if you want to time it.
Congrats — you're live. 🎉

## Answers to your questions, short version
- **Do I need Xcode?** Yes (free, Mac-only). It's the only supported way to build & upload.
- **Do I need an Apple Developer account?** Yes, $99/year, for App Store distribution.
  You do NOT need it to build and test on the simulator or your own phone.
- **How long is approval?** Developer account: 1–2 days. Each app review: usually 24–48h.
  Budget a week end-to-end for the launch step including one rejection cycle.
