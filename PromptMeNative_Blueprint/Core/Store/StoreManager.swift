import StoreKit
import Foundation
@preconcurrency import Supabase

@Observable
@MainActor
final class StoreManager {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    var errorMessage: String?
    private(set) var isPurchasing = false

    // @ObservationIgnored opts this property out of the @Observable macro's tracking,
    // which allows nonisolated(unsafe) to apply so that deinit (which runs off the
    // main actor) can cancel the task without a compiler error.
    @ObservationIgnored
    nonisolated(unsafe) private var updateListenerTask: Task<Void, Error>?

    /// Injected so that a successful purchase immediately refreshes the
    /// server-side plan tier (fixes the post-purchase plan sync bug).
    private let authManager: AuthManager

    /// Injected to write `user_metadata.plan` immediately after a verified purchase,
    /// so the Edge Function's server-side metering bypass activates right away
    /// without requiring an App Store Server Notifications webhook.
    private let supabase: SupabaseClient?

    init(authManager: AuthManager, supabase: SupabaseClient? = nil) {
        self.authManager = authManager
        self.supabase = supabase
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            products = try await Product.products(for: StoreProductID.all)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        AnalyticsService.shared.track(.planUpgradeTapped)

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                // Push plan tier to Supabase user_metadata immediately so the
                // Edge Function metering bypass activates without waiting for
                // an App Store Server Notifications webhook.
                if let planTier = planType(for: transaction.productID) {
                    await syncPlanToSupabase(planTier)
                }
                // Best-effort Railway plan sync (silently fails — plan is read
                // from StoreKit receipts via activePlan in all user-facing gates).
                await authManager.refreshMe()
                AnalyticsService.shared.track(.planUpgradeSuccess(plan: product.id))
                return true
            case .pending:
                errorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// The highest plan tier unlocked by current verified StoreKit receipts.
    /// Reads directly from `purchasedProductIDs` — no server round-trip needed.
    /// Falls back to `.starter` when no active purchase is found.
    var activePlan: PlanType {
        if purchasedProductIDs.contains(StoreProductID.unlimitedMonthly) ||
           purchasedProductIDs.contains(StoreProductID.unlimitedYearly) {
            return .unlimited
        }
        if purchasedProductIDs.contains(StoreProductID.proMonthly) ||
           purchasedProductIDs.contains(StoreProductID.proYearly) {
            return .pro
        }
        return .starter
    }

    /// Returns the `PlanType` that corresponds to a given StoreKit product ID,
    /// so we can sync the backend after a successful purchase.
    func planType(for productID: String) -> PlanType? {
        switch productID {
        case StoreProductID.proMonthly, StoreProductID.proYearly:
            return .pro
        case StoreProductID.unlimitedMonthly, StoreProductID.unlimitedYearly:
            return .unlimited
        default:
            return nil
        }
    }

    /// Writes the purchased plan tier to `user_metadata.plan` in Supabase Auth,
    /// so the Edge Function's server-side metering bypass activates immediately.
    ///
    /// This is a best-effort write — failure is silent. The client-side
    /// `activePlan` property is always the authoritative gate for UI/generation;
    /// this call exists only to keep the Edge Function's server-side metering
    /// in sync without needing an App Store Server Notifications webhook.
    private func syncPlanToSupabase(_ plan: PlanType) async {
        guard let supabase else { return }
        do {
            try await supabase.auth.update(user: UserAttributes(data: ["plan": .string(plan.rawValue)]))
        } catch {
            TelemetryService.shared.logStorageError(
                code: "PLAN_METADATA_SYNC_FAILED",
                message: "Failed to write plan to Supabase user_metadata: \(error.localizedDescription)"
            )
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await MainActor.run { [self] in
                        _ = self.purchasedProductIDs.insert(transaction.productID)
                    }
                    await transaction.finish()
                    // Sync server plan tier for background transaction updates
                    // (renewals, cross-device restores, family sharing, etc.).
                    await self.authManager.refreshMe()
                } catch {}
            }
        }
    }

    // MARK: - Error

    enum StoreError: Error {
        case failedVerification
    }
}
