import Foundation
import Observation

/// The sky's answer to being touched.
///
/// Tapping a mode chip or an ambience icon sends a breath of wind through
/// whatever is up there at that hour: after dark the stars and the moon lean
/// and come back, and by day the sun does. It is one signal, watched by one
/// place, for the same reason `SceneShake` is one signal — the thing that
/// *causes* a stir (a chip, a star, a picker somewhere two sheets deep) has
/// no business knowing what the sky is currently made of.
///
/// **A counter, not a flag.** Same reasoning as `SceneShake.count`: a boolean
/// that a view has to reset can get stuck in the "stirring" state if a view
/// misses one, and the sky would then be leaning forever with nothing to
/// straighten it. A counter cannot be wrong — it can only be observed late.
///
/// Nothing here is persisted, and deliberately so. A stir lives for two and a
/// half seconds and means nothing afterwards; there is no `StorageKeys` entry
/// because there is no state to keep, and so nothing for `-PawmodoroResetState`
/// to reset.
@Observable
final class SkyStir {
    static let shared = SkyStir()

    /// Bumped on every stir. Views watch it with `onChange`.
    private(set) var count = 0

    private init() {}

    func stir() { count += 1 }

    // MARK: The rule about focus

    /// Whether the sky is allowed to answer at all right now.
    ///
    /// **It is not, while a focus phase is counting down.** The ambience row
    /// sits on the main screen and stays live through a session — it is the
    /// one control you are *meant* to reach for mid-focus, because changing
    /// what you are listening to is part of settling in. A sky that lurched
    /// every time somebody swapped rain for a creek would turn the app's
    /// quietest stretch into the one that keeps tugging at the eye, which is
    /// the exact thing the inert-scene rule exists to prevent. The mode chips
    /// are already idle-only (`expeditionRow` is mounted on `runState ==
    /// .idle`), so this gate is really about the ambience row.
    ///
    /// The stir is therefore a *break and idle* pleasure, which is also when
    /// somebody is actually looking at the screen rather than at their work.
    ///
    /// This is the same expression `photoControl` and `skyTouch` already use
    /// to decide they are out of hours — written once here so the three
    /// cannot drift apart, and so flipping the decision is one line rather
    /// than a search.
    static func allowed(isRunning: Bool, isBreak: Bool) -> Bool {
        !(isRunning && !isBreak)
    }

    // MARK: The shape of the movement

    /// How long the lean takes to reach its furthest point, and how long it
    /// then takes to come back.
    ///
    /// Deliberately lopsided — out in under half a second, back over two.
    /// A symmetric there-and-back reads as a bounce, and a bounce on a focus
    /// timer is a toy. Out quickly and back slowly reads as something heavy
    /// being nudged, which is what a sky is.
    ///
    /// There is no overshoot and no spring: the lean approaches zero from one
    /// side and stops. Nothing crosses back through centre, so the sky never
    /// wobbles.
    static let out: TimeInterval = 0.45
    static let back: TimeInterval = 2.1

    /// The whole movement, for anything that needs to know when the sky is
    /// still again.
    static var settle: TimeInterval { out + back }

    /// How far the sky leans, in degrees, about a pivot far below the screen.
    ///
    /// Small on purpose. Rotating about a point roughly two and a half
    /// screens down turns this into a near-horizontal slide of seven or eight
    /// points at the top of the sky band, tapering slightly toward the
    /// horizon — which is the parallax a real sky has, and the reason this is
    /// a rotation rather than an offset. An offset moves every star by the
    /// same amount and reads as the *image* sliding; a rotation about a
    /// distant pivot moves the high ones further than the low ones and reads
    /// as depth.
    static let leanDegrees = 0.26

    /// How much of the stars' lean the sun and moon take.
    ///
    /// Less than all of it, so the big warm thing in the corner trails the
    /// small cold ones. That lag is the whole character of the movement: a
    /// sky where everything moves by the same fraction at the same moment is
    /// a texture being dragged, and a sky where the little things go first is
    /// weather.
    static let heavyLean = 0.62
}
