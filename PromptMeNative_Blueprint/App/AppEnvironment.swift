import Foundation
import SwiftData

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
            container = try! ModelContainer(
                for: PromptHistoryItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        self.historyStore = HistoryStore(modelContext: container.mainContext)

        self.preferencesStore = PreferencesStore()
        self.router = AppRouter()
        self.storeManager = StoreManager()
        // Combine forwarding removed — @Observable on AuthManager propagates changes automatically
    }
}
