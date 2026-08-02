# Putting Pawmodoro on your own iPhone

Yes — you can install this on your phone and use it every day without the App
Store, TestFlight, or anyone's approval. Xcode installs it directly over a
cable, and it behaves like any other app: home screen icon, notifications,
Focus modes, the lot.

There is exactly one catch, and it depends on which Apple account you use.

| | Free Apple ID | Apple Developer Program ($99/yr) |
|---|---|---|
| Cost | nothing | $99 a year |
| App keeps working for | **7 days**, then it won't launch until you plug in and rebuild | **1 year** |
| Apps at once | 3 | unlimited |
| Needs the Mac again | every week | once a year |
| Good for | trying it out | actually living with it |

**Recommendation:** start free today — it takes ten minutes and costs nothing.
If you find yourself using it daily, the $99 is worth it purely to stop
re-signing every week, and you need it for the App Store anyway.

---

## One-time setup

### 1. Give the app its own bundle identifier

The project still ships the placeholder `com.example.pawmodoro`. Apple needs
something unique to you, and `example.com` is reserved.

In Xcode: select the **Pawmodoro** project in the left sidebar → the
**Pawmodoro** target → **Signing & Capabilities** → change **Bundle
Identifier** to something like:

```
com.zhangcheng.pawmodoro
```

Reverse-domain style. It doesn't have to be a domain you own — it just has to
be unique. Use it consistently from here on.

> Doing this also breaks the in-app purchase product IDs, which are prefixed
> with the bundle ID. That's fine for personal use — the store isn't set up
> yet anyway, and the paywall degrades to its "store isn't available" state.
> See [MONETIZATION.md](MONETIZATION.md) when you get to that.

### 2. Sign in and pick your team

Still in **Signing & Capabilities**:

1. Tick **Automatically manage signing**.
2. **Team** → *Add an Account…* → sign in with your Apple ID.
3. Pick the team that appears — it'll be called *Your Name (Personal Team)*.

Xcode creates a free provisioning profile. If it shows a red error about the
bundle identifier being unavailable, change it again — someone else has that
one.

### 3. Plug in your iPhone

1. Connect it by cable, unlock it, and tap **Trust** on the phone.
2. iPhone **Settings → Privacy & Security → Developer Mode** → turn it **on**.
   The phone restarts. (This only exists on iOS 16+, and only appears once
   a Mac has tried to install something.)
3. In Xcode's toolbar, click the run-destination dropdown (it currently says
   a simulator name) and pick your iPhone.

### 4. Build and run

Press **⌘R**.

The first run fails on the phone with *"Untrusted Developer"*. That's
expected. On the iPhone:

**Settings → General → VPN & Device Management → your Apple ID → Trust**

Then press **⌘R** again. The app installs and launches, and the icon stays on
your home screen.

---

## Living with it

**On the free account**, after 7 days the app refuses to open. To fix it:
plug in, open the project, press **⌘R**. Your data survives — sessions,
streak, settings and the places you've reached are all stored on the phone and
are not touched by reinstalling.

Worth doing anyway, since you're rebuilding: `git pull` first to pick up
whatever's new.

**Notifications:** allow them the first time it asks, otherwise phase-end
alerts won't arrive while the app is backgrounded.

**Haptics:** this is the first place you'll actually feel them — the purr when
you pet the buddy, the detents on the timer dial, and the heartbeat over the
last ten seconds are all no-ops in the simulator.

---

## If something goes wrong

**"Failed to register bundle identifier"** — someone already has that ID.
Change it to something more specific and try again.

**"Unable to install… device is locked"** — unlock the phone and press ⌘R.

**The app is greyed out on the home screen after a week** — that's the 7-day
expiry, not a bug. Plug in and rebuild.

**"Could not launch… process launch failed: Security"** — you haven't trusted
the developer profile yet. See step 4.

**Anything else** — copy the exact error from Xcode's Issue navigator; it's
almost always one of the four above wearing a different hat.
