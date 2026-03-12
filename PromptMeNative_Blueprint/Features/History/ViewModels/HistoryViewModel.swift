import Foundation

@Observable
@MainActor
final class HistoryViewModel {
	var query = ""

	private var historyStore: (any HistoryStoring)?

	init() {}

	func bind(historyStore: any HistoryStoring) {
		guard self.historyStore == nil else { return }
		self.historyStore = historyStore
	}

	/// Live, filtered view of history. Because historyStore is @Observable,
	/// SwiftUI automatically tracks historyStore.items and re-renders on changes.
	var filteredItems: [PromptHistoryItem] {
		let newestFirst = (historyStore?.items ?? []).sorted { $0.createdAt > $1.createdAt }
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return newestFirst }

		return newestFirst.filter {
			$0.input.localizedCaseInsensitiveContains(trimmed)
			|| $0.professional.localizedCaseInsensitiveContains(trimmed)
			|| ($0.customName?.localizedCaseInsensitiveContains(trimmed) == true)
		}
	}

	var favoriteItems: [PromptHistoryItem] {
		filteredItems.filter(\.favorite)
	}

	func toggleFavorite(_ item: PromptHistoryItem) {
		historyStore?.toggleFavorite(id: item.id)
	}

	func delete(_ item: PromptHistoryItem) {
		historyStore?.remove(id: item.id)
	}

	func rename(_ item: PromptHistoryItem, to customName: String?) {
		let cleaned = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
		historyStore?.rename(id: item.id, customName: cleaned?.isEmpty == true ? nil : cleaned)
	}

	func clearAll() {
		historyStore?.clearAll()
	}
}
