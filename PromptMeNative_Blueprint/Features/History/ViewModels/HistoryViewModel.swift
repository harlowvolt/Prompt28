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

	func item(id: UUID) -> PromptHistoryItem? {
		historyStore?.items.first(where: { $0.id == id })
	}

	func toggleFavorite(id: UUID) {
		historyStore?.toggleFavorite(id: id)
	}

	func delete(id: UUID) {
		historyStore?.remove(id: id)
	}

	func rename(id: UUID, to customName: String?) {
		let cleaned = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
		historyStore?.rename(id: id, customName: cleaned?.isEmpty == true ? nil : cleaned)
	}

	func clearAll() {
		historyStore?.clearAll()
	}

	/// `true` while a Supabase sync is in flight — forwarded from the store so
	/// the pull-to-refresh indicator stays visible for the full sync duration.
	var isSyncing: Bool { historyStore?.isSyncing ?? false }

	/// Triggers a forced two-way Supabase sync (called from pull-to-refresh).
	func syncWithRemote() async {
		await historyStore?.forceSync()
	}
}
