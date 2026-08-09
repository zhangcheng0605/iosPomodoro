#if DEBUG

import CryptoKit
import Foundation

// MARK: - This whole file is Debug-only, and that is the point
//
// Every type below — `PromoCode`, `PromoCodes`, `PromoLedger` — is compiled
// out of Release entirely. Not hidden, not gated behind a flag: **absent**.
// `strings` over a Release binary turns up no digest, no salt, no round
// count and no ledger.
//
// The reason is App Review guideline 3.1.1, which names this exact mechanism
// ("apps may not use their own mechanisms to unlock content or
// functionality, such as license keys…"), and Apple's rejection letter for it
// leads with promo codes. Merely *hiding* the field would trade a 3.1.1
// problem for a 2.3.1 "hidden, dormant, or undocumented features" one, whose
// remedy reaches removal from the developer program. So the code is not in
// the shipped binary to be found.
//
// It stays in Debug because it is the only way the owner reaches his own paid
// content on his own device: StoreKit vends nothing to an app installed
// outside Xcode, so without this there is no way to test what he built.
//
// `tools/check_swift.py`'s `check_debug_only_symbols` is what holds the line.
// A file whose first line is `#if DEBUG` has no Release stand-in by design,
// so the checker fails on any *unfenced* mention of a name declared here. Add
// a reference from ordinary code and the checker says so before Xcode does.
//
// ## What a Debug redemption leaves behind, and why Release doesn't trip
//
// Redeeming writes two things: the ledger under `StorageKeys.promo`, and
// `true` under `StorageKeys.hasPlus` (see `StoreManager.updateHasPlus`).
// Running a Release build on the same device afterwards:
//
// - **`pawmodoro.promo`** is an orphan. Nothing in a Release binary knows the
//   type that wrote it, so nothing decodes it and nothing can fail on it. The
//   key stays in `StorageKeys.all` so `-PawmodoroResetState` still clears it
//   in Debug, and so a future author can see the name is taken.
// - **`pawmodoro.hasPlus`** is read at launch as the entitlement cache it has
//   always been, and then corrected by `refreshEntitlements()` the way a
//   revoked purchase would be — `updateHasPlus` no longer folds a ledger in,
//   so it passes StoreKit's answer straight through and a self-issued grant
//   evaporates on the first launch of a Release build. That is the *correct*
//   outcome, and it is not a decay: nothing a user paid for is touched, only
//   something the developer gave himself in a build nobody else has.
//
// The sanctioned replacement, when a real code is ever wanted, is StoreKit
// Offer Codes — extended to non-consumables at iOS 16.3, and this app targets
// 17. See docs/PROMO_CODES.md.

/// A code somebody can type in to be let in.
///
/// There is one of these today and the shape is built for more: a code is a
/// row in `PromoCodes.all`, not a comparison written into a view, so a second
/// one is a line rather than a redesign.
///
/// ## What is and isn't secret here
///
/// The literal code is **not** in the binary. What ships is the salted,
/// stretched hash of it (see `digest(of:)`), so running `strings` over the
/// `.ipa` turns up sixty-four hex characters and no way to read them
/// backwards. That is the whole of the claim, and it is worth being plain
/// about the rest: somebody with the binary can extract the salt and the
/// round count and then guess codes offline. Stretching makes each guess cost
/// about a hundredth of a second rather than a microsecond, which turns a
/// full sweep of every six-character code from an afternoon into centuries —
/// but a *short word somebody might guess* is still a short word somebody
/// might guess. A promo code is a speed bump. Anything that has to actually
/// be secret belongs behind a receipt, not behind this.
struct PromoCode: Identifiable, Sendable, Equatable {

    /// A stable, readable id. This — never the code itself — is what gets
    /// written down when somebody redeems, so the plaintext never lands in
    /// `UserDefaults` where a backup could carry it off the device.
    let id: String

    /// The salted, stretched hash of the code, lowercase hex.
    let digest: String

    /// Whether redeeming this one opens Pawmodoro Plus.
    ///
    /// A field rather than an assumption, so a later code that grants
    /// something smaller doesn't have to fight the one that grants
    /// everything.
    let grantsPlus: Bool

    /// One calm line shown after a successful redemption. In the app's voice,
    /// and it does not congratulate anybody for typing.
    let welcome: String
}

/// The table, and the arithmetic that reads it.
enum PromoCodes {

    /// Every code the app knows. One for now.
    ///
    /// A digest for a new row is the recipe in `digest(of:)`, which is short
    /// enough to reproduce anywhere: SHA-256 of `salt + ":" + code`, then
    /// `rounds - 1` further passes of SHA-256 over `salt + ":" + previous`.
    static let all: [PromoCode] = [
        PromoCode(
            id: "keeper",
            digest: "e3208583480343c00327fb89734fdbb485222137099ae4b371d2c5382891974a",
            grantsPlus: true,
            welcome: "The door is open. Every buddy, every place, every track — "
                   + "yours from here on."
        ),
    ]

    /// The row with this id, if the app still knows it.
    ///
    /// Deliberately allowed to return nil: a redeemed entitlement outlives its
    /// row in this table, which is why `PromoLedger` keeps its own record of
    /// what was granted rather than re-deriving it from here. Nothing decays,
    /// including because a code was retired.
    static func code(id: String) -> PromoCode? {
        all.first { $0.id == id }
    }

    // MARK: Matching

    /// What the app actually hashes.
    ///
    /// Case-insensitive and whitespace-insensitive: `"  Zac888 "` and
    /// `"zac 888"` both come out as `"zac888"`. Somebody reading a code off a
    /// piece of paper, or pasting one out of a message with a stray space
    /// on the end, should not be told they got it wrong.
    static func normalize(_ typed: String) -> String {
        typed.lowercased().filter { !$0.isWhitespace }
    }

    /// How many times the hash is folded back over itself.
    ///
    /// The point is cost, not secrecy: one check is a few milliseconds on a
    /// phone and nobody notices, while a machine grinding through guesses pays
    /// it for every one. Changing this number invalidates every digest in the
    /// table above.
    static let rounds = 40_000

    /// Salted so that the digest of a code here can't be looked up in a
    /// rainbow table of common words. Stored split from the codes themselves
    /// for no reason other than tidiness — this is not a key and is not
    /// treated like one.
    private static let salt = Data("pawmodoro.promo.v1".utf8)

    /// The salted, stretched hash of an already-normalized code.
    static func digest(of normalized: String) -> String {
        var block = Data(SHA256.hash(data: seasoned(Data(normalized.utf8))))
        for _ in 1..<rounds {
            block = Data(SHA256.hash(data: seasoned(block)))
        }
        return block.map { String(format: "%02x", $0) }.joined()
    }

    private static func seasoned(_ payload: Data) -> Data {
        var data = salt
        data.append(0x3A)  // ':'
        data.append(payload)
        return data
    }

    /// The code somebody typed, if it is one of ours.
    ///
    /// An empty field matches nothing — without this an empty string would be
    /// hashed and compared like any other, which is fine, but the view would
    /// rather not have to think about it.
    static func match(_ typed: String) -> PromoCode? {
        let normalized = normalize(typed)
        guard !normalized.isEmpty else { return nil }
        let hashed = digest(of: normalized)
        return all.first { $0.digest == hashed }
    }
}

/// What has been redeemed on this device, and what it granted.
///
/// Two fields rather than one on purpose. The ids are a record of *what
/// happened*; `plus` is the entitlement itself, kept separately so that the
/// grant survives its code being retired from `PromoCodes.all`, a future
/// version renaming a row, or the table being rebuilt entirely. A redeemed
/// entitlement is kept forever — that is the house rule, and re-deriving it
/// from a mutable table every launch would be one refactor away from
/// breaking it.
///
/// Monotonic by construction: `record` only inserts and only ever turns `plus`
/// on, so `merge` is `union` and `||`, and merging is both commutative and
/// idempotent without anybody having to think about it.
struct PromoLedger: Codable, Equatable, Sendable {

    /// The ids of every code ever redeemed here.
    private(set) var codeIDs: Set<String> = []

    /// Whether any of them opened Plus. Never set back to false.
    private(set) var plus: Bool = false

    var isEmpty: Bool { codeIDs.isEmpty && !plus }

    mutating func record(_ code: PromoCode) {
        codeIDs.insert(code.id)
        if code.grantsPlus { plus = true }
    }

    func has(_ code: PromoCode) -> Bool { codeIDs.contains(code.id) }

    static func merge(_ a: PromoLedger, _ b: PromoLedger) -> PromoLedger {
        PromoLedger(codeIDs: a.codeIDs.union(b.codeIDs), plus: a.plus || b.plus)
    }

    // MARK: Storage

    static func load(from defaults: UserDefaults) -> PromoLedger {
        guard let data = defaults.data(forKey: StorageKeys.promo),
              let decoded = try? JSONDecoder().decode(PromoLedger.self, from: data)
        else { return PromoLedger() }
        return decoded
    }

    /// Writes, merged with whatever is already stored, so a save can only ever
    /// add. There is no path in the app that removes a redemption, and this is
    /// the reason there can't be one by accident either.
    func save(to defaults: UserDefaults) {
        let merged = PromoLedger.merge(PromoLedger.load(from: defaults), self)
        guard let data = try? JSONEncoder().encode(merged) else { return }
        defaults.set(data, forKey: StorageKeys.promo)
    }

    /// Grants the first Plus-granting code without anybody typing, for
    /// `-PawmodoroRedeemed`. Lives here rather than in `LaunchOptions` so the
    /// stored shape has exactly one author.
    static func seedRedeemed(into defaults: UserDefaults) {
        guard let code = PromoCodes.all.first(where: \.grantsPlus) else { return }
        var ledger = load(from: defaults)
        ledger.record(code)
        ledger.save(to: defaults)
    }
}

#endif
