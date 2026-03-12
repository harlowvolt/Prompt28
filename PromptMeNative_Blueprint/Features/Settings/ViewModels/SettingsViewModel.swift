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
		errorMessage = nil
		defer { isLoading = false }

		guard let apiClient else { return }

		do {
			appSettings = try await apiClient.settings()
		} catch {
			errorMessage = error.localizedDescription
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
		guard let authManager, let apiClient, let historyStore, let token = authManager.token else {
			errorMessage = "Not authenticated."
			return false
		}

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		do {
			_ = try await apiClient.deleteUser(token: token)
			historyStore.clearAll()
			authManager.logout()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}
}
