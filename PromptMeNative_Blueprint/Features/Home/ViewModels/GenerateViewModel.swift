import Foundation
import SwiftUI
import UIKit
@preconcurrency import Supabase

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

    private let authManager: AuthManager
    private let historyStore: any HistoryStoring
    private let preferencesStore: any PreferenceStoring
    private let usageTracker: UsageTracker

    // StoreKit plan gate — reads verified receipts to determine real plan tier.
    // Nil during testing / when storeManager isn't available; falls back to auth plan.
    private let storeManager: StoreManager?

    // Supabase client for Edge Function invocation.
    // Nil when not injected (should not happen in production since HomeView always injects it).
    private let supabase: SupabaseClient?
    // Name of the deployed Edge Function, read from Info.plist key SUPABASE_GENERATE_FUNCTION.
    // Empty string or missing key → "Generation service not configured" error at generate time.
    private let edgeFunctionName: String?

    init(
        authManager: AuthManager,
        historyStore: any HistoryStoring,
        preferencesStore: any PreferenceStoring,
        usageTracker: UsageTracker,
        storeManager: StoreManager? = nil,
        supabase: SupabaseClient? = nil
    ) {
        self.authManager = authManager
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.usageTracker = usageTracker
        self.storeManager = storeManager
        self.supabase = supabase
        // Read the Edge Function name from Info.plist at init time.
        // Must be set to the deployed function name (e.g. "generate") — empty/missing shows a config error.
        let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_GENERATE_FUNCTION") as? String
        self.edgeFunctionName = (raw?.isEmpty == false) ? raw : nil
        self.selectedMode = preferencesStore.preferences.selectedMode
    }

    /// Resolved plan tier — prefers StoreKit receipt truth, falls back to Supabase user_metadata, then starter.
    var activePlan: PlanType {
        storeManager?.activePlan ?? authManager.currentUser?.plan ?? .starter
    }

    var canGenerate: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !isGenerating
    }

    var latestPromptText: String {
        latestResult?.professional.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Remaining free generations this calendar month.
    /// Returns `nil` for paid plan users (unlimited) — callers should hide the counter.
    var promptsRemaining: Int? {
        guard activePlan == .starter else { return nil }
        return max(0, UsageTracker.freeMonthlyLimit - usageTracker.count)
    }

    /// `true` if the user is at or past their monthly free limit (starter only).
    var isAtFreeLimit: Bool {
        promptsRemaining == 0
    }

    /// Live favorite state — reads directly from historyStore (also @Observable),
    /// so any view reading this property re-renders automatically on store changes.
    var isLatestFavorite: Bool {
        guard let id = latestHistoryItemID else { return false }
        return historyStore.items.first(where: { $0.id == id })?.favorite ?? false
    }

    func generate() async {
        AnalyticsService.shared.track(.generateTapped(mode: selectedMode.rawValue))
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

        guard authManager.token != nil else {
            errorMessage = "Please sign in to generate prompts."
            return
        }

        // Client-side freemium gate — avoids a wasted API call when local count is exhausted.
        // Prefer StoreKit receipt-backed plan so paid users aren't blocked by any plan-sync lag.
        // Fall back to auth user plan (from user_metadata), then starter.
        let plan = storeManager?.activePlan ?? authManager.currentUser?.plan ?? .starter
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

            let response: GenerateResponse

            guard let sb = supabase, let fnName = edgeFunctionName else {
                errorMessage = "Generation service not configured. Check SUPABASE_GENERATE_FUNCTION in Info.plist."
                HapticService.notification(.error)
                return
            }

            // Supabase Edge Function path — carries the user's JWT automatically.
            response = try await invokeEdgeFunction(
                supabase: sb,
                functionName: fnName,
                request: request,
                plan: plan
            )
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
            AnalyticsService.shared.track(.generateSuccess(
                mode: selectedMode.rawValue,
                wordCount: wordCount,
                intentCategory: response.intent_category,
                latencyMs: response.latency_ms,
                webContextUsed: response.web_context_used
            ))

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
                // Show paywall only on explicit rate-limit, not auth errors.
                if case .rateLimited = network {
                    showPaywall = true
                    AnalyticsService.shared.track(.generateRateLimited)
                    AnalyticsService.shared.track(.paywallShown)
                }
                // .unauthorized on the Edge Function is unexpected (JWT is always forwarded).
                // Show a generic service message rather than a misleading "session expired."
                if case .unauthorized = network {
                    errorMessage = "Prompt generation is temporarily unavailable. Please try again."
                } else {
                    errorMessage = network.errorDescription
                }
            } else if let edgeMessage = edgeFunctionErrorMessage(from: error) {
                // Edge Function returned a non-2xx response with a JSON body like
                // { "error": "Monthly generation limit reached…" }. Show that message directly.
                // If the function returned 429, also open the paywall.
                if edgeFunctionHTTPStatus(from: error) == 429 {
                    showPaywall = true
                    AnalyticsService.shared.track(.generateRateLimited)
                    AnalyticsService.shared.track(.paywallShown)
                }
                errorMessage = edgeMessage
            } else {
                errorMessage = error.localizedDescription
            }
            AnalyticsService.shared.track(.generateError(message: error.localizedDescription))
        }
    }

    func trackCopy() {
        AnalyticsService.shared.track(.copyPrompt)
    }

    func trackShare() {
        AnalyticsService.shared.track(.sharePrompt)
    }

    /// Records thumbs up/down feedback for the most recently generated prompt.
    /// Writes to the Supabase `prompt_feedback` table (RLHF data flywheel)
    /// and fires the `prompt_feedback` analytics event.
    ///
    /// Table schema (run once in Supabase SQL editor):
    /// ```sql
    /// create table prompt_feedback (
    ///   id              uuid primary key default gen_random_uuid(),
    ///   user_id         uuid references auth.users(id) on delete cascade,
    ///   history_item_id uuid,
    ///   input           text,
    ///   professional    text,
    ///   thumbs_up       boolean not null,
    ///   created_at      timestamptz default now()
    /// );
    /// alter table prompt_feedback enable row level security;
    /// create policy "Users own their feedback"
    ///   on prompt_feedback for all using (auth.uid() = user_id);
    /// ```
    func submitFeedback(thumbsUp: Bool) async {
        guard let result = latestResult else { return }
        let itemID = latestHistoryItemID?.uuidString ?? "unknown"
        HapticService.impact(thumbsUp ? .medium : .light)
        AnalyticsService.shared.track(.promptFeedback(thumbsUp: thumbsUp, historyItemID: itemID))

        guard let sb = supabase,
              let session = try? await sb.auth.session else { return }

        struct FeedbackRow: Encodable {
            let user_id: String
            let history_item_id: String?
            let input: String
            let professional: String
            let thumbs_up: Bool
        }
        let row = FeedbackRow(
            user_id: session.user.id.uuidString,
            history_item_id: latestHistoryItemID?.uuidString,
            input: latestInput,
            professional: result.professional,
            thumbs_up: thumbsUp
        )
        do {
            try await sb.from("prompt_feedback").insert(row).execute()
        } catch {
            TelemetryService.shared.logStorageError(
                code: "FEEDBACK_INSERT_FAILED",
                message: error.localizedDescription
            )
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
            plan: .starter,
            intent_category: nil,
            latency_ms: nil,
            web_context_used: nil
        )
        errorMessage = nil
    }

    // MARK: - Edge Function invocation

    /// Calls the Supabase Edge Function at `functionName` and maps the response
    /// to the app's `GenerateResponse`. The Edge Function only needs to return
    /// `{ professional, template }` — usage/plan fields are filled in locally
    /// if the function doesn't provide them.
    private func invokeEdgeFunction(
        supabase: SupabaseClient,
        functionName: String,
        request: GenerateRequest,
        plan: PlanType
    ) async throws -> GenerateResponse {
        let raw: EdgeGenerateResponse = try await supabase.functions.invoke(
            functionName,
            options: FunctionInvokeOptions(body: request)
        )
        // Fill in usage metadata locally when the Edge Function omits them.
        let used = raw.prompts_used ?? (usageTracker.count + 1)
        let remaining: Int?
        if let r = raw.prompts_remaining {
            remaining = r
        } else if plan == .starter {
            remaining = max(0, UsageTracker.freeMonthlyLimit - used)
        } else {
            remaining = nil
        }
        return GenerateResponse(
            professional: raw.professional,
            template: raw.template,
            prompts_used: used,
            prompts_remaining: remaining,
            plan: raw.plan ?? plan,
            intent_category: raw.intent_category,
            latency_ms: raw.latency_ms,
            web_context_used: raw.web_context_used
        )
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

    // MARK: - Edge Function error extraction

    /// Extracts the HTTP status code from a Supabase `FunctionsError.httpError(code:data:)`.
    /// Returns `nil` for any other error type.
    private func edgeFunctionHTTPStatus(from error: Error) -> Int? {
        let m = Mirror(reflecting: error)
        // FunctionsError.httpError has associated values (code: Int, data: Data?)
        // The first child is the enum case label; the value is a tuple of associated values.
        for child in m.children {
            let inner = Mirror(reflecting: child.value)
            for innerChild in inner.children {
                if let code = innerChild.value as? Int { return code }
            }
            if let code = child.value as? Int { return code }
        }
        return nil
    }

    /// Extracts a human-readable error message from a Supabase `FunctionsError`.
    ///
    /// When an Edge Function returns a non-2xx response, supabase-swift v2 throws
    /// an error whose associated value contains the raw response `Data`. We use
    /// Mirror to reach that `Data` without importing the internal FunctionsError
    /// type directly, then decode the JSON body for the "error" field.
    ///
    /// Expected Edge Function error body: `{ "error": "some message" }`
    private func edgeFunctionErrorMessage(from error: Error) -> String? {
        // Walk the Mirror tree up to two levels to find any Data associated value.
        func findData(in value: Any) -> Data? {
            let m = Mirror(reflecting: value)
            for child in m.children {
                if let data = child.value as? Data { return data }
                let inner = Mirror(reflecting: child.value)
                for innerChild in inner.children {
                    if let data = innerChild.value as? Data { return data }
                }
            }
            return nil
        }

        guard let data = findData(in: error) else { return nil }

        // Decode the edge function error body.
        struct EdgeError: Decodable { let error: String? }
        if let body = try? JSONDecoder().decode(EdgeError.self, from: data) {
            return body.error
        }
        // Fallback: try as plain string.
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Edge Function DTO

/// Decodable response from the Supabase Edge Function `/generate`.
/// The Edge Function MUST return at minimum `{ professional, template }`.
/// All other fields are optional and filled in locally when absent.
///
/// Full Edge Function response shape:
/// ```json
/// {
///   "professional": "Refined prompt text…",
///   "template": "Template text…",
///   "prompts_used": 1,               // optional
///   "prompts_remaining": 9,          // optional (starter plan)
///   "plan": "starter",               // optional
///   "intent_category": "work",       // optional — intent classifier output
///   "latency_ms": 843,               // optional — total server-side latency
///   "web_context_used": true         // optional — true when Brave Search snippet was injected
/// }
/// ```
private struct EdgeGenerateResponse: Decodable, Sendable {
    let professional: String
    let template: String
    let prompts_used: Int?
    let prompts_remaining: Int?
    let plan: PlanType?
    let intent_category: String?
    let latency_ms: Int?
    let web_context_used: Bool?
}
