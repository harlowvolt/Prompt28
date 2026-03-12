import Foundation

enum TrendingCategory: String, CaseIterable {
	case all = "All"
	case school = "School"
	case work = "Work"
	case business = "Business"
	case fitness = "Fitness"
}

@Observable
@MainActor
final class TrendingViewModel {
	private(set) var catalog: PromptCatalog?
	private(set) var isLoading = false
	var errorMessage: String?
	var selectedCategory: TrendingCategory = .all

	var categories: [PromptCategory] {
		catalog?.categories ?? []
	}

	var prompts: [PromptItem] {
		categories.flatMap(\.items)
	}

	var filteredPrompts: [PromptItem] {
		if selectedCategory == .all {
			return prompts
		}

		let key = selectedCategory.rawValue.lowercased()
		return categories
			.filter { $0.key.lowercased() == key }
			.flatMap(\.items)
	}

	func selectCategory(_ category: TrendingCategory) {
		selectedCategory = category
	}

	func promptItem(id: String) -> PromptItem? {
		prompts.first(where: { $0.id == id })
	}

	/// Loads content for display. On the first call:
	///   1. Immediately populates the catalog from the bundled JSON (zero-latency).
	///   2. Fires a background API refresh to pull the latest server-side prompts.
	/// Subsequent calls are no-ops unless `refresh` is called explicitly.
	func loadIfNeeded(apiClient: any APIClientProtocol) async {
		guard catalog == nil else { return }
		await refresh(apiClient: apiClient)
	}

	/// Fetches the latest trending catalog from the server.
	/// Updates `catalog` on success; preserves the existing (bundled or cached)
	/// catalog on failure so the view remains functional offline.
	func refresh(apiClient: any APIClientProtocol) async {
		isLoading = true
		errorMessage = nil
		defer { isLoading = false }

		do {
			let data = try await apiClient.promptsTrending()
			catalog = data
		} catch {
			// Only surface the error if we have nothing to show.
			if catalog == nil {
				errorMessage = error.localizedDescription
			}
			// If bundled/cached data is already showing, fail silently.
		}
	}
}
