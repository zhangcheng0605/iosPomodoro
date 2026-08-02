import Foundation

/// Product identifiers, which must match App Store Connect exactly.
///
/// These are prefixed with the app's bundle identifier,
/// `com.zhangcheng.pawmodoro`. If that ever changes, change these to match and
/// create products with the same identifiers in App Store Connect. A mismatch
/// doesn't fail the build — the store simply returns no products and the paywall
/// shows its "unavailable" state, which is a confusing bug to chase.
///
/// See docs/MONETIZATION.md for the exact setup steps.
enum StoreIDs {
    /// Non-consumable: unlocks extra buddies, ambience and themes, forever.
    static let plus = "com.zhangcheng.pawmodoro.plus"

    /// Consumables: optional tips, which unlock nothing.
    static let tipSmall = "com.zhangcheng.pawmodoro.tip.small"
    static let tipMedium = "com.zhangcheng.pawmodoro.tip.medium"
    static let tipLarge = "com.zhangcheng.pawmodoro.tip.large"

    static let tips = [tipSmall, tipMedium, tipLarge]
    static let all = [plus] + tips
}
