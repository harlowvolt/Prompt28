import SwiftUI
import UIKit

struct HistoryView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = HistoryViewModel()
	@State private var renameItem: PromptHistoryItem?
	@State private var selectedItem: PromptHistoryItem?
	@State private var renameText = ""
	@State private var showClearAllConfirm = false
	@State private var showCopiedToast = false
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
						if let onSelect {
							onSelect(item)
						} else {
							selectedItem = item
						}
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
			.sheet(item: $selectedItem) { item in
				NavigationStack {
					ScrollView {
						VStack(alignment: .leading, spacing: 16) {
							Text(item.customName ?? item.input)
								.font(.title3.weight(.semibold))

							Text(item.professional)
								.font(.body)
								.textSelection(.enabled)

							if !item.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
								Divider()
								Text("Template")
									.font(.caption.weight(.semibold))
									.foregroundStyle(.secondary)
								Text(item.template)
									.font(.footnote)
									.foregroundStyle(.secondary)
									.textSelection(.enabled)
							}

							HStack(spacing: 10) {
								Button("Copy") {
									UIPasteboard.general.string = item.professional
									showCopiedToast = true
									DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
										showCopiedToast = false
									}
								}
								.buttonStyle(.borderedProminent)

								ShareLink(item: item.professional) {
									Label("Share", systemImage: "square.and.arrow.up")
								}
								.buttonStyle(.bordered)

								Button(item.favorite ? "Unfavorite" : "Favorite") {
									viewModel.toggleFavorite(item)
									if let updated = viewModel.items.first(where: { $0.id == item.id }) {
										selectedItem = updated
									}
								}
								.buttonStyle(.bordered)
							}
						}
						.padding()
					}
					.navigationTitle("History Item")
					.navigationBarTitleDisplayMode(.inline)
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Done") {
								selectedItem = nil
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
			.overlay(alignment: .bottom) {
				if showCopiedToast {
					Text("Copied to clipboard")
						.font(.footnote.weight(.semibold))
						.padding(.horizontal, 16)
						.padding(.vertical, 10)
						.background(.ultraThinMaterial, in: Capsule())
						.padding(.bottom, 18)
				}
			}
		}
		.onAppear {
			viewModel.bind(historyStore: env.historyStore)
		}
	}
}
