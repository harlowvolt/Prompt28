import Foundation
import UIKit
@preconcurrency import Supabase

// MARK: - Events

enum AnalyticsEvent {
    case appOpen
    case generateTapped(mode: String)
    case generateSuccess(mode: String, wordCount: Int, intentCategory: String? = nil, latencyMs: Int? = nil)
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
    case promptFeedback(thumbsUp: Bool, historyItemID: String)

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
        case .promptFeedback:        return "prompt_feedback"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .generateTapped(let mode):
            return ["mode": mode]
        case .generateSuccess(let mode, let wordCount, let intentCategory, let latencyMs):
            var props: [String: Any] = ["mode": mode, "word_count": wordCount]
            if let intent = intentCategory { props["intent_category"] = intent }
            if let latency = latencyMs     { props["latency_ms"]       = latency }
            return props
        case .generateError(let msg):
            return ["error": msg]
        case .planUpgradeSuccess(let plan):
            return ["plan": plan]
        case .authSuccess(let provider):
            return ["provider": provider]
        case .modeSwitched(let to):
            return ["to": to]
        case .promptFeedback(let thumbsUp, let historyItemID):
            return ["thumbs_up": thumbsUp ? "true" : "false", "history_item_id": historyItemID]
        default:
            return [:]
        }
    }
}

// MARK: - Cached Event

/// Codable envelope stored in UserDefaults until drained to the Supabase `events` table.
struct CachedAnalyticsEvent: Codable, Identifiable {
    let id: UUID
    let name: String
    let properties: [String: String]   // stringified for Codable conformance
    let timestamp: Date
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case properties
        case timestamp
        case userId = "user_id"
    }

    init(event: AnalyticsEvent, userId: String?) {
        self.id = UUID()
        self.name = event.name
        self.properties = event.properties.reduce(into: [:]) { $0[$1.key] = "\($1.value)" }
        self.timestamp = Date()
        self.userId = userId
    }
}

// MARK: - Service

/// Analytics service.
///
/// Events are fired into a local UserDefaults cache (max 100, FIFO) and
/// batch-uploaded to the Supabase `events` table via `uploadToSupabase()`.
/// Upload is triggered automatically when the app enters background.
///
/// Call `configure(supabase:)` once from `AppEnvironment.init()`.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let userDefaults = UserDefaults.standard
    private let cacheKey = "orion.orb.analytics.cache"
    private let maxCacheSize = 100
    private var cachedEvents: [CachedAnalyticsEvent] = []
    private var userId: String?
    private var supabase: SupabaseClient?

    private init() {
        loadCachedEvents()
        setupBackgroundFlush()
    }

    // MARK: - Configuration

    /// Inject the live Supabase client. Call once from `AppEnvironment.init()`.
    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
    }

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

        let cached = CachedAnalyticsEvent(event: event, userId: userId)
        cachedEvents.append(cached)
        if cachedEvents.count > maxCacheSize {
            cachedEvents.removeFirst(cachedEvents.count - maxCacheSize)
        }
        persistCache()

        // ── Drop-in replacement examples ──────────────────────────────────
        // Mixpanel:
        //   Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
        // Amplitude:
        //   Amplitude.instance().logEvent(event.name, withEventProperties: event.properties)
        // Firebase:
        //   Analytics.logEvent(event.name, parameters: event.properties)
        // ─────────────────────────────────────────────────────────────────
    }

    // MARK: - Cache inspection

    func getPendingEvents() -> [CachedAnalyticsEvent] { cachedEvents }
    var pendingEventCount: Int { cachedEvents.count }

    func clearUploadedEvents(_ ids: [UUID]) {
        cachedEvents.removeAll { ids.contains($0.id) }
        persistCache()
    }

    func clearAllEvents() {
        cachedEvents.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }

    // MARK: - Private

    private func loadCachedEvents() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let events = try? JSONDecoder().decode([CachedAnalyticsEvent].self, from: data) else {
            cachedEvents = []
            return
        }
        cachedEvents = events
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(cachedEvents) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    private func setupBackgroundFlush() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.uploadToSupabase()
            }
        }
    }
}

// MARK: - Supabase Upload

extension AnalyticsService {
    /// Drains the local cache to the Supabase `events` table.
    /// Called automatically on app-background; also callable on demand.
    func uploadToSupabase() async {
        guard let supabase, !cachedEvents.isEmpty else { return }

        let pending = cachedEvents

        do {
            try await supabase
                .from("events")
                .insert(pending)
                .execute()

            let uploadedIDs = pending.map(\.id)
            clearUploadedEvents(uploadedIDs)

            #if DEBUG
            print("📊 [Analytics] Uploaded \(pending.count) events to Supabase")
            #endif
        } catch {
            #if DEBUG
            print("📊 [Analytics] Upload failed: \(error.localizedDescription)")
            #endif
        }
    }
}
