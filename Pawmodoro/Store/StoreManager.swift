import Foundation
import Observation
import StoreKit

/// Owns everything to do with purchases: loading products, buying, restoring,
/// and deciding what the user is entitled to.
///
/// Note this file deliberately does not import SwiftUI — SwiftUI also defines a
/// `Transaction` type, which would make StoreKit's `Transaction` ambiguous here.
@MainActor
@Observable
final class StoreManager {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        /// The store couldn't be reached, or the products don't exist yet.
        case failed(String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var plusProduct: Product?
    private(set) var tipProducts: [Product] = []

    /// True once Pawmodoro Plus is owned.
    private(set) var hasPlus: Bool

    /// How many tips the user has left, purely so the app can say thank you.
    private(set) var tipsGiven: Int

    /// Set while a purchase sheet is up, so buttons can show a spinner.
    private(set) var purchasingProductID: String?

    /// Surfaced to the user when something goes wrong.
    var lastError: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private enum Keys {
        static let hasPlus = StorageKeys.hasPlus
        static let tipsGiven = StorageKeys.tipsGiven
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Read from the cache first so the UI doesn't flash "locked" during
        // launch; `refreshEntitlements()` corrects it a moment later.
        self.hasPlus = defaults.bool(forKey: Keys.hasPlus)
        self.tipsGiven = defaults.integer(forKey: Keys.tipsGiven)
        listenForTransactions()
    }

    // MARK: Loading

    func loadProducts() async {
        if case .loaded = loadState { return }
        loadState = .loading
        do {
            let products = try await Product.products(for: StoreIDs.all)
            plusProduct = products.first { $0.id == StoreIDs.plus }
            // Keep the tips in the order declared in StoreIDs, cheapest first,
            // rather than whatever order the store returns them in.
            tipProducts = StoreIDs.tips.compactMap { id in
                products.first { $0.id == id }
            }
            loadState = products.isEmpty
                ? .failed("No products are available yet.")
                : .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
        await refreshEntitlements()
    }

    /// Re-derives `hasPlus` from what StoreKit says the user owns.
    func refreshEntitlements() async {
        // Launched with -PawmodoroUnlockPlus, stand in for a purchase: a build
        // installed with `simctl` has no StoreKit configuration attached, so
        // there is otherwise no way to see the Plus content in a simulator.
        if LaunchOptions.unlockPlus {
            updateHasPlus(true)
            return
        }

        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == StoreIDs.plus, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        updateHasPlus(unlocked)
    }

    // MARK: Buying

    func purchase(_ product: Product) async {
        lastError = nil
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled:
                break
            case .pending:
                // Ask to Buy, or a payment awaiting approval.
                lastError = "Your purchase is waiting for approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Restores a previous purchase on a new device or after a reinstall.
    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
        if !hasPlus {
            lastError = "No previous purchase was found for this Apple Account."
        }
    }

    // MARK: Entitlements

    /// Still the single place that decides whether a thing is available, and
    /// now it knows about two roads to the same door.
    ///
    /// Plus first, because Plus is everything and always was. Then the
    /// pouch — but only for things the cart actually sells: `catalogItem` is
    /// nil for Soot and for anything else Plus gates but the cart will never
    /// stock, so those fall through to locked, which is the safe answer.
    func isUnlocked(_ item: PlusLockable) -> Bool {
        if hasPlus || !item.isPlus { return true }
        guard let entry = (item as? any Ownable)?.catalogItem else { return false }
        return pouch?.owns(entry) == true
    }

    /// Whether a catalogue item is available, by either road.
    ///
    /// The cart asks this rather than `isUnlocked(_:)` because it holds
    /// `CatalogItem`s rather than the underlying buddies and places, and
    /// because it wants the same answer for both roads: a thing you have is a
    /// thing you have, whether it came from the pouch or from Plus. The free
    /// pieces — the given accessories, the free film — are checked first,
    /// because a gift is not an entitlement and needs neither road.
    func isUnlocked(byPurchase item: CatalogItem) -> Bool {
        item.isFree || hasPlus || pouch?.owns(item) == true
    }

    /// The traded half of the entitlement. Set once, at app construction —
    /// held here rather than passed to every call site so that
    /// `isUnlocked(_:)` stays one function with one answer, which is the
    /// whole reason this file exists.
    ///
    /// Weak, because the pouch outlives nothing and this would otherwise be a
    /// retain cycle waiting for somebody to add a back-reference.
    @ObservationIgnored weak var pouch: Pouch?

    // MARK: Internals

    /// Catches purchases made on another device, Ask to Buy approvals, and
    /// refunds, which all arrive here rather than through `purchase()`.
    private func listenForTransactions() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }

        if transaction.productID == StoreIDs.plus {
            updateHasPlus(transaction.revocationDate == nil)
        } else if StoreIDs.tips.contains(transaction.productID) {
            tipsGiven += 1
            defaults.set(tipsGiven, forKey: Keys.tipsGiven)
        }

        // Always finish, or StoreKit will keep redelivering the transaction.
        await transaction.finish()
    }

    private func updateHasPlus(_ value: Bool) {
        guard hasPlus != value else { return }
        hasPlus = value
        defaults.set(value, forKey: Keys.hasPlus)
    }
}
