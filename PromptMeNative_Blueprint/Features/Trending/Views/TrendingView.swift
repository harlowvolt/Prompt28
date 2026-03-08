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
			HStack(spacing: 8) {
				ForEach(viewModel.categories) { category in
					let isSelected = viewModel.selectedCategory?.key == category.key
					Button(category.name) {
						viewModel.selectCategory(category.key)
					}
					.buttonStyle(.borderedProminent)
					.tint(isSelected ? PromptTheme.mutedViolet : PromptTheme.deepShadow.opacity(0.85))
				}
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		if viewModel.isLoading && viewModel.catalog == nil {
			VStack(spacing: 10) {
				ProgressView("Loading prompts...")
					.tint(PromptTheme.softLilac)
			}
			.frame(maxWidth: .infinity)
			.padding(.top, 28)
		} else if let message = viewModel.errorMessage, viewModel.catalog == nil {
			VStack(spacing: 10) {
				Text("Could not load trending prompts")
					.font(.headline)
					.foregroundStyle(PromptTheme.paleLilacWhite)
				Text(message)
					.foregroundStyle(PromptTheme.softLilac.opacity(0.82))
					.multilineTextAlignment(.center)
				Button("Retry") {
					Task { await viewModel.refresh(apiClient: env.apiClient) }
				}
				.buttonStyle(.borderedProminent)
				.tint(PromptTheme.mutedViolet)
			}
			.frame(maxWidth: .infinity)
			.padding(.top, 24)
		} else if let category = viewModel.selectedCategory {
			LazyVStack(spacing: 12) {
				ForEach(category.items) { item in
					NavigationLink(destination: PromptDetailView(item: item)) {
						VStack(alignment: .leading, spacing: 8) {
							Text(item.title)
								.font(.system(size: 18, weight: .semibold, design: .rounded))
								.foregroundStyle(PromptTheme.paleLilacWhite)

							Text(item.prompt)
								.lineLimit(3)
								.font(.system(size: 14, weight: .regular, design: .rounded))
								.foregroundStyle(PromptTheme.softLilac.opacity(0.82))
						}
						.frame(maxWidth: .infinity, alignment: .leading)
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
					.buttonStyle(.plain)
				}
			}
		} else {
			VStack(spacing: 10) {
				Image(systemName: "text.quote")
					.font(.system(size: 28, weight: .semibold))
					.foregroundStyle(PromptTheme.softLilac.opacity(0.75))
				Text("No Prompts")
					.font(.system(size: 18, weight: .semibold, design: .rounded))
					.foregroundStyle(PromptTheme.paleLilacWhite)
			}
			.frame(maxWidth: .infinity)
			.padding(.top, 30)
		}
	}
}
