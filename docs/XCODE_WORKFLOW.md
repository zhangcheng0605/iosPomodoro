# Getting the code onto your MacBook and into Xcode

Yes — the GitHub repo is the source of truth. You clone it once, then `git pull`
whenever I push more work. You never need to copy files around by hand.

## One-time setup

1. Install **Xcode 16 or newer** from the Mac App Store (free, ~10 GB).
2. Open **Terminal** and clone the repo:

   ```sh
   cd ~/Developer          # or wherever you keep projects; mkdir -p ~/Developer first
   git clone https://github.com/zhangcheng0605/iosPomodoro.git
   cd iosPomodoro
   ```

3. Switch to the branch I'm working on:

   ```sh
   git checkout claude/pawmodoro-ios-simulator-sf815f
   ```

4. Open the project:

   ```sh
   open Pawmodoro.xcodeproj
   ```

5. Press **⌘R**. The app builds and launches in the iPhone simulator.

That's the whole loop. No Apple Developer account needed for this part.

## Getting my later changes

Whenever I push more work:

```sh
cd ~/Developer/iosPomodoro
git pull
```

Then press ⌘R again. If Xcode is already open it picks up changed files
automatically — no need to close and reopen the project.

> If `git pull` ever says your local changes would be overwritten, see
> "Keeping your signing settings" below — that's almost always the cause.

## Running on your actual iPhone

1. Plug the phone in (or pair over Wi-Fi) and trust the Mac.
2. In Xcode: **Xcode → Settings → Accounts → +** and sign in with your Apple ID.
   A free Apple ID is enough for this — no $99 needed yet.
3. Click the project in the sidebar → the **Pawmodoro** target →
   **Signing & Capabilities**:
   - Check **Automatically manage signing**
   - Set **Team** to your personal team
   - Change **Bundle Identifier** to something unique to you, e.g.
     `com.zhangcheng.pawmodoro` (already set; change only if Apple says it is taken
     `com.zhangcheng.pawmodoro`, which Apple will not accept)
4. Pick your phone from the device dropdown at the top, then ⌘R.

With a free account the app expires after 7 days — just re-run it to reinstall.
With the paid account it stays for a year.

## Keeping your signing settings

Steps 3 above edit `project.pbxproj`, which is a tracked file. That means your
Team and Bundle ID show up as local changes and can collide with my pushes.
Pick one of these:

**Simplest — commit your signing change once:**

```sh
git add Pawmodoro.xcodeproj/project.pbxproj
git commit -m "Set my signing team and bundle identifier"
git pull --rebase          # replays your commit on top of my new work
```

If the rebase reports a conflict in `project.pbxproj`, the safe resolution is
almost always: keep your `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER`
lines, take mine for everything else.

**Alternative — set them outside git.** In Xcode, put your Team and Bundle ID in
a local `.xcconfig` that's gitignored. Cleaner long-term, more fiddly to set up.
Not worth it until the conflicts actually annoy you.

## If something doesn't build

The code in this repo has been syntax-checked but **never compiled** — there's no
Mac in the environment I work in, so the first real build happens on your
machine. If you hit errors:

1. In Xcode, open the Issue navigator (**⌘5**) to see the full list.
2. Copy the error text and paste it to me — include the file and line.
3. I'll push a fix; you `git pull` and try again.

Two specific things worth checking on the first run:

- **Ambient sounds silent?** Check the target's **Build Phases → Copy Bundle
  Resources** and confirm the four files from `Pawmodoro/Resources/` are listed.
  Xcode 16's synchronized groups should add them automatically.
- **Notifications never arrive?** iOS only asks for permission once. If you
  denied it, re-enable under **Settings → Pawmodoro → Notifications** on the device.

## Handy Xcode shortcuts

| Keys | Does |
|---|---|
| ⌘R | Build and run |
| ⌘. | Stop |
| ⌘⇧K | Clean build folder (fixes weird stale-build errors) |
| ⌘5 | Issue navigator (the error list) |
| ⌥⌘P | Resume SwiftUI preview |
| ⌘S (in Simulator) | Save a screenshot — this is how you make App Store screenshots |
