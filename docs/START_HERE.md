# Start here — Pawmodoro, from repo to App Store

Everything in order, with rough timings. The other docs go deeper; this one is
the sequence. Don't skip ahead — step 4 takes 1–2 days of waiting, which is why
it happens on night one.

---

## Night 1 — get it running (about 1 hour, mostly downloading)

### 1. Install Xcode
Mac App Store → search **Xcode** → Get. It's ~10 GB, so start this first and go
do something else. You need Xcode 16 or newer.

### 2. Get the code
Open **Terminal** and paste these one at a time:

```sh
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/zhangcheng0605/iosPomodoro.git
cd iosPomodoro
git checkout claude/pawmodoro-ios-simulator-sf815f
open Pawmodoro.xcodeproj
```

### 3. Press ⌘R
Xcode builds the app and launches it in the iPhone simulator.

**If you get red errors instead:** that's expected and fine — this code has never
been compiled (there's no Mac in the environment it was written in). Press **⌘5**
to see the error list, copy the text with file names and line numbers, and send it
to me. I'll push fixes; you run `git pull` and press ⌘R again.

Once it runs, click around: start a timer, open Settings, switch buddies and
themes, open the paywall (purchases work in the simulator — no account, no money).

A 25-minute focus phase is a long wait, so debug builds take launch flags that
turn minutes into seconds and skip past onboarding. If you'd rather have Claude
build and tap through the app for you, in a simulator beside the conversation,
that's [`docs/SIMULATOR.md`](SIMULATOR.md) — same Xcode install, no ⌘R.

### 4. Enroll in the Apple Developer Program — **do this tonight**
[developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll)
→ enroll as an **Individual** → pay $99/year.

Approval takes **1–2 days**, so starting it now means it's ready when you are.
Everything in steps 5–7 happens while you wait.

---

## Days 2–4 — make it yours, and actually use it

### 5. Set your identity in Xcode
Click the project in the left sidebar → the **Pawmodoro** target →
**Signing & Capabilities**:

- Tick **Automatically manage signing**
- **Team**: your Apple ID (a free one works until the paid account is approved)
- **Bundle Identifier**: change `com.pawmodoro.zhangcheng` to something yours, like
  `com.pawmodoro.zhangcheng`. This is permanent once published — choose carefully.

### 6. Update the purchase IDs to match
Because you just changed the bundle ID, update the product identifiers in **two
files** so they match your new prefix:

- `Pawmodoro/Store/StoreIDs.swift`
- `Pawmodoro.storekit`

They must be identical in both, and later in App Store Connect. If they don't
match, nothing fails to build — the store just silently returns no products. It's
a horrible bug to chase, so do it now while you're thinking about it.

### 7. Run it on your actual iPhone, then use it for real
Plug the phone in, pick it from the device menu at the top of Xcode, press ⌘R.

Then **use it for a few real work sessions over several days**. This is the part
people skip and regret. App Review will not find your bugs — a reviewer spends a
couple of minutes and skips the timer. Things only real use will catch:

- Start a focus session, lock your phone for an hour, come back. Correct?
- Force-quit the app mid-session and reopen it
- Change the theme, close the app, reopen — did it stick?
- Deny notification permission and see what happens
- Let a session finish while the phone is on silent

Every bug you find here is one that doesn't become a permanent 1-star review.

---

## Day 4-ish — once your developer account is approved

### 8. Create the app record
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps → + →
New App**. Platform iOS, your app name, primary language, your bundle ID, and an
SKU (any text, e.g. `pawmodoro-001`).

**Name it something available.** Search the App Store for "Pawmodoro" first — if
it's taken you'll need a variant.

### 9. Set up getting paid
App Store Connect → **Business**. Three rows, all must say **Active**:
Paid Applications Agreement, your bank account, and tax forms (W-9 in the US,
W-8BEN otherwise).

Then apply for the **App Store Small Business Program** — it takes Apple's cut
from 30% down to 15%. It's not automatic and it's the best five minutes here.

*Skipping the paid stuff for now? You can. A free app with no purchases needs none
of this. See step 11.*

### 10. Create the four purchases
**Monetization → In-App Purchases → +**, using the exact IDs from step 6:

| Product | Type | Suggested price |
|---|---|---|
| Pawmodoro Plus | Non-Consumable | $3.99 |
| Cup of tea | Consumable | $0.99 |
| Bag of treats | Consumable | $2.99 |
| Fancy cat bed | Consumable | $5.99 |

Each needs a display name, description, and a review screenshot (a photo of the
paywall is fine). Full detail in [`MONETIZATION.md`](MONETIZATION.md).

**Attach them to your app version** under the version's In-App Purchases section,
or they'll sit in "Ready to Submit" forever.

### 11. Publish your privacy policy
Apple requires a public URL even though the app collects nothing. The text is
already written in [`PRIVACY.md`](PRIVACY.md) — enable GitHub Pages on the repo
(Settings → Pages → Source: your branch, `/docs` folder) and use the resulting URL.

---

## Day 5 — the listing (1–2 hours)

### 12. Screenshots
Run the app in the simulator, set up a nice-looking screen, press **⌘S** to save a
screenshot. You need a set for the 6.9" iPhone size; Apple scales for the rest.

Take 4–5: a focus session running, a break, the stats screen, the buddy picker,
and a theme. Free tools like AppMockUp add captions and device frames.

### 13. Fill in the text
- **Subtitle** (30 chars): "Cozy focus timer with pets"
- **Keywords** (100 chars): `pomodoro,focus,timer,study,cozy,cute,cat,dog,productivity,adhd`
- **Description**: what it is, who it's for, what Plus adds
- **Category**: Productivity (primary)
- **Age rating**: answer everything "No" → 4+
- **Privacy label**: choose **Data Not Collected** — true for this app, no network
  calls anywhere

---

## Day 6+ — ship it

### 14. Upload a build
In Xcode: **Product → Archive**. When it finishes, the Organizer opens →
**Distribute App → App Store Connect → Upload**.

If Archive is greyed out, change the run destination from a simulator to
**Any iOS Device** at the top of the window.

### 15. TestFlight with friends first (2–3 days)
App Store Connect → **TestFlight** → add a few people by email. External testers
need a quick beta review (usually under a day). Let them use it for a couple of
days. Fix what they find, then upload a new build with a bumped build number —
bumped on **both** targets, the app and the widget extension, which have to
agree. `docs/SHARE_WITH_TESTERS.md` says how.

### 16. Submit for review
Select your build, fill in every field, set the price to **Free**, hit
**Submit for Review**.

Review usually takes **24–48 hours**.

### 17. Expect one rejection
Most first apps get rejected once. It's routine, not a judgement. You reply in
Resolution Center, fix, resubmit — re-reviews are usually faster. Common causes
are a missing privacy policy URL, screenshots that don't match the app, or a crash
on the reviewer's device.

### 18. Release 🎉
Choose automatic release on approval, or hold it for a date you pick.

---

## The short version

| When | What | Time |
|---|---|---|
| Night 1 | Install Xcode, clone, ⌘R, **start the $99 enrollment** | 1 hr + waiting |
| Days 2–4 | Bundle ID, product IDs, run on your phone, **use it daily** | a few days |
| Day 4 | App record, banking, purchases, privacy policy | 1–2 hrs |
| Day 5 | Screenshots and listing text | 1–2 hrs |
| Day 6+ | Archive, TestFlight, submit | ~1 week |

**Total: roughly two weeks at a relaxed pace**, most of it waiting on Apple.

## Where to get unstuck

- **Build errors** → copy from ⌘5 and send them to me
- **Xcode/git questions** → [`XCODE_WORKFLOW.md`](XCODE_WORKFLOW.md)
- **App Store details** → [`APP_STORE_LAUNCH_GUIDE.md`](APP_STORE_LAUNCH_GUIDE.md)
- **Purchases** → [`MONETIZATION.md`](MONETIZATION.md)
- **Lock screen timer** (do after it builds) → [`LIVE_ACTIVITY.md`](LIVE_ACTIVITY.md)
