# Pawmodoro 🐾 — Plan: Cozy Pomodoro App for iOS

A cutesy, cozy Pomodoro timer where a cat or dog buddy keeps you company.
Your buddy naps while you focus ("don't wake the kitty!") and plays during
breaks. Warm pastel palette, rounded shapes, soft animations — the vibe of
cozy pixel-art games.

## Concept

- **Name idea:** Pawmodoro (working title — check App Store for name conflicts before finalizing)
- **Hook:** Focus sessions earn paw prints; your buddy reacts to your progress
- **Audience:** Students, remote workers, cozy-game fans

## Phases

### Phase 1 — MVP (this repo, ~1 week of evenings)
- [x] Classic Pomodoro: 25 min focus / 5 min short break / 15 min long break (all adjustable)
- [x] Auto-cycling phases with session counter (long break every 4 focus sessions)
- [x] Cat or dog buddy with mood states (napping while you focus, playing on breaks)
- [x] Paw-print progress dots for completed sessions
- [x] Local notification when a timer ends (works even if app is backgrounded)
- [x] Haptic feedback on phase changes
- [x] Settings: durations, buddy choice, sessions per long break, haptics toggle
- [x] Timer survives backgrounding correctly (computes from end date, not ticks)

### Phase 2 — Polish (1–2 weeks)
- [ ] Replace emoji buddy with real art (commission pixel art or use procreate/aseprite;
      budget $100–400 on Fiverr/itch.io artists for a small sprite set)
- [ ] Ambient sounds (rain, café, purring) — royalty-free from freesound.org or similar
- [ ] Simple stats screen (sessions today / this week, streaks)
- [ ] App icon (1024×1024) — same artist as buddy sprites for consistency
- [ ] Onboarding screen (one page: pick your buddy, explain the loop)
- [ ] Nice-to-have: Live Activity on lock screen / Dynamic Island for the running timer

### Phase 3 — Launch (~1 week)
- [ ] Follow `docs/APP_STORE_LAUNCH_GUIDE.md` step by step
- [ ] TestFlight beta with a few friends first
- [ ] Screenshots (Xcode simulator + a mockup tool like AppMockUp or Screenshots.pro)
- [ ] Submit for review

### Phase 4 — Post-launch ideas
- [ ] More buddies (bunny, hamster) — possible in-app purchase
- [ ] Buddy "levels up" / unlocks accessories with completed sessions
- [ ] Widgets (today's paw prints on the home screen)
- [ ] Apple Watch companion

## Monetization (decide before Phase 3)
- **Free** — simplest first launch; build reviews and downloads
- **Free + one-time "tip jar" or cosmetic IAP** — good fit for cozy audience
- Avoid subscriptions for v1; not worth the extra review scrutiny and setup

## Tech decisions (already made in this scaffold)
- **SwiftUI**, iOS 17+, no third-party dependencies
- Emoji-based buddy art as placeholder so the app is fully functional before any art spend
- Timer stores an end `Date` and reschedules notifications — the only correct way on iOS,
  since apps get suspended in the background

## Rough total timeline
| Step | Time |
|---|---|
| MVP working on your phone | done + a weekend of tweaking |
| Art & polish | 1–2 weeks |
| Developer account approval | 1–2 days (have your ID ready) |
| App Store Connect setup + screenshots | 1–2 days |
| App review | 1–2 days (expect one rejection cycle as a first-timer; it's normal) |
| **Total to launch** | **~3–4 weeks, casual pace** |
