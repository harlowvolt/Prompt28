import SwiftUI
import UIKit

struct HistoryView: View {
	private enum ActiveSheet: Identifiable {
		case rename(PromptHistoryItem)
		case detail(PromptHistoryItem)

		var id: String {
			switch self {
			case .rename(let item):
				return "rename-\(item.id.uuidString)"
			case .detail(let item):
				return "detail-\(item.id.uuidString)"
			}
		}
	}

	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = HistoryViewModel()
	@State private var activeSheet: ActiveSheet?
	@State private var renameText = ""
	@State private var showClearAllConfirm = false
	@State private var showCopiedToast = false
	let onSelect: ((PromptHistoryItem) -> Void)?

	init(onSelect: ((PromptHistoryItem) -> Void)? = nil) {
		self.onSelect = onSelect
	}

	var body: some View {
		NavigationStack {
			PremiumTabScreen(title: "History") {
				searchField

				if viewModel.items.isEmpty {
					emptyState
				} else {
					LazyVStack(spacing: 12) {
						ForEach(viewModel.filteredItems) { item in
							historyRow(item)
						}
					}
				}
			}
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
			.sheet(item: $activeSheet) { sheet in
				switch sheet {
				case .rename(let item):
					NavigationStack {
						Form {
							TextField("Custom title", text: $renameText)
						}
						.navigationTitle("Rename")
						.toolbar {
							ToolbarItem(placement: .cancellationAction) {
								Button("Cancel") {
									activeSheet = nil
								}
							}
							ToolbarItem(placement: .confirmationAction) {
								Button("Save") {
									viewModel.rename(item, to: renameText)
									activeSheet = nil
								}
							}
						}
					}
				case .detail(let item):
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
											activeSheet = .detail(updated)
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
									activeSheet = nil
								}
							}
						}
					}
				}
			}
			.overlay(alignment: .bottom) {
				if showCopiedToast {
					Text("Copied to clipboard")
						.font(.footnote.weight(.semibold))
						.padding(.horizontal, 16)
						.padding(.vertical, 10)
						.background(
							Capsule()
								.fill(PromptTheme.glassFill)
								.overlay(Capsule().stroke(PromptTheme.glassStroke, lineWidth: 1))
						)
						.padding(.bottom, 18)
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

				TextField("Search history", text: $viewModel.query)
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
				Image(systemName: "clock.arrow.circlepath")
					.font(.system(size: 28, weight: .semibold))
					.foregroundStyle(PromptTheme.softLilac.opacity(0.75))

				Text("No History Yet")
					.font(.system(size: 18, weight: .semibold, design: .rounded))
					.foregroundStyle(PromptTheme.paleLilacWhite)

				Text("Your generated prompts will appear here.")
					.font(.system(size: 14, weight: .medium, design: .rounded))
					.foregroundStyle(PromptTheme.softLilac.opacity(0.74))
					.multilineTextAlignment(.center)
			}
			.frame(maxWidth: .infinity)
			.padding(.top, 34)
			.padding(.bottom, 22)
		}

		private func historyRow(_ item: PromptHistoryItem) -> some View {
			VStack(alignment: .leading, spacing: 10) {
				Button {
					if let onSelect {
						onSelect(item)
					} else {
						activeSheet = .detail(item)
					}
				} label: {
					VStack(alignment: .leading, spacing: 8) {
						Text(item.customName ?? item.input)
							.font(.system(size: 17, weight: .semibold, design: .rounded))
							.foregroundStyle(PromptTheme.paleLilacWhite)
							.lineLimit(2)

						Text(item.professional)
							.font(.system(size: 14, weight: .regular, design: .rounded))
							.foregroundStyle(PromptTheme.softLilac.opacity(0.86))
							.lineLimit(3)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.buttonStyle(.plain)

				HStack {
					Text(item.createdAt, style: .date)
						.font(.caption)
						.foregroundStyle(PromptTheme.softLilac.opacity(0.72))

					Spacer()

					Button(item.favorite ? "Unfavorite" : "Favorite") {
						viewModel.toggleFavorite(item)
					}
					.buttonStyle(.bordered)
					.tint(PromptTheme.mutedViolet.opacity(0.86))

					Menu {
						Button("Rename") {
							activeSheet = .rename(item)
							renameText = item.customName ?? ""
						}

						Button("Delete", role: .destructive) {
							viewModel.delete(item)
						}
					} label: {
						Image(systemName: "ellipsis.circle")
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(PromptTheme.softLilac.opacity(0.9))
					}
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
