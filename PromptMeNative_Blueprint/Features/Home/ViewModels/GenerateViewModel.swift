import Combine
import Foundation

@MainActor
final class GenerateViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var refinementText = ""
    @Published var selectedMode: PromptMode = .ai
    @Published private(set) var isGenerating = false
    @Published private(set) var latestResult: GenerateResponse?
    @Published private(set) var latestInput: String = ""
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let authManager: AuthManager
    private let historyStore: HistoryStore
    private let preferencesStore: PreferencesStore

    init(
        apiClient: APIClient,
        authManager: AuthManager,
        historyStore: HistoryStore,
        preferencesStore: PreferencesStore
    ) {
        self.apiClient = apiClient
        self.authManager = authManager
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.selectedMode = preferencesStore.preferences.selectedMode
    }

    var canGenerate: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !isGenerating
    }

    var latestPromptText: String {
        latestResult?.professional.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func generate() async {
        await runGenerate(input: inputText, refinement: nil)
    }

    func generateFromOrb(text: String) async {
        inputText = text
        await runGenerate(input: text, refinement: nil)
    }

    func refine() async {
        guard let latestResult else { return }
        await runGenerate(input: latestResult.professional, refinement: refinementText)
    }

    private func runGenerate(input: String, refinement: String?) async {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else {
            errorMessage = "No speech detected. Try again and speak a little longer."
            return
        }

        guard let token = authManager.token else {
            errorMessage = "Please sign in to generate prompts."
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let request = GenerateRequest(
                input: cleanedInput,
                refinement: refinement?.isEmpty == true ? nil : refinement,
                mode: selectedMode
            )

            let response = try await apiClient.generate(request, token: token)
            let promptText = response.professional.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !promptText.isEmpty else {
                errorMessage = "The server returned an empty result. Please try again."
                latestResult = nil
                return
            }

            latestResult = response
            latestInput = cleanedInput

            if preferencesStore.preferences.saveHistory {
                let item = PromptHistoryItem(
                    mode: selectedMode,
                    input: cleanedInput,
                    professional: response.professional,
                    template: response.template
                )
                historyStore.add(item)
            }

            await authManager.refreshMe()
        } catch {
            if case NetworkError.unauthorized = error {
                authManager.logout()
            }
            if let network = error as? NetworkError {
                errorMessage = network.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func restoreFromHistory(_ item: PromptHistoryItem) {
        selectedMode = item.mode
        inputText = item.input
        latestInput = item.input
        latestResult = GenerateResponse(
            professional: item.professional,
            template: item.template,
            prompts_used: 0,
            prompts_remaining: nil,
            plan: .starter
        )
        errorMessage = nil
    }
}
