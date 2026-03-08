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
					LazyVStack(spacing: PromptTheme.Spacing.s) {
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
		HStack(spacing: PromptTheme.Spacing.xs) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(PromptTheme.softLilac.opacity(0.72))

			TextField("Search favorites", text: $viewModel.query)
				.font(PromptTheme.Typography.rounded(15, .medium))
				.foregroundStyle(PromptTheme.paleLilacWhite)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
		}
		.padding(.horizontal, PromptTheme.Spacing.s)
		.padding(.vertical, PromptTheme.Spacing.xs)
		.background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
				.stroke(Color.white.opacity(0.12), lineWidth: 1)
		)
	}

	private var emptyState: some View {
		VStack(spacing: PromptTheme.Spacing.xs) {
			Image(systemName: "star")
				.font(.system(size: 28, weight: .semibold))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.75))

			Text("No Favorites Yet")
				.font(PromptTheme.Typography.rounded(18, .semibold))
				.foregroundStyle(PromptTheme.paleLilacWhite)

			Text("Favorite generated prompts to find them quickly.")
				.font(PromptTheme.Typography.rounded(14, .medium))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.74))
				.multilineTextAlignment(.center)
		}
		.padding(PromptTheme.Spacing.l)
		.background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
				.stroke(Color.white.opacity(0.1), lineWidth: 1)
		)
		.frame(maxWidth: .infinity)
		.frame(minHeight: 280, alignment: .center)
	}

	private func favoriteRow(_ item: PromptHistoryItem) -> some View {
		VStack(alignment: .leading, spacing: PromptTheme.Spacing.xs) {
			Text(item.customName ?? item.input)
				.font(PromptTheme.Typography.rounded(17, .semibold))
				.foregroundStyle(PromptTheme.paleLilacWhite)
				.lineLimit(2)

			Text(item.professional)
				.font(PromptTheme.Typography.rounded(14, .regular))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.86))
				.lineLimit(3)

			HStack {
				Text(item.createdAt, style: .date)
					.font(PromptTheme.Typography.rounded(12, .medium))
					.foregroundStyle(PromptTheme.softLilac.opacity(0.72))

				Spacer()

				Button("Remove") {
					viewModel.toggleFavorite(item)
				}
				.buttonStyle(.bordered)
				.tint(PromptTheme.mutedViolet.opacity(0.86))
			}
		}
		.padding(PromptTheme.Spacing.s)
		.background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
				.stroke(Color.white.opacity(0.12), lineWidth: 1)
		)
	}
}
