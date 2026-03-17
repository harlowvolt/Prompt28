import Foundation

// MARK: - Events

enum AnalyticsEvent {
    case appOpen
    case generateTapped(mode: String)
    case generateSuccess(mode: String, wordCount: Int)
    case generateError(message: String)
    case generateRateLimited
    case copyPrompt
    case sharePrompt
    case favoriteTapped
    case refinePrompt
    case planUpgradeTapped
    case planUpgradeSuccess(plan: String)
    case authSuccess(provider: String)
    case paywallShown
    case onboardingCompleted
    case modeSwitched(to: String)

    var name: String {
        switch self {
        case .appOpen:               return "app_open"
        case .generateTapped:        return "generate_tapped"
        case .generateSuccess:       return "generate_success"
        case .generateError:         return "generate_error"
        case .generateRateLimited:   return "generate_rate_limited"
        case .copyPrompt:            return "copy_prompt"
        case .sharePrompt:           return "share_prompt"
        case .favoriteTapped:        return "favorite_tapped"
        case .refinePrompt:          return "refine_prompt"
        case .planUpgradeTapped:     return "plan_upgrade_tapped"
        case .planUpgradeSuccess:    return "plan_upgrade_success"
        case .authSuccess:           return "auth_success"
        case .paywallShown:          return "paywall_shown"
        case .onboardingCompleted:   return "onboarding_completed"
        case .modeSwitched:          return "mode_switched"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .generateTapped(let mode):
            return ["mode": mode]
        case .generateSuccess(let mode, let wordCount):
            return ["mode": mode, "word_count": wordCount]
        case .generateError(let msg):
            return ["error": msg]
        case .planUpgradeSuccess(let plan):
            return ["plan": plan]
        case .authSuccess(let provider):
            return ["provider": provider]
        case .modeSwitched(let to):
            return ["to": to]
        default:
            return [:]
        }
    }
}

// MARK: - Cached Event

/// Codable envelope stored in UserDefaults until the Supabase ingress
/// pipeline is wired in Phase 2.
struct CachedAnalyticsEvent: Codable {
    let name: String
    let properties: [String: String]   // stringified for Codable conformance
    let timestamp: Date
    let userId: String?
}

// MARK: - Service

/// Phase 1 analytics service.
///
/// Events are fired into a local UserDefaults cache (max 100) so that
/// nothing is lost before the Supabase `events` table is available.
/// Call `uploadToSupabase()` once SupabaseClient is configured (Phase 2)
/// to drain the queue.
///
/// Replace the `track` body with Mixpanel / Amplitude / Firebase when
/// ready — the callsites stay the same.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let cacheKey = "analytics_event_cache"
    private let maxCacheSize = 100
    private var userId: String?

    private init() {}

    // MARK: - User identity

    func setUserId(_ id: String?) {
        userId = id
    }

    // MARK: - Track

    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        let props = event.properties.isEmpty ? "" : " \(event.properties)"
        print("📊 [Analytics] \(event.name)\(props)")
        #endif

        // Cache locally for Supabase flush (Phase 2).
        let stringProps = event.properties.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = "\(pair.value)"
        }
        let cached = CachedAnalyticsEvent(
            name: event.name,
            properties: stringProps,
            timestamp: Date(),
            userId: userId
        )
        appendToCache(cached)

        // ── Drop-in replacement examples ──────────────────────────────────
        // Mixpanel:
        //   Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
        // Amplitude:
        //   Amplitude.instance().logEvent(event.name, withEventProperties: event.properties)
        // Firebase:
        //   Analytics.logEvent(event.name, parameters: event.properties)
        // ─────────────────────────────────────────────────────────────────
    }

    // MARK: - Cache management

    private func appendToCache(_ event: CachedAnalyticsEvent) {
        var cached = loadCache()
        cached.append(event)
        // FIFO: drop oldest events when limit is exceeded.
        if cached.count > maxCacheSize {
            cached = Array(cached.suffix(maxCacheSize))
        }
        saveCache(cached)
    }

    func loadCache() -> [CachedAnalyticsEvent] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let events = try? JSONDecoder().decode([CachedAnalyticsEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func saveCache(_ events: [CachedAnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: - Supabase upload (Phase 2 stub)

    /// Drains the local cache to the Supabase `events` table.
    /// Wire this up in Phase 2 once `SupabaseClient` is configured.
    func uploadToSupabase() async {
        let pending = loadCache()
        guard !pending.isEmpty else { return }

        // TODO (Phase 2): call SupabaseClient to batch-insert `pending`
        //   into the `events` table, then call clearCache() on success.
        //
        // Example:
        //   try await supabase.from("events").insert(pending).execute()
        //   clearCache()
    }
}
