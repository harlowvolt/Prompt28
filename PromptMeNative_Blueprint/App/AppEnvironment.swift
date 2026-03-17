import Foundation
import SwiftUI

@Observable
@MainActor
final class AppEnvironment {
    let apiClient: APIClient
    let keychain: KeychainService
    let authManager: AuthManager
    let historyStore: HistoryStore
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager
    /// Keychain-backed client-side freemium usage counter.
    let usageTracker: UsageTracker
    /// Production error telemetry service (Phase 1)
    let telemetryService: TelemetryService
    /// CloudKit sync service for cross-device history (Phase 2)
    let cloudKitService: CloudKitService
    /// Factory seam for speech recognizer construction.
    let speechRecognizerFactory: any SpeechRecognizerFactoryProtocol
    /// Factory seam for orb engine construction.
    let orbEngineFactory: any OrbEngineFactoryProtocol
    /// Supabase client for auth, database, and real-time features (Task 3)
    let supabase: SupabaseClient

    init() {
        let baseURL = URL(string: "https://promptme-app-production.up.railway.app")!
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: baseURL)
        
        // Task 3: Initialize Supabase client
        // Uses singleton for shared configuration
        let supabase = SupabaseClient.shared
        
        self.keychain = keychain
        self.apiClient = apiClient
        self.supabase = supabase
        
        // Task 3: AuthManager now uses Supabase for authentication
        // APIClient is still passed for backward compatibility with Railway API
        self.authManager = AuthManager(
            supabase: supabase,
            apiClient: apiClient,
            keychain: keychain
        )
        
        self.usageTracker = UsageTracker(keychain: keychain)
        self.telemetryService = TelemetryService.shared
        
        // Phase 2: Initialize CloudKit service
        // Uses default container (no identifier needed for standard iCloud container)
        self.cloudKitService = CloudKitService()
        
        // Phase 2: HistoryStore now uses CloudKitService for sync
        // Falls back to Codable JSON local persistence
        self.historyStore = HistoryStore(cloudKitService: cloudKitService)

        self.preferencesStore = PreferencesStore()
        self.router = AppRouter()
        self.storeManager = StoreManager(authManager: authManager)
        self.speechRecognizerFactory = LiveSpeechRecognizerFactory()
        self.orbEngineFactory = LiveOrbEngineFactory(speechFactory: speechRecognizerFactory)
        
        // Phase 1: Setup analytics and telemetry user ID syncing
        setupAnalyticsAndTelemetry()
    }
    
    private func setupAnalyticsAndTelemetry() {
        // Track app open event
        AnalyticsService.shared.track(.appOpen)
        
        // Sync user ID when auth state changes
        Task {
            await syncAnalyticsUserId()
        }
    }
    
    private func syncAnalyticsUserId() async {
        // Set initial user ID if already authenticated
        if let user = authManager.currentUser {
            AnalyticsService.shared.setUserId(user.id)
            TelemetryService.shared.setUserId(user.id)
        }
    }
}

@Observable
@MainActor
final class ErrorState {
    struct PresentedError: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    private(set) var presented: PresentedError?

    func present(title: String = "Something Went Wrong", message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presented = PresentedError(title: title, message: trimmed)
    }

    func clear() {
        presented = nil
    }
}

private struct HistoryStoreKey: EnvironmentKey {
    static var defaultValue: (any HistoryStoring)? = nil
}

private struct AuthManagerKey: EnvironmentKey {
    static var defaultValue: AuthManager? = nil
}

private struct AppRouterKey: EnvironmentKey {
    static var defaultValue: AppRouter? = nil
}

private struct ErrorStateKey: EnvironmentKey {
    static var defaultValue: ErrorState? = nil
}

private struct APIClientKey: EnvironmentKey {
    static var defaultValue: (any APIClientProtocol)? = nil
}

private struct PreferencesStoreKey: EnvironmentKey {
    static var defaultValue: (any PreferenceStoring)? = nil
}

private struct UsageTrackerKey: EnvironmentKey {
    static var defaultValue: UsageTracker? = nil
}

private struct StoreManagerKey: EnvironmentKey {
    static var defaultValue: StoreManager? = nil
}

private struct KeychainServiceKey: EnvironmentKey {
    static var defaultValue: KeychainService? = nil
}

private struct TelemetryServiceKey: EnvironmentKey {
    static var defaultValue: TelemetryService? = nil
}

private struct CloudKitServiceKey: EnvironmentKey {
    static var defaultValue: CloudKitService? = nil
}

private struct OrbEngineFactoryKey: EnvironmentKey {
    static var defaultValue: (any OrbEngineFactoryProtocol)? = nil
}

private struct SpeechRecognizerFactoryKey: EnvironmentKey {
    static var defaultValue: (any SpeechRecognizerFactoryProtocol)? = nil
}

private struct SupabaseClientKey: EnvironmentKey {
    static var defaultValue: SupabaseClient? = nil
}

extension EnvironmentValues {
    var historyStore: (any HistoryStoring)? {
        get { self[HistoryStoreKey.self] }
        set { self[HistoryStoreKey.self] = newValue }
    }

    var authManager: AuthManager? {
        get { self[AuthManagerKey.self] }
        set { self[AuthManagerKey.self] = newValue }
    }

    var appRouter: AppRouter? {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }

    var errorState: ErrorState? {
        get { self[ErrorStateKey.self] }
        set { self[ErrorStateKey.self] = newValue }
    }

    var apiClient: (any APIClientProtocol)? {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var preferencesStore: (any PreferenceStoring)? {
        get { self[PreferencesStoreKey.self] }
        set { self[PreferencesStoreKey.self] = newValue }
    }

    var usageTracker: UsageTracker? {
        get { self[UsageTrackerKey.self] }
        set { self[UsageTrackerKey.self] = newValue }
    }

    var storeManager: StoreManager? {
        get { self[StoreManagerKey.self] }
        set { self[StoreManagerKey.self] = newValue }
    }

    var keychainService: KeychainService? {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }

    var telemetryService: TelemetryService? {
        get { self[TelemetryServiceKey.self] }
        set { self[TelemetryServiceKey.self] = newValue }
    }

    var cloudKitService: CloudKitService? {
        get { self[CloudKitServiceKey.self] }
        set { self[CloudKitServiceKey.self] = newValue }
    }

    var orbEngineFactory: (any OrbEngineFactoryProtocol)? {
        get { self[OrbEngineFactoryKey.self] }
        set { self[OrbEngineFactoryKey.self] = newValue }
    }

    var speechRecognizerFactory: (any SpeechRecognizerFactoryProtocol)? {
        get { self[SpeechRecognizerFactoryKey.self] }
        set { self[SpeechRecognizerFactoryKey.self] = newValue }
    }
    
    var supabase: SupabaseClient? {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}
