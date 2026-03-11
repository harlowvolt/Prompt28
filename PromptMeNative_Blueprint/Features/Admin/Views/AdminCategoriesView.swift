import SwiftUI

struct AdminCategoriesView: View {
	@ObservedObject var viewModel: AdminViewModel
	@State private var newCategoryKey = ""
	@State private var newCategoryName = ""

	var body: some View {
		Form {
			Section("Add Category") {
				TextField("Key (e.g. school)", text: $newCategoryKey)
					.textInputAutocapitalization(.never)
				TextField("Display Name", text: $newCategoryName)
				Button("Add / Update") {
					viewModel.upsertCategory(key: newCategoryKey, name: newCategoryName)
					newCategoryKey = ""
					newCategoryName = ""
				}
			}

			Section("Existing") {
				ForEach(viewModel.promptsDraft.categories) { category in
					HStack {
						Text(category.name)
						Spacer()
						Text(category.key)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.swipeActions {
						Button("Delete", role: .destructive) {
							viewModel.deleteCategory(key: category.key)
						}
					}
				}
			}
		}
	}
}
