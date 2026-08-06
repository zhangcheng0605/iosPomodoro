import Observation

/// The one signal the snow globe listens for.
///
/// On iOS a shake reaches it through `ShakeDetector`; on macOS there is no
/// accelerometer and it comes from a menu item. Both call the same method
/// here, so the *feature* has one implementation and only the way of asking
/// for it differs by platform — which is the whole rule `Platform.swift`
/// states: no macOS variant of anything, only a macOS way in.
@Observable
final class SceneShake {
    static let shared = SceneShake()

    /// Bumped on every shake. Views watch it with `onChange` rather than
    /// reading a boolean they would then have to reset — a counter cannot get
    /// stuck in the "shaken" state if a view misses one.
    private(set) var count = 0

    private init() {}

    func shake() { count += 1 }
}
