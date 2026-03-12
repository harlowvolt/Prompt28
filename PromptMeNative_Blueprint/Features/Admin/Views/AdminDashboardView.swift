import SwiftUI

struct AdminDashboardView: View {
	@Environment(\.apiClient) private var scopedAPIClient
	@Environment(\.keychainService) private var scopedKeychain
	@State private var viewModel = AdminViewModel()
	@State private var selection = 0

	var body: some View {
		NavigationStack {
			Group {
				if viewModel.isUnlocked {
					VStack(spacing: 12) {
						Picker("Section", selection: $selection) {
							Text("Text").tag(0)
							Text("Prompts").tag(1)
						}
						.pickerStyle(.segmented)

						if selection == 0 {
							AdminTextSettingsView(viewModel: viewModel)
						} else {
							AdminPromptsView(viewModel: viewModel)
						}
					}
					.padding()
				} else {
					AdminUnlockView(viewModel: viewModel)
				}
			}
			.navigationTitle("Admin")
			.toolbar {
				if viewModel.isUnlocked {
					ToolbarItem(placement: .topBarLeading) {
						Button("Lock") {
							viewModel.lock()
						}
					}
					ToolbarItem(placement: .topBarTrailing) {
						Button("Refresh") {
							Task { await viewModel.loadDashboard() }
						}
					}
				}
			}
			.task {
				guard let scopedAPIClient, let scopedKeychain else {
					viewModel.errorMessage = "Admin dependencies unavailable."
					return
				}
				viewModel.bind(apiClient: scopedAPIClient, keychain: scopedKeychain)
				await viewModel.bootstrap()
			}
		}
	}
}
