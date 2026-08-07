import Foundation
import Observation

/// How many high fives have ever landed at the bell.
///
/// One lifetime integer, and deliberately not a streak: the count only ever
/// rises, a missed five writes nothing anywhere, and the number is shown on
/// no screen. Its single job is the pre-empt — after enough landed fives the
/// buddy starts raising its paw a beat *before* the chime, because it has
/// learned you'll be there. Earned once, kept forever.
@Observable
final class FiveCounter {

    private(set) var lifetime: Int

    /// Landed fives before the buddy starts expecting you.
    static let preemptThreshold = 5

    /// Whether the paw now rises before the chime.
    var preempts: Bool { lifetime >= Self.preemptThreshold }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lifetime = defaults.integer(forKey: StorageKeys.fives)
    }

    func land() {
        lifetime += 1
        defaults.set(lifetime, forKey: StorageKeys.fives)
    }

    /// `-PawmodoroFives <n>` — preview the pre-empt without earning it.
    func seedForDebug(_ count: Int) {
        lifetime = count
        defaults.set(lifetime, forKey: StorageKeys.fives)
    }
}
