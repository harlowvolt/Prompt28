import Foundation

/// Keychain-backed client-side usage tracker for the freemium tier.
///
/// Stores a monthly generation count and the period-start timestamp in Keychain
/// so the data survives app reinstalls. The store is transparent to the caller:
/// reading `count` or `canGenerate` automatically performs a monthly roll-over
/// check and resets as needed.
///
/// The server remains the authoritative source of truth. `sync(promptsRemaining:plan:)`
/// realigns the local counter with the value returned by each API response, preventing
/// drift between client and backend.
final class UsageTracker {

    // MARK: - Constants

    /// Maximum free-tier generations per calendar month.
    static let freeMonthlyLimit = 10

    // MARK: - Keychain keys

    private static let countKey     = "usage.monthly.count"
    private static let periodKey    = "usage.monthly.period"    // ISO8601 date of month start

    // MARK: - Dependencies

    private let keychain: KeychainService
    private let calendar = Calendar.current

    // MARK: - Init

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Current number of generations used in the rolling calendar month.
    var count: Int {
        rolloverIfNeeded()
        return storedCount
    }

    /// Guest-mode usage mirrors the local freemium counter until the user signs in.
    var guestCount: Int {
        count
    }

    /// `true` when the user may generate without hitting the free-tier wall.
    /// Always `true` for paid plans — pass a non-starter plan to bypass the gate.
    func canGenerate(for plan: PlanType) -> Bool {
        guard plan == .starter else { return true }
        return count < Self.freeMonthlyLimit
    }

    /// Increments the local counter by one. Call after a successful generation.
    func recordGeneration() {
        rolloverIfNeeded()
        try? keychain.set("\(storedCount + 1)", for: Self.countKey)
    }

    /// Realigns the local counter with the server's authoritative `prompts_remaining`
    /// value returned in the generate response. Skips adjustment for paid plans.
    func sync(promptsRemaining: Int?, plan: PlanType) {
        guard plan == .starter, let remaining = promptsRemaining else { return }
        let serverUsed = max(0, Self.freeMonthlyLimit - remaining)
        let localUsed  = storedCount
        // Only advance the counter — never roll it backwards (avoids cheating).
        if serverUsed > localUsed {
            try? keychain.set("\(serverUsed)", for: Self.countKey)
        }
    }

    /// Hard-resets the counter to zero and starts a fresh period. Use for testing
    /// or after a plan upgrade that grants a new monthly allocation.
    func reset() {
        try? keychain.set("0", for: Self.countKey)
        try? keychain.set(iso(from: Date()), for: Self.periodKey)
    }

    // MARK: - Private helpers

    private var storedCount: Int {
        Int(keychain.get(Self.countKey) ?? "0") ?? 0
    }

    /// Checks whether the stored period has rolled over into a new calendar month;
    /// if so, resets the counter and stamps the new period start.
    private func rolloverIfNeeded() {
        let now = Date()
        let nowMonth = calendar.dateComponents([.year, .month], from: now)

        if let raw = keychain.get(Self.periodKey),
           let periodStart = date(from: raw) {
            let startMonth = calendar.dateComponents([.year, .month], from: periodStart)
            if startMonth.year == nowMonth.year && startMonth.month == nowMonth.month {
                return  // Still in the same calendar month; nothing to do.
            }
        }

        // New month (or no stored period) — reset.
        try? keychain.set("0", for: Self.countKey)
        try? keychain.set(iso(from: now), for: Self.periodKey)
    }

    private func iso(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func date(from string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
}
