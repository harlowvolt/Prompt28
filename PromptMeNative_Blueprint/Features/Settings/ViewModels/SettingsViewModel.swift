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

	init() {}

	func bind(
		apiClient: any APIClientProtocol,
		authManager: AuthManager,
		preferencesStore: any PreferenceStoring,
		historyStore: any HistoryStoring,
		supabase: SupabaseClient? = nil
	) {
		guard self.apiClient == nil else { return }
		self.apiClient = apiClient
		self.authManager = authManager
		self.preferencesStore = preferencesStore
		self.historyStore = historyStore
		self.supabase = supabase
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

	func updatePlan() async -> Bool {
		guard let authManager, let apiClient, let token = authManager.token else {
			errorMessage = "Not authenticated."
			return false
		}

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		do {
			let adminKey = devAdminKey.trimmingCharacters(in: .whitespacesAndNewlines)
			_ = try await apiClient.updatePlan(
				UpdatePlanRequest(plan: selectedPlan, adminKey: adminKey.isEmpty ? nil : adminKey),
				token: token
			)
			await authManager.refreshMe()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}

	func resetUsage() async {
		guard let authManager, let apiClient, let token = authManager.token else {
			errorMessage = "Not authenticated."
			return
		}

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		do {
			_ = try await apiClient.resetUsage(token: token)
			await authManager.refreshMe()
		} catch {
			errorMessage = error.localizedDescription
		}
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
