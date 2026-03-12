import Foundation

@Observable
@MainActor
final class AdminViewModel {
	var adminKeyInput = ""
	private(set) var isUnlocked = false
	private(set) var isLoading = false
	private(set) var isSaving = false
	var errorMessage: String?

	var settingsDraft: AppSettings = .default
	var promptsDraft = PromptCatalog(categories: [])

	private var apiClient: (any APIClientProtocol)?
	private var keychain: KeychainService?
	private let adminKeyStorageKey = "promptme_admin_key"

	func bind(apiClient: any APIClientProtocol, keychain: KeychainService) {
		guard self.apiClient == nil else { return }
		self.apiClient = apiClient
		self.keychain = keychain
	}

	func bootstrap() async {
		guard let keychain,
			  let key = keychain.get(adminKeyStorageKey),
			  !key.isEmpty else {
			return
		}

		adminKeyInput = key
		await verifyAndUnlock()
	}

	func verifyAndUnlock() async {
		guard let apiClient else { return }
		let key = adminKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else {
			errorMessage = "Admin key is required."
			return
		}

		isLoading = true
		errorMessage = nil
		defer { isLoading = false }

		do {
			_ = try await apiClient.adminVerify(key: key)
			try keychain?.set(key, for: adminKeyStorageKey)
			isUnlocked = true
			await loadDashboard()
		} catch {
			isUnlocked = false
			errorMessage = error.localizedDescription
		}
	}

	func lock() {
		keychain?.delete(adminKeyStorageKey)
		adminKeyInput = ""
		isUnlocked = false
		promptsDraft = PromptCatalog(categories: [])
		settingsDraft = .default
	}

	func loadDashboard() async {
		guard let apiClient else { return }
		let key = adminKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return }

		isLoading = true
		errorMessage = nil
		defer { isLoading = false }

		do {
			async let settings = apiClient.adminSettings(key: key)
			async let prompts = apiClient.adminPrompts(key: key)
			settingsDraft = try await settings
			promptsDraft = try await prompts
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func saveSettings() async {
		guard let apiClient else { return }
		let key = adminKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return }

		var payload: [String: Any] = [
			"voiceEnabled": settingsDraft.voiceEnabled ?? true
		]

		if let value = settingsDraft.greetingName { payload["greetingName"] = value }
		if let value = settingsDraft.greetingSubtitle { payload["greetingSubtitle"] = value }
		if let value = settingsDraft.trendingTitle { payload["trendingTitle"] = value }
		if let value = settingsDraft.trendingSubtitle { payload["trendingSubtitle"] = value }
		if let value = settingsDraft.typeButtonText { payload["typeButtonText"] = value }
		if let value = settingsDraft.generateButtonText { payload["generateButtonText"] = value }

		if let nav = settingsDraft.navLabels {
			var navPayload: [String: Any] = [:]
			if let value = nav.home { navPayload["home"] = value }
			if let value = nav.favorites { navPayload["favorites"] = value }
			if let value = nav.history { navPayload["history"] = value }
			if let value = nav.trending { navPayload["trending"] = value }
			if !navPayload.isEmpty {
				payload["navLabels"] = navPayload
			}
		}

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		do {
			_ = try await apiClient.adminUpdateSettings(key: key, payload: payload)
			await loadDashboard()
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func savePrompts() async {
		guard let apiClient else { return }
		let key = adminKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return }

		isSaving = true
		errorMessage = nil
		defer { isSaving = false }

		do {
			_ = try await apiClient.adminUpdatePrompts(key: key, catalog: promptsDraft)
			await loadDashboard()
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func upsertCategory(key: String, name: String) {
		let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedKey.isEmpty, !trimmedName.isEmpty else { return }

		if let idx = promptsDraft.categories.firstIndex(where: { $0.key == trimmedKey }) {
			promptsDraft.categories[idx].name = trimmedName
		} else {
			promptsDraft.categories.append(PromptCategory(key: trimmedKey, name: trimmedName, items: []))
		}
	}

	func deleteCategory(key: String) {
		promptsDraft.categories.removeAll { $0.key == key }
	}

	func upsertPrompt(categoryKey: String, item: PromptItem) {
		guard let categoryIndex = promptsDraft.categories.firstIndex(where: { $0.key == categoryKey }) else { return }
		if let promptIndex = promptsDraft.categories[categoryIndex].items.firstIndex(where: { $0.id == item.id }) {
			promptsDraft.categories[categoryIndex].items[promptIndex] = item
		} else {
			promptsDraft.categories[categoryIndex].items.append(item)
		}
	}

	func deletePrompt(categoryKey: String, promptId: String) {
		guard let categoryIndex = promptsDraft.categories.firstIndex(where: { $0.key == categoryKey }) else { return }
		promptsDraft.categories[categoryIndex].items.removeAll { $0.id == promptId }
	}
}
