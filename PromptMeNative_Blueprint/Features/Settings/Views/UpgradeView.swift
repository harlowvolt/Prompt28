import SwiftUI

struct UpgradeView: View {
	@Environment(\.dismiss) private var dismiss
	@ObservedObject var viewModel: SettingsViewModel

	var body: some View {
		NavigationStack {
			Form {
				Section("Choose Plan") {
					Picker("Plan", selection: $viewModel.selectedPlan) {
						Text("Starter").tag(PlanType.starter)
						Text("Pro").tag(PlanType.pro)
						Text("Unlimited").tag(PlanType.unlimited)
						Text("Dev").tag(PlanType.dev)
					}
				}

				if viewModel.selectedPlan == .dev {
					Section("Dev Plan Authorization") {
						SecureField("Admin key", text: $viewModel.devAdminKey)
					}
				}

				Section {
					Button(viewModel.isSaving ? "Saving..." : "Update Plan") {
						Task {
							let updated = await viewModel.updatePlan()
							if updated {
								dismiss()
							}
						}
					}
					.disabled(viewModel.isSaving)
				}

				if let message = viewModel.errorMessage {
					Section {
						Text(message)
							.foregroundStyle(.red)
					}
				}
			}
			.navigationTitle("Manage Plan")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
			}
		}
	}
}
