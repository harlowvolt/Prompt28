import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let apiClient: APIClient
    let keychain: KeychainService
    let authManager: AuthManager
    let historyStore: HistoryStore
    let preferencesStore: PreferencesStore
    let router: AppRouter
    let storeManager: StoreManager

    private var cancellables = Set<AnyCancellable>()

    init() {
        let baseURL = URL(string: "https://promptme-app-production.up.railway.app")!
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: baseURL)

        self.keychain = keychain
        self.apiClient = apiClient
        self.authManager = AuthManager(apiClient: apiClient, keychain: keychain)
        self.historyStore = HistoryStore()
        self.preferencesStore = PreferencesStore()
        self.router = AppRouter()
        self.storeManager = StoreManager()

        // Forward authManager changes to AppEnvironment so RootView re-renders on login/logout
        self.authManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
