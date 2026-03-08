import SwiftUI

struct TrendingView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = TrendingViewModel()

	var body: some View {
		NavigationStack {
			PremiumTabScreen(title: "Trending") {
				categoryPicker
				content
			}
			.task {
				await viewModel.loadIfNeeded(apiClient: env.apiClient)
			}
			.refreshable {
				await viewModel.refresh(apiClient: env.apiClient)
			}
		}
	}

	private var categoryPicker: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: PromptTheme.Spacing.xs) {
				ForEach(viewModel.categories) { category in
					let isSelected = viewModel.selectedCategory?.key == category.key
					Button(category.name) {
						viewModel.selectCategory(category.key)
					}
					.font(PromptTheme.Typography.rounded(13, .semibold))
					.buttonStyle(.borderedProminent)
					.tint(isSelected ? PromptTheme.mutedViolet : PromptTheme.deepShadow.opacity(0.85))
				}
			}
			.padding(.vertical, PromptTheme.Spacing.xxs)
		}
	}

	@ViewBuilder
	private var content: some View {
		if viewModel.isLoading && viewModel.catalog == nil {
			VStack(spacing: PromptTheme.Spacing.xs) {
				ProgressView("Loading prompts...")
					.tint(PromptTheme.softLilac)
			}
			.padding(PromptTheme.Spacing.l)
			.background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
					.stroke(Color.white.opacity(0.1), lineWidth: 1)
			)
			.frame(maxWidth: .infinity)
			.frame(minHeight: 280, alignment: .center)
		} else if let message = viewModel.errorMessage, viewModel.catalog == nil {
			VStack(spacing: PromptTheme.Spacing.xs) {
				Text("Could not load trending prompts")
					.font(PromptTheme.Typography.rounded(18, .semibold))
					.foregroundStyle(PromptTheme.paleLilacWhite)
				Text(message)
					.font(PromptTheme.Typography.rounded(14, .medium))
					.foregroundStyle(PromptTheme.softLilac.opacity(0.82))
					.multilineTextAlignment(.center)
				Button("Retry") {
					Task { await viewModel.refresh(apiClient: env.apiClient) }
				}
				.buttonStyle(.borderedProminent)
				.tint(PromptTheme.mutedViolet)
			}
			.padding(PromptTheme.Spacing.l)
			.background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: PromptTheme.Radius.large, style: .continuous)
					.stroke(Color.white.opacity(0.1), lineWidth: 1)
			)
			.frame(maxWidth: .infinity)
			.frame(minHeight: 280, alignment: .center)
		} else if let category = viewModel.selectedCategory {
			LazyVStack(spacing: PromptTheme.Spacing.s) {
				ForEach(category.items) { item in
					NavigationLink(destination: PromptDetailView(item: item)) {
						VStack(alignment: .leading, spacing: PromptTheme.Spacing.xs) {
							Text(item.title)
								.font(PromptTheme.Typography.rounded(18, .semibold))
								.foregroundStyle(PromptTheme.paleLilacWhite)

							Text(item.prompt)
								.lineLimit(3)
								.font(PromptTheme.Typography.rounded(14, .regular))
								.foregroundStyle(PromptTheme.softLilac.opacity(0.82))
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(PromptTheme.Spacing.s)
						.background(PromptTheme.premiumMaterial, in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
						.overlay(
							RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous)
								.stroke(Color.white.opacity(0.12), lineWidth: 1)
						)
					}
					.buttonStyle(.plain)
				}
			}
		} else {
			VStack(spacing: PromptTheme.Spacing.xs) {
				Image(systemName: "text.quote")
					.font(.system(size: 28, weight: .semibold))
					.foregroundStyle(PromptTheme.softLilac.opacity(0.75))
				Text("No Prompts")
					.font(PromptTheme.Typography.rounded(18, .semibold))
					.foregroundStyle(PromptTheme.paleLilacWhite)
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
	}
}
