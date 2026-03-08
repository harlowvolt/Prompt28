import SwiftUI

struct SettingsView: View {
	@EnvironmentObject private var env: AppEnvironment
	@StateObject private var viewModel = SettingsViewModel()
	@State private var showUpgrade = false
	@State private var showDeleteConfirm = false

	var body: some View {
		NavigationStack {
			Form {
				Section("Account") {
					if let user = env.authManager.currentUser {
						LabeledContent("Email", value: user.email)
						LabeledContent("Plan", value: user.plan.rawValue.capitalized)
						LabeledContent("Used", value: "\(user.prompts_used)")
						LabeledContent("Remaining", value: user.prompts_remaining.map(String.init) ?? "Unlimited")
					}
				}

				Section("Preferences") {
					Toggle("Save Prompt History", isOn: $viewModel.saveHistory)

					Picker("Default Mode", selection: $viewModel.selectedMode) {
						Text("AI").tag(PromptMode.ai)
						Text("Human").tag(PromptMode.human)
					}

					Button("Save Preferences") {
						viewModel.applyLocalPreferences()
					}
				}

				Section("Plan") {
					Button("Manage Plan") {
						showUpgrade = true
					}

					if env.authManager.currentUser?.plan == .dev {
						Button("Reset Usage") {
							Task { await viewModel.resetUsage() }
						}
					}
				}

				Section("Danger Zone") {
					Button("Log Out", role: .none) {
						env.authManager.logout()
						env.router.rootRoute = .auth
					}

					Button("Delete Account", role: .destructive) {
						showDeleteConfirm = true
					}
				}

				if let message = viewModel.errorMessage {
					Section {
						Text(message)
							.foregroundStyle(.red)
					}
				}
			}
			.scrollContentBackground(.hidden)
			.background(PromptTheme.backgroundGradient.ignoresSafeArea())
			.navigationTitle("Settings")
			.task {
				viewModel.bind(
					apiClient: env.apiClient,
					authManager: env.authManager,
					preferencesStore: env.preferencesStore,
					historyStore: env.historyStore
				)
				viewModel.syncFromStores()
				await viewModel.loadRemoteSettings()
			}
			.sheet(isPresented: $showUpgrade) {
				UpgradeView(viewModel: viewModel)
			}
			.confirmationDialog("Delete your account permanently?", isPresented: $showDeleteConfirm) {
				Button("Delete Account", role: .destructive) {
					Task {
						let deleted = await viewModel.deleteAccount()
						if deleted {
							env.router.rootRoute = .auth
						}
					}
				}
			}
		}
	}
}
