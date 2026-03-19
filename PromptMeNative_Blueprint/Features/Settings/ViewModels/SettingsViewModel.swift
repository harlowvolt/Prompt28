import Foundation
@preconcurrency import Supabase

@Observable
@MainActor
final class SettingsViewModel {
	private(set) var appSettings: AppSettings = .default
	private(set) var isLoading = false
	private(set) var isSaving = false
	var errorMessage: String?

	var saveHistory = true
	var selectedMode: PromptMode = .ai
	var selectedPlan: PlanType = .starter
	var devAdminKey = ""

	private var apiClient: (any APIClientProtocol)?
	private var authManager: AuthManager?
	private var preferencesStore: (any PreferenceStoring)?
	private var historyStore: (any HistoryStoring)?
	private var supabase: SupabaseClient?
    private var usageTracker: UsageTracker?

	init() {}

	func bind(
		apiClient: any APIClientProtocol,
		authManager: AuthManager,
		preferencesStore: any PreferenceStoring,
		historyStore: any HistoryStoring,
		supabase: SupabaseClient? = nil,
        usageTracker: UsageTracker? = nil
	) {
		guard self.apiClient == nil else { return }
		self.apiClient = apiClient
		self.authManager = authManager
		self.preferencesStore = preferencesStore
		self.historyStore = historyStore
		self.supabase = supabase
        self.usageTracker = usageTracker
		syncFromStores()
	}

	func syncFromStores() {
		guard let preferencesStore else { return }
		let prefs = preferencesStore.preferences
		saveHistory = prefs.saveHistory
		selectedMode = prefs.selectedMode
		selectedPlan = authManager?.currentUser?.plan ?? .starter
	}

	func loadRemoteSettings() async {
		isLoading = true
		// Do NOT clear errorMessage here — leave room for user-action errors (save, delete).
		defer { isLoading = false }

		guard let apiClient else { return }

		do {
			appSettings = try await apiClient.settings()
		} catch {
			// AppSettings is purely cosmetic (greeting text, nav labels).
			// The app works correctly with .default values, so we silently swallow
			// the Railway 401 that occurs during the Supabase JWT migration period
			// rather than showing a confusing red error box in Settings.
			TelemetryService.shared.logStorageError(
				code: "SETTINGS_FETCH_FAILED",
				message: error.localizedDescription
			)
		}
	}

	func applyLocalPreferences() {
		guard let preferencesStore else { return }
		preferencesStore.update {
			$0.saveHistory = saveHistory
			$0.selectedMode = selectedMode
			$0.aiModeDefault = (selectedMode == .ai)
		}
	}

    /// Writes `selectedPlan` directly to Supabase `user_metadata.plan`.
    /// Used by the dev "Activate Dev Plan" button in UpgradeView.
    /// Production IAP upgrades are handled by `StoreManager.syncPlanToSupabase()`.
	func updatePlan() async -> Bool {
		guard let authManager, let sb = supabase else {
			errorMessage = "Not authenticated."
			return false
		}

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		do {
			try await sb.auth.update(
                user: UserAttributes(data: ["plan": .string(selectedPlan.rawValue)])
            )
            // Refresh the in-memory user so the UI picks up the new plan immediately.
			await authManager.refreshMe()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}

    /// Resets the local Keychain usage counter to zero.
    /// Dev-only — visible when `currentUser.plan == .dev`.
	func resetUsage() {
		usageTracker?.reset()
	}

	func deleteAccount() async -> Bool {
		guard let authManager, let historyStore else {
			errorMessage = "Not authenticated."
			return false
		}

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		// Phase 3: call the `delete-account` Edge Function which deletes the
		// auth.users row (requires service role) and all associated prompts.
		// Falls back to local-only clear + logout if the function is unavailable.
		if let sb = supabase {
			do {
				struct DeleteResponse: Decodable { let success: Bool? }
				let _: DeleteResponse = try await sb.functions.invoke(
					"delete-account",
					options: FunctionInvokeOptions()
				)
			} catch {
				// If the Edge Function call fails, surface the error so the user
				// can try again rather than silently leaving their account intact.
				errorMessage = "Account deletion failed. Please try again."
				return false
			}
		}

		// Clear local state and sign out regardless of Edge Function outcome.
		historyStore.clearAll()
		authManager.logout()
		return true
	}
}
