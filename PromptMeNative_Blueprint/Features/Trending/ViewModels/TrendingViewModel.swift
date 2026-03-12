import Foundation

@Observable
@MainActor
final class TrendingViewModel {
	private(set) var catalog: PromptCatalog?
	private(set) var isLoading = false
	var errorMessage: String?
	var selectedCategoryKey: String?

	var categories: [PromptCategory] {
		catalog?.categories ?? []
	}

	var selectedCategory: PromptCategory? {
		guard let categoryKey = selectedCategoryKey else {
			return categories.first
		}
		return categories.first(where: { $0.key == categoryKey }) ?? categories.first
	}

	func selectCategory(_ key: String) {
		selectedCategoryKey = key
	}

	/// Loads content for display. On the first call:
	///   1. Immediately populates the catalog from the bundled JSON (zero-latency).
	///   2. Fires a background API refresh to pull the latest server-side prompts.
	/// Subsequent calls are no-ops unless `refresh` is called explicitly.
	func loadIfNeeded(apiClient: any APIClientProtocol) async {
		guard catalog == nil else { return }

		// Step 1 — instant bundle load so the view is never empty on first render.
		if let bundled = BundleCatalogLoader.loadTrendingCatalog() {
			catalog = bundled
			if selectedCategoryKey == nil {
				selectedCategoryKey = bundled.categories.first?.key
			}
		}

		// Step 2 — background API refresh to pick up any server-side updates.
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
			if selectedCategoryKey == nil {
				selectedCategoryKey = data.categories.first?.key
			}
		} catch {
			// Only surface the error if we have nothing to show.
			if catalog == nil {
				errorMessage = error.localizedDescription
			}
			// If bundled/cached data is already showing, fail silently.
		}
	}
}
