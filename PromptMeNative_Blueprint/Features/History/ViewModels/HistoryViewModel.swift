import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
	@Published var query = ""
	@Published private(set) var items: [PromptHistoryItem] = []

	private var historyStore: HistoryStore?
	private var cancellables: Set<AnyCancellable> = []

	init() {}

	func bind(historyStore: HistoryStore) {
		guard self.historyStore == nil else { return }
		self.historyStore = historyStore
		self.items = historyStore.items

		historyStore.$items
			.receive(on: DispatchQueue.main)
			.sink { [weak self] value in
				self?.items = value
			}
			.store(in: &cancellables)
	}

	var filteredItems: [PromptHistoryItem] {
		let newestFirst = items.sorted { $0.createdAt > $1.createdAt }
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
