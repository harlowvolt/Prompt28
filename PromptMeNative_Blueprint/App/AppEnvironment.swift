import Foundation
import SwiftData
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
    /// Structured error telemetry — queues to UserDefaults, flushes to Supabase in Phase 2.
    let telemetryService: TelemetryService
    /// Supabase project config loaded from Info.plist (SUPABASE_URL + SUPABASE_ANON_KEY).
    /// Populated when both keys are present; nil while scaffolding is in progress.
    /// Phase 2: replace with `let supabaseClient: SupabaseClient` once supabase-swift SPM is added.
    let supabaseConfig: SupabaseConfig?
    /// Factory seam for speech recognizer construction.
    let speechRecognizerFactory: any SpeechRecognizerFactoryProtocol
    /// Factory seam for orb engine construction.
    let orbEngineFactory: any OrbEngineFactoryProtocol

    init() {
        let baseURL = URL(string: "https://promptme-app-production.up.railway.app")!
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: baseURL)

        self.keychain = keychain
        self.apiClient = apiClient
        self.authManager = AuthManager(apiClient: apiClient, keychain: keychain)
        self.usageTracker = UsageTracker(keychain: keychain)

        // SwiftData: create a persistent ModelContainer for prompt history.
        // A lightweight in-memory fallback is used on catastrophic schema errors
        // (should not occur once the schema is stable).
        let container: ModelContainer
        do {
            container = try ModelContainer(for: PromptHistoryItem.self)
        } catch {
            if let inMemoryContainer = try? ModelContainer(
                for: PromptHistoryItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ) {
                container = inMemoryContainer
            } else {
                fatalError("Failed to initialize SwiftData ModelContainer")
            }
        }
        self.historyStore = HistoryStore(modelContext: container.mainContext)

        self.preferencesStore = PreferencesStore()
        self.router = AppRouter()
        self.telemetryService = TelemetryService.shared

        // Supabase — load non-fatally so the app runs while Info.plist keys are
        // still being configured. Phase 2: once supabase-swift SPM is added,
        // replace this with:
        //   self.supabaseClient = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        self.supabaseConfig = SupabaseConfig.tryLoad()

        self.storeManager = StoreManager(authManager: authManager)
        self.speechRecognizerFactory = LiveSpeechRecognizerFactory()
        self.orbEngineFactory = LiveOrbEngineFactory(speechFactory: speechRecognizerFactory)
        // Combine forwarding removed — @Observable on AuthManager propagates changes automatically
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

private struct OrbEngineFactoryKey: EnvironmentKey {
    static var defaultValue: (any OrbEngineFactoryProtocol)? = nil
}

private struct SpeechRecognizerFactoryKey: EnvironmentKey {
    static var defaultValue: (any SpeechRecognizerFactoryProtocol)? = nil
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

    var orbEngineFactory: (any OrbEngineFactoryProtocol)? {
        get { self[OrbEngineFactoryKey.self] }
        set { self[OrbEngineFactoryKey.self] = newValue }
    }

    var speechRecognizerFactory: (any SpeechRecognizerFactoryProtocol)? {
        get { self[SpeechRecognizerFactoryKey.self] }
        set { self[SpeechRecognizerFactoryKey.self] = newValue }
    }
}
