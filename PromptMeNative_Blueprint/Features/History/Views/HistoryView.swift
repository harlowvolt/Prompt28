import SwiftUI

struct HistoryView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = HistoryViewModel()
	@State private var renameItem: PromptHistoryItem?
	@State private var renameText = ""
	@State private var showClearAllConfirm = false
	let onSelect: ((PromptHistoryItem) -> Void)?

	init(onSelect: ((PromptHistoryItem) -> Void)? = nil) {
		self.onSelect = onSelect
	}

	var body: some View {
		NavigationStack {
			List {
				ForEach(viewModel.filteredItems) { item in
					VStack(alignment: .leading, spacing: 8) {
						Text(item.customName ?? item.input)
							.font(.headline)
							.lineLimit(2)

						Text(item.professional)
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.lineLimit(3)

						HStack {
							Text(item.createdAt, style: .date)
								.font(.caption)
								.foregroundStyle(.secondary)
							Spacer()
							Button(item.favorite ? "Unfavorite" : "Favorite") {
								viewModel.toggleFavorite(item)
							}
							.font(.caption)
							.buttonStyle(.bordered)
						}
					}
					.contentShape(Rectangle())
					.onTapGesture {
						onSelect?(item)
					}
					.padding(.vertical, 4)
					.swipeActions(edge: .leading, allowsFullSwipe: false) {
						Button("Rename") {
							renameItem = item
							renameText = item.customName ?? ""
						}
						.tint(.blue)
					}
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button("Delete", role: .destructive) {
							viewModel.delete(item)
						}
					}
				}
			}
			.listStyle(.plain)
			.searchable(text: $viewModel.query, prompt: "Search history")
			.navigationTitle("History")
			.toolbar {
				if !viewModel.items.isEmpty {
					ToolbarItem(placement: .topBarTrailing) {
						Button("Clear") {
							showClearAllConfirm = true
						}
					}
				}
			}
			.confirmationDialog("Clear all history?", isPresented: $showClearAllConfirm) {
				Button("Clear All", role: .destructive) {
					viewModel.clearAll()
				}
			}
			.sheet(item: $renameItem) { item in
				NavigationStack {
					Form {
						TextField("Custom title", text: $renameText)
					}
					.navigationTitle("Rename")
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Cancel") {
								renameItem = nil
							}
						}
						ToolbarItem(placement: .confirmationAction) {
							Button("Save") {
								viewModel.rename(item, to: renameText)
								renameItem = nil
							}
						}
					}
				}
			}
			.overlay {
				if viewModel.items.isEmpty {
					ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath")
				}
			}
		}
		.onAppear {
			viewModel.bind(historyStore: env.historyStore)
		}
	}
}
