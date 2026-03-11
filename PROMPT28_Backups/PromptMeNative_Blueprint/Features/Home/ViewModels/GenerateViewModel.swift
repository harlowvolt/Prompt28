import Combine
import Foundation
import UIKit

@MainActor
final class GenerateViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var refinementText = ""
    @Published var selectedMode: PromptMode = .ai
    @Published private(set) var isGenerating = false
    @Published private(set) var latestResult: GenerateResponse?
    @Published private(set) var latestInput: String = ""
    @Published private(set) var latestHistoryItemID: UUID?
    @Published private(set) var isLatestFavorite = false
    @Published var errorMessage: String?
    @Published var showPaywall = false

    private let apiClient: APIClient
    private let authManager: AuthManager
    private let historyStore: HistoryStore
    private let preferencesStore: PreferencesStore
    private var cancellables: Set<AnyCancellable> = []

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

        historyStore.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.syncLatestFavoriteState(items: items)
            }
            .store(in: &cancellables)

        syncLatestFavoriteState(items: historyStore.items)
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
        AnalyticsService.shared.track(.generateTapped(mode: selectedMode.rawValue))
        await runGenerate(input: text, refinement: nil)
    }

    func refine() async {
        guard let latestResult else { return }
        AnalyticsService.shared.track(.refinePrompt)
        await runGenerate(input: latestResult.professional, refinement: refinementText)
    }

    private func runGenerate(input: String, refinement: String?) async {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else {
            errorMessage = "No speech detected. Try again and speak a little longer."
            HapticService.notification(.error)
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
                latestHistoryItemID = nil
                isLatestFavorite = false
                HapticService.notification(.error)
                return
            }

            latestResult = response
            latestInput = cleanedInput

            // Analytics: track success
            let wordCount = promptText.split(separator: " ").count
            AnalyticsService.shared.track(.generateSuccess(mode: selectedMode.rawValue, wordCount: wordCount))

            // Haptics: success pulse
            HapticService.notification(.success)

            // Paywall: show if user has run out of prompts
            if let remaining = response.prompts_remaining, remaining <= 0 {
                showPaywall = true
                AnalyticsService.shared.track(.paywallShown)
            }

            // Notifications: low-usage local alert
            if let remaining = response.prompts_remaining {
                NotificationService.scheduleLowUsageAlert(remaining: remaining)
            }

            if preferencesStore.preferences.saveHistory {
                let item = PromptHistoryItem(
                    mode: selectedMode,
                    input: cleanedInput,
                    professional: response.professional,
                    template: response.template
                )
                historyStore.add(item)
                latestHistoryItemID = item.id
                isLatestFavorite = item.favorite

                // Notifications: request permission on first-ever successful save
                if historyStore.items.count == 1 {
                    Task { _ = await NotificationService.requestPermission() }
                }
            } else {
                latestHistoryItemID = nil
                isLatestFavorite = false
            }

            await authManager.refreshMe()
        } catch {
            HapticService.notification(.error)
            if let network = error as? NetworkError {
                if network.isSessionExpired {
                    authManager.logout()
                }
                // Show paywall on rate limit
                if case .rateLimited = network {
                    showPaywall = true
                    AnalyticsService.shared.track(.generateRateLimited)
                    AnalyticsService.shared.track(.paywallShown)
                }
                errorMessage = network.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            AnalyticsService.shared.track(.generateError(message: error.localizedDescription))
        }
    }

    func restoreFromHistory(_ item: PromptHistoryItem) {
        selectedMode = item.mode
        inputText = item.input
        latestInput = item.input
        latestHistoryItemID = item.id
        isLatestFavorite = item.favorite
        latestResult = GenerateResponse(
            professional: item.professional,
            template: item.template,
            prompts_used: 0,
            prompts_remaining: nil,
            plan: .starter
        )
        errorMessage = nil
    }

    func toggleFavoriteForLatest() {
        guard let latestResult else { return }
        HapticService.impact(.medium)
        AnalyticsService.shared.track(.favoriteTapped)

        if let id = latestHistoryItemID {
            historyStore.toggleFavorite(id: id)
            return
        }

        let fallbackInput = latestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = PromptHistoryItem(
            mode: selectedMode,
            input: fallbackInput.isEmpty ? latestResult.professional : fallbackInput,
            professional: latestResult.professional,
            template: latestResult.template,
            favorite: true
        )
        historyStore.add(item)
        latestHistoryItemID = item.id
        isLatestFavorite = true
    }

    private func syncLatestFavoriteState(items: [PromptHistoryItem]) {
        guard let id = latestHistoryItemID else {
            isLatestFavorite = false
            return
        }

        if let item = items.first(where: { $0.id == id }) {
            isLatestFavorite = item.favorite
        } else {
            latestHistoryItemID = nil
            isLatestFavorite = false
        }
    }
}
