import SwiftUI

struct FavoritesView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = HistoryViewModel()

	var body: some View {
		NavigationStack {
			PremiumTabScreen(title: "Favorites") {
				searchField

				if viewModel.favoriteItems.isEmpty {
					emptyState
				} else {
					LazyVStack(spacing: 12) {
						ForEach(viewModel.favoriteItems) { item in
							favoriteRow(item)
						}
					}
				}
			}
		}
		.onAppear {
			viewModel.bind(historyStore: env.historyStore)
		}
	}

	private var searchField: some View {
		HStack(spacing: 10) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(PromptTheme.softLilac.opacity(0.72))

			TextField("Search favorites", text: $viewModel.query)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 11)
		.background(PromptTheme.glassFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.stroke(PromptTheme.glassStroke, lineWidth: 1)
		)
	}

	private var emptyState: some View {
		VStack(spacing: 10) {
			Image(systemName: "star")
				.font(.system(size: 28, weight: .semibold))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.75))

			Text("No Favorites Yet")
				.font(.system(size: 18, weight: .semibold, design: .rounded))
				.foregroundStyle(PromptTheme.paleLilacWhite)

			Text("Favorite generated prompts to find them quickly.")
				.font(.system(size: 14, weight: .medium, design: .rounded))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.74))
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 34)
		.padding(.bottom, 22)
	}

	private func favoriteRow(_ item: PromptHistoryItem) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(item.customName ?? item.input)
				.font(.system(size: 17, weight: .semibold, design: .rounded))
				.foregroundStyle(PromptTheme.paleLilacWhite)
				.lineLimit(2)

			Text(item.professional)
				.font(.system(size: 14, weight: .regular, design: .rounded))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.86))
				.lineLimit(3)

			HStack {
				Text(item.createdAt, style: .date)
					.font(.caption)
					.foregroundStyle(PromptTheme.softLilac.opacity(0.72))

				Spacer()

				Button("Remove") {
					viewModel.toggleFavorite(item)
				}
				.buttonStyle(.bordered)
				.tint(PromptTheme.mutedViolet.opacity(0.86))
			}
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(PromptTheme.glassFill)
				.overlay(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.stroke(PromptTheme.glassStroke, lineWidth: 1)
				)
		)
	}
}
