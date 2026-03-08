import SwiftUI

struct FavoritesView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = HistoryViewModel()

	var body: some View {
		NavigationStack {
			List {
				ForEach(viewModel.favoriteItems) { item in
					VStack(alignment: .leading, spacing: 8) {
						Text(item.customName ?? item.input)
							.font(.headline)
							.lineLimit(2)
						Text(item.professional)
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.lineLimit(3)
					}
					.padding(.vertical, 4)
					.swipeActions(edge: .trailing) {
						Button("Remove") {
							viewModel.toggleFavorite(item)
						}
						.tint(.orange)
					}
				}
			}
			.searchable(text: $viewModel.query, prompt: "Search favorites")
			.navigationTitle("Favorites")
			.overlay {
				if viewModel.favoriteItems.isEmpty {
					ContentUnavailableView("No Favorites", systemImage: "star")
				}
			}
		}
		.onAppear {
			viewModel.bind(historyStore: env.historyStore)
		}
	}
}
