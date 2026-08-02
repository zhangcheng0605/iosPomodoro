# Review findings — fix these first

An adversarial multi-agent review of the three delight commits
(`a5c9618..08b5965`) surfaced many candidate defects; most were refuted
against the actual code. These three survived with confirmed reproductions.
They are small. Fix them at the start of the next execution session (build
order item #1 in [CONTENT_PLAN.md](CONTENT_PLAN.md)).

## 1. Skipping a focus session still plays the reward animation

`BuddyView` triggers the `waking` celebration on *any* focus→break phase
change (`onChange(of: engine.phase)`), but `TimerEngine.skipPhase()` also
produces that transition. Skip an unfinished focus session and the buddy
stretches and bounces as if you'd earned it — a small leak in the
"no reward for abandoning" contract (confetti and the log correctly don't
fire; only the buddy's animation leaks).

**Fix:** drive the waking animation from `engine.completion` (published only
on natural completion) instead of from the phase transition.

## 2. VoiceOver can change the duration while the timer runs

`TimerRingView` gates the drag gesture and the knob on `isAdjustable`, but
`.accessibilityAdjustableAction` is attached unconditionally and `commit()`
does not re-check. A VoiceOver user can swipe-adjust the focus duration
mid-session; the countdown itself stays correct (end-date derived) but
`phaseDuration` changes under it, so the progress ring jumps.

**Fix:** guard the adjustable action (or `commit()`) on `isAdjustable`, and
have the action land a `nudge()` haptic when refused, matching the drag path.

## 3. The ring's arc snaps when a session starts

While idle, the arc shows *duration as a share of the settable range* (25 min
draws about a third of the ring). On start it switches to *progress*, which
begins near zero — so pressing play visibly snaps the arc from one-third to
empty. Verified on simulator from the shipping UI.

**Fix options** (pick one): animate the handoff (brief spring from
duration-arc to progress-arc), or render the idle duration as a distinct
affordance (e.g. only the knob position, no filled arc) so the two modes
don't share a visual channel.
