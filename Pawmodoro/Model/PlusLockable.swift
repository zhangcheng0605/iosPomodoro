import Foundation

/// Content that may require the Pawmodoro Plus unlock.
///
/// `StoreManager.isUnlocked(_:)` is the single place that decides whether a
/// given piece of content is available, so no view has to reason about
/// entitlements on its own.
protocol PlusLockable {
    var isPlus: Bool { get }
}
