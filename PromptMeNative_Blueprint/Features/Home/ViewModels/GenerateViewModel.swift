import Foundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class GenerateViewModel {
    var inputText = ""
    var refinementText = ""
    var selectedMode: PromptMode = .ai
    private(set) var isGenerating = false
    private(set) var latestResult: GenerateResponse?
    private(set) var latestInput: String = ""
    private(set) var latestHistoryItemID: UUID?
    var errorMessage: String?
    var showPaywall = false
    var showCopiedToast = false

    private let apiClient: any APIClientProtocol
    private let authManager: AuthManager
    private let historyStore: any HistoryStoring
    private let preferencesStore: any PreferenceStoring
    private let usageTracker: UsageTracker

    init(
        apiClient: any APIClientProtocol,
        authManager: AuthManager,
        historyStore: any HistoryStoring,
        preferencesStore: any PreferenceStoring,
        usageTracker: UsageTracker
    ) {
        self.apiClient = apiClient
        self.authManager = authManager
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.usageTracker = usageTracker
        self.selectedMode = preferencesStore.preferences.selectedMode
    }

    var canGenerate: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !isGenerating
    }

    var latestPromptText: String {
        latestResult?.professional.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Live favorite state — reads directly from historyStore (also @Observable),
    /// so any view reading this property re-renders automatically on store changes.
    var isLatestFavorite: Bool {
        guard let id = latestHistoryItemID else { return false }
        return historyStore.items.first(where: { $0.id == id })?.favorite ?? false
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

        // Client-side freemium gate — avoids a wasted API call when local count is exhausted.
        let plan = authManager.currentUser?.plan ?? .starter
        guard usageTracker.canGenerate(for: plan) else {
            showPaywall = true
            AnalyticsService.shared.track(.paywallShown)
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let systemPrompt: String
            switch selectedMode {
            case .ai:
                systemPrompt = "You are an expert AI prompt engineer. Transform the user's raw spoken idea into a precise, structured prompt optimised for AI language models. Maximise clarity, specificity, and instructional detail."
            case .human:
                systemPrompt = "You are an expert communicator and copywriter. Transform the user's raw spoken idea into clear, compelling, human-centred communication. Use natural language, conversational tone, and emotional clarity."
            }

            let request = GenerateRequest(
                input: cleanedInput,
                refinement: refinement?.isEmpty == true ? nil : refinement,
                mode: selectedMode,
                systemPrompt: systemPrompt
            )

            let response = try await apiClient.generate(request, token: token)
            let promptText = response.professional.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !promptText.isEmpty else {
                errorMessage = "The server returned an empty result. Please try again."
                latestResult = nil
                latestHistoryItemID = nil
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

            // Usage tracking: record local generation + sync from server truth.
            usageTracker.recordGeneration()
            usageTracker.sync(promptsRemaining: response.prompts_remaining, plan: plan)

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

                // Notifications: request permission on first-ever successful save
                if historyStore.items.count == 1 {
                    Task { _ = await NotificationService.requestPermission() }
                }
            } else {
                latestHistoryItemID = nil
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

    func triggerCopiedToast() {
        withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            withAnimation(.easeInOut(duration: 0.2)) { self?.showCopiedToast = false }
        }
    }

    func restoreFromHistory(_ item: PromptHistoryItem) {
        selectedMode = item.mode
        inputText = item.input
        latestInput = item.input
        latestHistoryItemID = item.id
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
    }
}
