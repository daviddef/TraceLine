import StoreKit

/// StoreKit 2 shell, deliberately inactive for v1 — HANDOVER § Technology Stack:
/// "Implement IAP shell but don't activate for v1", and § What NOT to build:
/// "In-app purchases (stubs only)".
///
/// Every entry point is gated on `isEnabled`, so while it is false nothing here can
/// reach the network or start a purchase, and `isPurchased` always answers false.
/// That matters beyond tidiness: the App Store listing declares no in-app purchases.
///
/// Turning this on is not a one-line change. It needs, in order:
///   1. The products created in App Store Connect under the ids below.
///   2. A paid-apps agreement in place.
///   3. The listing's in-app-purchase declaration updated.
///   4. UI to actually present them — there is none today.
enum Store {

    /// The v1 kill switch. Leave false until the four steps above are done.
    static let isEnabled = false

    /// Ids are namespaced under the bundle id, matching what App Store Connect expects.
    enum ProductID: String, CaseIterable {
        case unlockAllThemes = "com.defranceski.traceline.themes.all"
        case unlockWorldTwo  = "com.defranceski.traceline.world2"
        case tipJar          = "com.defranceski.traceline.tip"
    }

    private(set) static var products: [Product] = []
    private static var updatesTask: Task<Void, Never>?

    /// Call once at launch. No-ops entirely while disabled.
    static func start() {
        guard isEnabled else { return }
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
    }

    static func loadProducts() async {
        guard isEnabled else { return }
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
        } catch {
            print("[Store] product load failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func purchase(_ id: ProductID) async -> Bool {
        guard isEnabled, let product = products.first(where: { $0.id == id.rawValue }) else {
            return false
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard let transaction = try? verification.payloadValue else { return false }
                apply(transaction)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[Store] purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    static func restore() async {
        guard isEnabled else { return }
        try? await AppStore.sync()
    }

    static func isPurchased(_ id: ProductID) -> Bool {
        guard isEnabled else { return false }
        return PlayerProgress.shared.isEntitled(id.rawValue)
    }

    private static func apply(_ transaction: Transaction) {
        guard transaction.revocationDate == nil else {
            PlayerProgress.shared.setEntitled(transaction.productID, false)
            return
        }
        PlayerProgress.shared.setEntitled(transaction.productID, true)
    }

    /// Purchases can also arrive from outside the app (Ask to Buy, another device),
    /// so a live store has to keep listening rather than only react to its own flow.
    private static func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                guard let transaction = try? update.payloadValue else { continue }
                apply(transaction)
                await transaction.finish()
            }
        }
    }
}
