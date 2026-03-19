import Foundation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var settings: AppSettings = .default
    private(set) var user: User?
    var errorMessage: String?
    var inputText: String = ""
    var onGeneratePrompt: ((String) -> Void)?

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
            // Railway /api/settings rejects Supabase JWTs with 401.
            // AppSettings is purely cosmetic (feature flags), so falling back to
            // .default is safe. Log silently rather than showing a red banner.
            TelemetryService.shared.logStorageError(
                code: "SETTINGS_LOAD_FAILED",
                message: "HomeViewModel loadSettings failed: \(error.localizedDescription)"
            )
        }
    }

    func generatePrompt() {
        let cleaned = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onGeneratePrompt?(cleaned)
    }

    func orbEngineDidFinishSpeech(_ text: String) {
        inputText = text
        generatePrompt()
    }
}
