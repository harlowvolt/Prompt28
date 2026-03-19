import Foundation

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

	init() {}

	func bind(
		apiClient: any APIClientProtocol,
		authManager: AuthManager,
		preferencesStore: any PreferenceStoring,
		historyStore: any HistoryStoring
	) {
		guard self.apiClient == nil else { return }
		self.apiClient = apiClient
		self.authManager = authManager
		self.preferencesStore = preferencesStore
		self.historyStore = historyStore
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

		// Note: The Railway /api/user DELETE endpoint rejects Supabase JWTs.
		// Phase 3 will add a Supabase Edge Function for server-side account deletion
		// (removing auth.users row requires service role). For now:
		//   1. Clear all local history (local + Supabase prompts table via RLS)
		//   2. Sign out via Supabase — invalidates the session
		// The Supabase auth user record itself persists until Phase 3 deletion function
		// is deployed, but the user cannot sign back in to access their data.
		historyStore.clearAll()
		authManager.logout()
		return true
	}
}
