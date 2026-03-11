import SwiftUI

struct AdminPromptsView: View {
	@ObservedObject var viewModel: AdminViewModel

	@State private var showCategories = false
	@State private var selectedCategoryKey: String?
	@State private var editorItem: PromptItem?

	var body: some View {
		VStack(spacing: 10) {
			HStack {
				Button("Manage Categories") {
					showCategories = true
				}
				.buttonStyle(.bordered)

				Spacer()

				Button(viewModel.isSaving ? "Saving..." : "Save Prompts") {
					Task { await viewModel.savePrompts() }
				}
				.buttonStyle(.borderedProminent)
				.disabled(viewModel.isSaving)
			}

			List {
				ForEach(viewModel.promptsDraft.categories) { category in
					Section(category.name) {
						ForEach(category.items) { item in
							VStack(alignment: .leading, spacing: 4) {
								Text(item.title)
									.font(.headline)
								Text(item.prompt)
									.font(.subheadline)
									.foregroundStyle(.secondary)
									.lineLimit(2)
							}
							.padding(.vertical, 4)
							.contentShape(Rectangle())
							.onTapGesture {
								selectedCategoryKey = category.key
								editorItem = item
							}
							.swipeActions {
								Button("Delete", role: .destructive) {
									viewModel.deletePrompt(categoryKey: category.key, promptId: item.id)
								}
							}
						}

						Button("Add Prompt") {
							selectedCategoryKey = category.key
							editorItem = PromptItem(id: UUID().uuidString, title: "", prompt: "")
						}
					}
				}
			}
			.listStyle(.insetGrouped)

			if let message = viewModel.errorMessage {
				Text(message)
					.foregroundStyle(.red)
					.font(.footnote)
			}
		}
		.sheet(isPresented: $showCategories) {
			NavigationStack {
				AdminCategoriesView(viewModel: viewModel)
					.navigationTitle("Categories")
					.toolbar {
						ToolbarItem(placement: .confirmationAction) {
							Button("Done") { showCategories = false }
						}
					}
			}
		}
		.sheet(item: $editorItem) { item in
			if let categoryKey = selectedCategoryKey {
				AdminPromptEditorSheet(
					initialID: item.id,
					initialTitle: item.title,
					initialPrompt: item.prompt
				) { edited in
					viewModel.upsertPrompt(categoryKey: categoryKey, item: edited)
				}
			}
		}
	}
}
