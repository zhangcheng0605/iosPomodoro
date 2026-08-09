# Getting Pawmodoro onto other people's iPhones (UAT)

You want a friend to install it over the air, no cable, no Mac of yours
involved. That's TestFlight, and it's the right tool — but it needs the paid
Apple Developer Program. There is no free path to someone else's phone.

## Why free doesn't work here

A free Apple ID gets you *personal* provisioning: the app can only be installed
by **your Mac**, over **a cable**, onto **a device you physically have**, and it
expires after **7 days**. There's no over-the-air install and no way to send
anyone a link. It's built for testing on your own device, and that's all.

So the honest options:

| | Free Apple ID | **TestFlight** ($99/yr) | Ad Hoc ($99/yr) |
|---|---|---|---|
| Friend installs without a cable | ✗ | ✓ | ✓ (fiddly) |
| You need their phone in your hands | ✓ | ✗ | ✗ |
| Needs their device UDID up front | — | ✗ | ✓ |
| How they get it | — | a link + the TestFlight app | you host an `.ipa` somewhere |
| Build lifetime | 7 days | 90 days | 1 year |
| Testers | you | 100 internal / 10,000 external | 100 devices/year |

**Use TestFlight.** Ad Hoc exists, but collecting UDIDs and hosting `.ipa`
files is strictly worse for what you're doing.

---

## The path, once

### 1. Enrol in the Apple Developer Program

[developer.apple.com/programs](https://developer.apple.com/programs/) — $99/yr.
Approval is usually 24–48 hours. Have a government ID handy. This is the same
enrolment you'd need for the App Store, so it isn't wasted if you go further.

### 2. Set the team in Xcode

**Pawmodoro target → Signing & Capabilities → Team** → your new team (not
"Personal Team" any more). Bundle ID is already `com.pawmodoro.zhangcheng`.

### 3. Create the app record

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** →
**+** → **New App**. Platform iOS, pick the bundle ID from the dropdown, give it
a name and an SKU (any string — `pawmodoro-1` is fine).

### 4. Upload a build

In Xcode, set the run destination to **Any iOS Device (arm64)** — you cannot
archive while a simulator is selected — then:

**Product → Archive** → when the Organizer opens, **Distribute App → TestFlight
& App Store → Upload**.

Processing takes 5–15 minutes. You'll get an email when the build is ready.

> Export compliance is already answered: the project sets
> `ITSAppUsesNonExemptEncryption = NO`, which is accurate — this app makes no
> network calls at all. Without that you'd be asked on every single upload.

### 5. Add your friend

In App Store Connect → your app → **TestFlight**. Two kinds of tester, and the
difference matters:

**Internal** — up to 100 people, but each must be added under **Users and
Access** with a role on your team first. **No beta review**, builds appear for
them within minutes of processing. Best for one or two people you actually
know.

**External** — up to 10,000, invited by email or a **public link** you can just
send. The *first* build needs Beta App Review (usually well under 24 hours;
much lighter than App Store review). Later builds normally go straight
through.

For one friend doing UAT: internal is faster. For a handful of people you don't
want in your App Store Connect account: external with a public link.

### 6. What your friend does

1. Installs **TestFlight** (free, from the App Store).
2. Opens your invite link or email.
3. Taps **Install**. Pawmodoro appears on their home screen like any app.

They get a notification for each new build you upload, and there's a
**Send Feedback** button — screenshots and notes come straight back to you in
App Store Connect. That's the bit that makes this genuinely good for UAT.

---

## Shipping updates during testing

Every upload needs a **higher build number**. Bump `CURRENT_PROJECT_VERSION`
— `1` → `2` → `3` — **in both targets**: `Pawmodoro` *and*
`PawmodoroWidgetsExtension`. Build 2 is already live on the App Store, so the
next upload has to go past it.

Both, because an app and the extension embedded inside it must carry the same
`CFBundleVersion`; bump only the app and the upload comes back with a
mismatch warning. In Xcode that is the **Build** field on each target's
General tab, and it is easy to do once and think you are done.
`tools/check_icons.py` fails if the two disagree, so run it after a bump —
but the checker is a net, not a reminder.

Not theory: in a simulator build made from the current tree, the app's
`Info.plist` says `CFBundleVersion = 2` and the extension embedded inside it at
`PlugIns/PawmodoroWidgetsExtension.appex/Info.plist` says `CFBundleVersion = 2`
as well. Those two numbers are what Apple compares.

`MARKETING_VERSION` (the `1.0` users see) only changes when you want it to,
and it lives on both targets too.

Builds expire **90 days** after upload; upload a new one and testers move over.

---

## What to have testers look at

This app's whole argument is how it feels, and most of that is invisible in a
screenshot. Worth asking them directly:

- Pet the buddy during a break — does the purr land?
- Drag the ring to set the time — do the detents feel right, or fiddly?
- Sit through the last ten seconds of a session with the phone in hand.
- Finish four sessions and see whether the journey (a new place opening up)
  actually makes them want another one.

And the boring but decisive one: **does the timer survive being backgrounded**
for a full 25 minutes with the phone locked? It should — the countdown is
derived from an absolute end date, not ticks — but a real phone under real
memory pressure is the only honest test of that.
