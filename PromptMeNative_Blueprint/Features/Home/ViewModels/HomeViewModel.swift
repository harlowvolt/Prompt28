import Foundation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var settings: AppSettings = .default
    private(set) var user: User?
    var errorMessage: String?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient, authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    func load() async {
        await loadSettings()
        await refreshUser()
    }

    func refreshUser() async {
        await authManager.refreshMe()
        user = authManager.currentUser
    }

    private func loadSettings() async {
        do {
            settings = try await apiClient.settings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
