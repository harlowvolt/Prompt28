import SwiftUI

struct TrendingView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = TrendingViewModel()

	var body: some View {
		NavigationStack {
			VStack(spacing: 12) {
				categoryPicker
				content
			}
			.padding()
			.background(PromptTheme.backgroundGradient.ignoresSafeArea())
			.navigationTitle("Trending")
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
			Spacer()
			ProgressView("Loading prompts...")
			Spacer()
		} else if let message = viewModel.errorMessage, viewModel.catalog == nil {
			Spacer()
			VStack(spacing: 10) {
				Text("Could not load trending prompts")
					.font(.headline)
				Text(message)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
				Button("Retry") {
					Task { await viewModel.refresh(apiClient: env.apiClient) }
				}
				.buttonStyle(.borderedProminent)
			}
			Spacer()
		} else if let category = viewModel.selectedCategory {
			List(category.items) { item in
				NavigationLink(destination: PromptDetailView(item: item)) {
					VStack(alignment: .leading, spacing: 6) {
						Text(item.title)
							.font(.headline)
						Text(item.prompt)
							.lineLimit(2)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					.padding(.vertical, 4)
				}
			}
			.listStyle(.plain)
		} else {
			Spacer()
			ContentUnavailableView("No Prompts", systemImage: "text.quote")
			Spacer()
		}
	}
}
