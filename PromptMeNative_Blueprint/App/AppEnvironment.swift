import Foundation
import SwiftUI
@preconcurrency import Supabase

// MARK: - AppEnvironment

/// Root dependency container for the entire app.
///
/// All services are created here exactly once and injected downward via
/// SwiftUI's Environment. `@MainActor init()` resolves the Swift concurrency
/// error "Main actor-isolated property cannot be mutated from a non-isolated
/// context" that arises when `@Observable` properties are set in an
/// un-isolated initialiser.
///
/// Note: CloudKit has been removed from this class. Do not reintroduce it.
@Observable
@MainActor
final class AppEnvironment {

    // MARK: - Services

    let supabase: SupabaseClient
    let apiClient: APIClient
    let keychain: KeychainService
    let authManager: AuthManager
    let historyStore: HistoryStore
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager
    /// Keychain-backed client-side freemium usage counter.
    let usageTracker: UsageTracker
    /// Structured error telemetry — queues locally, flushes to Supabase `telemetry_errors`.
    let telemetryService: TelemetryService
    /// Factory seam for speech recognizer construction.
    let speechRecognizerFactory: any SpeechRecognizerFactoryProtocol
    /// Factory seam for orb engine construction.
    let orbEngineFactory: any OrbEngineFactoryProtocol

    // MARK: - Init

    @MainActor
    init() {
        // ── Supabase ─────────────────────────────────────────────────────────
        // Hard-fails at launch if SUPABASE_URL / SUPABASE_ANON_KEY are absent
        // from Info.plist. Both keys must be present before shipping.
        let config = SupabaseConfig.load()
        let supabase = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey
        )
        self.supabase = supabase

        // ── Core services ────────────────────────────────────────────────────
        let baseURL = URL(string: "https://promptme-app-production.up.railway.app")!
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: baseURL)

        self.keychain = keychain
        self.apiClient = apiClient

        // ── Auth ─────────────────────────────────────────────────────────────
        self.authManager = AuthManager(
            supabase: supabase,
            apiClient: apiClient,
            keychain: keychain
        )

        // ── Storage ──────────────────────────────────────────────────────────
        self.historyStore = HistoryStore(supabase: supabase)
        self.preferencesStore = PreferencesStore()

        // ── Usage & Store ────────────────────────────────────────────────────
        self.usageTracker = UsageTracker(keychain: keychain)
        self.storeManager = StoreManager(authManager: authManager, supabase: supabase)

        // ── Navigation ───────────────────────────────────────────────────────
        self.router = AppRouter()

        // ── Telemetry / Analytics (singletons) ───────────────────────────────
        // Inject the live Supabase client so the singletons can flush their
        // local caches to the `telemetry_errors` / `events` Supabase tables.
        self.telemetryService = TelemetryService.shared
        TelemetryService.shared.configure(supabase: supabase)
        AnalyticsService.shared.configure(supabase: supabase)

        // ── Speech / Orb factories ────────────────────────────────────────────
        let speechFactory = LiveSpeechRecognizerFactory()
        self.speechRecognizerFactory = speechFactory
        self.orbEngineFactory = LiveOrbEngineFactory(speechFactory: speechFactory)

        // ── Boot analytics ───────────────────────────────────────────────────
        AnalyticsService.shared.track(.appOpen)
        Task { await syncAnalyticsUserId() }
    }

    // MARK: - Private helpers

    private func syncAnalyticsUserId() async {
        if let user = authManager.currentUser {
            AnalyticsService.shared.setUserId(user.id)
            TelemetryService.shared.setUserId(user.id)
        }
    }
}

// MARK: - ErrorState

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

// MARK: - Environment Keys

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

private struct OrbEngineFactoryKey: EnvironmentKey {
    static var defaultValue: (any OrbEngineFactoryProtocol)? = nil
}

private struct SpeechRecognizerFactoryKey: EnvironmentKey {
    static var defaultValue: (any SpeechRecognizerFactoryProtocol)? = nil
}

private struct SupabaseClientKey: EnvironmentKey {
    static var defaultValue: SupabaseClient? = nil
}

// MARK: - EnvironmentValues

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
