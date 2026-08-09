# The Mac walk — 9 Aug 2026

_A tester's pass over the macOS build, screen by screen, looking for what App
Review or a first Mac user would find. Nobody had driven the Mac since roughly
fifteen features landed (the drifting cloud layer, the near plane, tappable
constellations, the sky lean, buddy acrobatics, five app icons, the re-voiced
ambience, the Scrapbook import fix, the Dynamic Type rework)._

**Nothing was uploaded. No repository file was changed except this one.**

---

## Verdict

**Not ready.** The app is a well-behaved phone app in a window — the art, the
scenery layers, the buddy, the break confetti, the sheets and the keyboard
shortcuts all render like a real Mac app — but **two defects are of the "this
is broken" class**, and one of them is in the single feature the Mac version
exists for.

1. **The menu bar extra draws a 418 × 402-point buddy.** It eats about 416
   points of the menu bar and shows a magnified slice of the cat's face. This
   is `MAC_APP_STORE.md` checklist step 6, still open. The cause is now
   proven rather than guessed — see § 1.
2. **The Settings sheet is 547 × 2972 points and does not scroll.** On the
   2160-point screen this Mac has, its **Done button is at y = 3005 — off the
   bottom of the display**, and so are Pawmodoro Plus, Redeem a code, Leave a
   tip and Restart cycle. On a MacBook Air's ~900 points, everything below
   "Durations" is unreachable. The Magpie's Cart has the same shape
   (470 × 2307, Done at y = 2344).

A reviewer on a laptop opens Settings, finds it cut off with no scroll bar and
no visible way out, and files that as a bug. Fix 1 and 2 before submitting.
Everything else on this list is polish.

---

## What was driven, and how

| | |
|---|---|
| Build | `xcodebuild -configuration Release … -destination 'platform=macOS'` → **BUILD SUCCEEDED**; a Debug build for the launch flags (they are `#if DEBUG`) |
| Host | macOS 15.7.3, Xcode 26.3, screen 7680 × 2160 points |
| Driving | Accessibility API (`AXPress`, `AXScrollToVisible`, window `AXSize`/`AXPosition`) and key events posted to the app's own pid with `CGEvent.postToPid`. **No mouse was used** — nothing was clicked at a screen coordinate, and no keystroke was ever sent to the frontmost app |
| Flags | `-PawmodoroSkipOnboarding -PawmodoroSuppressNotificationPrompt -PawmodoroUnlockPlus -PawmodoroSeedStats -PawmodoroBond 200 -PawmodoroFillJournal -PawmodoroSeedChronicle -PawmodoroUnlockPlaces -PawmodoroUnlockMusic -PawmodoroUnlockSounds -PawmodoroFillDreams -PawmodoroPostcard -PawmodoroKeepsakes 6 -PawmodoroBloom -PawmodoroFillDrawer -PawmodoroSeedScrapbook -PawmodoroClock 10 -PawmodoroFastTimers` |
| Screens | main (idle / focus / break), Stats, Sound Studio, Settings, the buddy book, the Magpie's Cart, the tip jar, the paywall, the Scrapbook, the haiku bench, the main menu bar and every menu in it, the menu bar extra's menu, the toolbar overflow, window resize to both limits, zoom, full screen, ⌘W / ⌘N / ⌘0 / ⌘Return / ⌘→ / ⌘K / Escape |

Two mechanical notes for whoever repeats this. The Debug build is the one that
takes launch flags. And a second workflow was driving a `Pawmodoro`-named
process on this Mac at the same time; System Events resolves `process
"Pawmodoro"` to whichever it finds first, so the two passes kept closing each
other's windows. The fix was to copy the bundle, rename it `PawWalk`, give it
its own bundle id and re-sign it ad-hoc — after which the walk was stable. If
you ever run two Mac passes at once, do that first.

---

## Findings, worst first

### 1. The menu bar extra is 418 × 402 points — and here is why

Measured through the accessibility API on the shipping code:

```
AXMenuBar   (6607,-189 418x402)
  AXMenuBarItem [AXMenuExtra] | Title = Pawmodoro. Mochi is waiting.
```

418 points wide, 402 tall, starting 189 points *above* the top of a 24-point
menu bar. What you see is a hugely magnified horizontal slice of the cat's
face smeared across a sixth of the menu bar.

`MenuBarBuddy` asks for `BuddySprite(… size: 16 …)`, so this looks impossible.
It is not. **A `MenuBarExtra` label sizes the status item from the
`NSImage`'s intrinsic size, not from the SwiftUI `.frame`.** The sprites are
400 × 400 PNGs and their `Contents.json` declares no `scale`, so
`NSImage(named:)` hands back an image whose `size` is 400 × 400 points —
and 400 + a little chrome is 418 × 402.

Proven in a clean-room app rather than argued. Two `MenuBarExtra` scenes, same
PNG:

| Label | Status item width |
|---|---|
| A — `Image(nsImage:).resizable().scaledToFit().frame(width: 16, height: 16)`, i.e. exactly what `BuddySprite` does today | **416 pt** |
| B — the same `NSImage` redrawn into a 16 × 16 `NSImage` first, then handed to `Image` | **32 pt** |

So the fix is one function: give the menu bar label an `NSImage` that is
already 16 × 16 (draw it into a small `NSImage`, or set `.size` on a copy).
Do not chase it with more SwiftUI modifiers — variant A already has the right
frame and it changes nothing.

This is the feature the Mac build is *for*. It cannot ship like this, and it
must be fixed before the store screenshots are re-shot (`MAC_APP_STORE.md`
checklist 18 already says so).

### 2. Settings is 2972 points tall, does not scroll, and its bottom third cannot be reached

The sheet is **547 × 2972**. Measured positions of things inside it, on a
screen 2160 points tall:

| Row | y | On screen? |
|---|---|---|
| See what's included (Pawmodoro Plus) | 2772 | **no** |
| Redeem a code | 2800 | **no** |
| Leave a tip | 2828 | **no** |
| Restart cycle | 2856 | **no** |
| **Done** | 3005 | **no** |

There is no vertical scroll area in the sheet — the only `AXScrollArea`s
inside it are the little horizontal buddy/wardrobe/place rows. The sheet
simply grows to fit a `Form` that is taller than any Mac display. Escape does
dismiss it, but nothing on screen says so.

On this 2160-point monitor that costs you the Plus block and the tip jar. On a
13-inch MacBook (~900 points of usable height) it costs you everything below
the Durations steppers: ambience, themes, the cabinet of clocks, every
Behaviour toggle, Plus, the cart, the tip jar and Done.

Two mitigations exist and are worth knowing before this gets over-fixed: Plus
is still reachable by tapping any padlock in the pickers near the top, and the
tip jar has its own row high up in Stats. So the *paywall* is not sealed off —
but a reviewer who goes looking in Settings will conclude it is.

**The Magpie's Cart is the same bug**: 470 × 2307, Done at y = 2344, also off
the bottom of this screen.

### 3. Settings also overflows sideways

At every window width the `Form` lays out wider than the sheet:

- "Long break every 4 sessions" renders as "**g break every 4 sessions**" —
  the label is clipped off the *left* edge.
- Every section footer is truncated at the right edge mid-word: "Ambient sound
  plays while the timer is running, and pauses when th…", "An off-duty buddy
  comes back when it comes back — with a letter, something for the drawer.
  Picking a traveler for duty calls them stra…", "…and is never mentioned",
  "Pawmodoro Plus / Unlocked … Thank yo…".
- The buddy Name `TextField` runs past the right edge of the sheet.
- "The buddy book" and "The magpie's cart" are full-width bordered buttons
  whose right ends are cut off.
- Section headers butt straight into the preceding footer with no gap
  ("Places you reach stay yours." / "Durations").

None of this is visible on iOS, where the Form is the width of the phone.

### 4. The gear is behind a `»` at the default window width

At the shipping default of 400 points the toolbar cannot fit its five idle
items, so **Settings and the haiku bench go into the overflow chevron**. This
is not merely visual: with the window at 400, a search of the whole
accessibility tree for "Settings" **finds nothing** — the control does not
exist until the chevron is opened, so VoiceOver and keyboard navigation cannot
reach it either. Widen the window to 520 and both reappear.

It only bites while the timer is idle — which is the state a first-run user is
in. During focus the camera and the bench drop out of the toolbar and the gear
comes back on its own.

Cheapest fixes: raise the default width, or move one of the three leading
glyphs somewhere else.

### 5. The Sound Studio sheet has no Done button

`SoundStudioView` puts its Done at `ToolbarItem(placement: .topBarTrailing)`.
`Platform.swift`'s own table — written after the Scrapbook lost its import
control the same way — says `.primaryAction` renders **nothing** in a macOS
sheet. It is the only view in the app still doing this; every other sheet uses
`.confirmationAction` or `.cancellationAction` and gets a proper Done.

Confirmed on screen and in the tree: the sheet contains a title and a scroll
area and no button of any kind. Escape works; nothing tells you that.

### 6. Controls that quietly disappear because they are `.topBarLeading`

Same trap, other direction. Verified absent from the running sheets:

| Control | Sheet | Consequence on macOS |
|---|---|---|
| **Clear** (session history) | Stats | You cannot clear your history at all |
| **the acorn pouch count** | Magpie's Cart | You shop without seeing your balance |
| **Remove** | a Scrapbook photo | Read from the source, not driven: a photo can be imported and never deleted |

The Scrapbook's own import control **is** fixed — the "+ Keep one" tile is in
the sheet's content and renders correctly on the Mac. That fix just needs
applying to the four controls above.

### 7. The green Zoom button makes a 520 × 2135 sliver, and the View menu is dead

Pressing Zoom gives a window 520 wide and 2135 tall: a thin column with the
countdown at the top, the ground at the bottom and roughly 900 points of
empty sky in between. It looks like a mistake.

`View ▸ Enter Full Screen` is **disabled**, and so are `Show Tab Bar` and
`Show All Tabs` — every item in the View menu is greyed out. That is the exact
situation the Help menu was deliberately emptied to avoid ("a menu item whose
only behaviour is an apology is worse than no menu item"). The same argument
applies here: either let the window fill a screen properly or remove the menu.

### 8. Touch words in copy a Mac user will read

| String | Where |
|---|---|
| "Tap to skip" | the Settle-in breathing screen |
| "…countdown starts. Tap anywhere to skip it." | Settings footer |
| "Fifty lo-fi tracks the moment you tap…" | **the paywall** |
| "tap to plant" / "tap to pick" / "Empty pocket. Tap to plant the offered seed." | the dream garden, in Stats |
| "there's an acorn on the sill — slide it over" | the main screen, every session |

"drag the ring to set your focus" and "Press and hold to cast off" are fine —
a pointer drags and holds. "Tap" is the one that has no Mac meaning, and it is
in the purchase screen.

### 9. Nothing answers the pointer

- `.onHover` appears **zero** times in the app. No control lights up under the
  cursor.
- `.help()` appears **zero** times. The toolbar is four unlabelled glyphs with
  no tooltips; the accessibility descriptions are good, but a tooltip is what
  a Mac user gets.
- `.contextMenu` appears **once** in the whole app (AlbumView). Right-clicking
  a buddy, a place, a track, a postcard or a keepsake does nothing.
- The long sheets do not scroll from the keyboard. Page Down inside Stats
  moves the focus ring to Done and leaves the content where it was.

None of this fails review. All of it is what "a phone app in a window" means
in practice.

### 10. Small and already known

- `NSSupportsLiveActivities = 1` is still in the built Mac `Info.plist` — a
  claim that is not true on this platform.
- `NSHumanReadableCopyright` is still unset; the About box will have no
  copyright line.
- No `Settings` scene, so **⌘,** does nothing. Every Mac user tries it first.
- The bare Space binding is confirmed to live only in the status menu:
  `Start` there carries `AXMenuItemCmdChar = space, AXMenuItemCmdModifiers =
  8` (no Command), while the main menu's `Session ▸ Start` is ⌘Return. That
  matches what `PawmodoroApp` claims, so it is not a bug — just verified.

---

## What is right, and worth not breaking

- **The icon shipped and it is the correct shape.** `CFBundleIconName =
  AppIcon` is in the built Mac `Info.plist`, `Assets.car` carries 11 AppIcon
  renditions from 16 pt to 1024 px, and the artwork is an 824 × 824 opaque
  body inset 100 points on a transparent 1024 canvas with its own shadow —
  exactly Apple's macOS icon grid. Checklist step 5 is closed.
- **Escape dismisses every sheet** I opened (Stats, Settings, Sound Studio,
  buddy book, cart, tip jar, paywall, Scrapbook, haiku bench).
- **⌘W closes the window and the session keeps running** in the menu bar, with
  the status item still counting down. That is the Mac's whole pitch and it
  works. ⌘N brings a window back; ⌘0 does not, because a `MenuBarExtra`
  menu's key equivalents are live only while that menu is open.
- **⌘Return start/pause, ⌘→ skip, ⌘K shake** are all present and correct, and
  the main menu carries no bare Space.
- **The Help menu holds only macOS's own search row** — the deliberate
  `CommandGroup(replacing: .help) { }` does what it says.
- **The window's resize clamps are real**: dragging to 2000 × 2000 gives
  520 × 1523, dragging to 100 × 100 gives 360 × 912. Width is bounded 360–520,
  height has a floor of 912 (860 of content plus the 52-point title bar) and
  no ceiling, exactly as `Platform.swift` documents.
- **The art holds up.** The scene layers, the drifting clouds, the near-plane
  grass and its fence rail, the sun, the house, the buddy's nap pose, the
  paw-print confetti on the break — all render crisply at 400 and at 520
  points, in a window, with no scaling artefacts. The scenery is the reason to
  ship this at all and it survived the port.
- **A focus → break cycle ran end to end** from ⌘Return, the phase advanced on
  its own, the celebration fired and the break screen came up with the timer
  correctly paused (auto-start is off by default).
- **The Scrapbook's Mac import control is there** — the "+ Keep one" tile in
  the sheet content, as designed.

**Size, said out loud as the rule requires.** The Release universal `.app` is
**53.46 MB** — 21.02 MB of universal binary (roughly half of that after
thinning), 26.95 MB across 169 `.m4a` files, 1.91 MB of `Assets.car`. That is
up from the 40 MB recorded in `MAC_APP_STORE.md` on 9 Aug; the five extra app
icons, the re-voiced ambience and the new scene layers are the difference.

---

## Not checked, and why

| | |
|---|---|
| **Dark mode and the eight themes** | The only way to flip a Mac's appearance is system-wide, and the owner was using this computer. `check_contrast.py` covers the palettes; the *layout* in dark mode is still unseen |
| **Anything by ear** | Unchanged: `MAC_APP_STORE.md` checklist 9 is still the owner's evening, and it is still the one that has failed on real hardware before |
| **The Photos import panel** | Reaching it opens the owner's photo library. The control renders; the round trip was already verified on 9 Aug |
| **StoreKit** | Needs a Sandbox Apple Account password. Checklist 19, still the owner's |
| **A small screen** | Everything above was measured on a 2160-point display. A 900-point laptop is where findings 2 and 3 get worse, and nobody has run it there |
| **Right-click in AlbumView** | The app's one `.contextMenu`; not driven |

## Housekeeping

- The walk used a renamed, ad-hoc-signed copy of the Debug build
  (`PawWalk`, bundle id `com.pawmodoro.walk`) so it could not be confused with
  the other workflow's process. Its sandbox container
  `~/Library/Containers/com.pawmodoro.walk` survives; it belongs to a bundle
  id that does not exist and can be deleted from Finder.
- Early runs launched the real `com.pawmodoro.zhangcheng` bundle with the
  seeding flags above, so that container's `UserDefaults` now hold seeded
  history. A copy taken before the walk is in this session's scratchpad if it
  is ever wanted; it was deliberately **not** restored, because another
  workflow was writing to the same container at the time.
