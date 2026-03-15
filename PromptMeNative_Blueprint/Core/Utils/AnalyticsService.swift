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

struct CachedAnalyticsEvent: Codable {
    let id: UUID
    let name: String
    let properties: Data
    let timestamp: Date
    let userId: String?
    
    init(event: AnalyticsEvent, userId: String?) {
        self.id = UUID()
        self.name = event.name
        self.properties = try! JSONSerialization.data(withJSONObject: event.properties)
        self.timestamp = Date()
        self.userId = userId
    }
}

// MARK: - Service

/// Analytics service with local caching for batch upload to Supabase.
/// 
/// Phase 1: Local caching implemented, ready for Supabase integration in Phase 2.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "orion.orb.analytics.cache"
    private let maxCacheSize = 100
    private var cachedEvents: [CachedAnalyticsEvent] = []
    private var userId: String?
    
    private init() {
        loadCachedEvents()
    }
    
    /// Set the current user ID for attribution
    func setUserId(_ id: String?) {
        self.userId = id
    }
    
    /// Track an event - logs immediately and caches for upload
    func track(_ event: AnalyticsEvent) {
        // Debug logging
        #if DEBUG
        let props = event.properties.isEmpty ? "" : " \(event.properties)"
        print("📊 [Analytics] \(event.name)\(props)")
        #endif
        
        // Cache for batch upload
        let cachedEvent = CachedAnalyticsEvent(event: event, userId: userId)
        cachedEvents.append(cachedEvent)
        
        // Maintain max cache size
        if cachedEvents.count > maxCacheSize {
            cachedEvents.removeFirst(cachedEvents.count - maxCacheSize)
        }
        
        persistCache()
        
        // Attempt immediate upload if we have connectivity (placeholder for Phase 2)
        // Task { await attemptUpload() }
    }
    
    /// Get all cached events for upload
    func getPendingEvents() -> [CachedAnalyticsEvent] {
        return cachedEvents
    }
    
    /// Clear events that have been successfully uploaded
    func clearUploadedEvents(_ eventIds: [UUID]) {
        cachedEvents.removeAll { eventIds.contains($0.id) }
        persistCache()
    }
    
    /// Clear all cached events (use after successful batch upload)
    func clearAllEvents() {
        cachedEvents.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    /// Get count of pending events
    var pendingEventCount: Int {
        return cachedEvents.count
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
}

// MARK: - Phase 2: Supabase Upload Extension

extension AnalyticsService {
    /// Upload pending events to Supabase (implement in Phase 2)
    /// 
    /// This will be called:
    /// - Periodically (every 30 seconds when app is active)
    /// - On app background
    /// - When event count reaches batch size threshold
    func uploadToSupabase() async {
        // Phase 2 Implementation:
        // 1. Get pending events
        // 2. Format for Supabase events table
        // 3. POST to Supabase
        // 4. Clear uploaded events on success
        // 5. Retry with exponential backoff on failure
        
        #if DEBUG
        print("📊 [Analytics] Would upload \(pendingEventCount) events to Supabase")
        #endif
    }
}
