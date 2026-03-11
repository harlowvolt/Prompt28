import Combine
import Foundation

@MainActor
final class TrendingViewModel: ObservableObject {
	@Published private(set) var catalog: PromptCatalog?
	@Published private(set) var isLoading = false
	@Published var errorMessage: String?
	@Published var selectedCategoryKey: String?

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

	func loadIfNeeded(apiClient: APIClient) async {
		guard catalog == nil else { return }
		await refresh(apiClient: apiClient)
	}

	func refresh(apiClient: APIClient) async {
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
			errorMessage = error.localizedDescription
		}
	}
}
