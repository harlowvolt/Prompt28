import SwiftUI

struct SettingsView: View {
	@Environment(AppEnvironment.self) private var env
	@StateObject private var viewModel = SettingsViewModel()
	@State private var showUpgrade = false
	@State private var showDeleteConfirm = false

	var body: some View {
		NavigationStack {
			PremiumTabScreen(title: "Settings") {
				accountSection
				preferencesSection
				planSection
				dangerSection

				if let message = viewModel.errorMessage {
					Text(message)
						.font(PromptTheme.Typography.rounded(14, .medium))
						.foregroundStyle(.red.opacity(0.92))
						.padding(.horizontal, PromptTheme.Spacing.s)
						.padding(.vertical, PromptTheme.Spacing.xs)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: PromptTheme.Radius.medium, style: .continuous))
				}
			}
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

	private var accountSection: some View {
		settingsSection(title: "Account") {
			if let user = env.authManager.currentUser {
				settingsRow(label: "Email", value: user.email)
				settingsRow(label: "Plan", value: user.plan.rawValue.capitalized)
				settingsRow(label: "Used", value: "\(user.prompts_used)")
				settingsRow(label: "Remaining", value: user.prompts_remaining.map(String.init) ?? "Unlimited")
			} else {
				settingsRow(label: "Status", value: "Signed out")
			}
		}
	}

	private var preferencesSection: some View {
		settingsSection(title: "Preferences") {
			Toggle("Save Prompt History", isOn: $viewModel.saveHistory)
				.tint(PromptTheme.mutedViolet)

			Picker("Default Mode", selection: $viewModel.selectedMode) {
				Text("AI").tag(PromptMode.ai)
				Text("Human").tag(PromptMode.human)
			}

			Button("Save Preferences") {
				viewModel.applyLocalPreferences()
			}
			.buttonStyle(.borderedProminent)
			.tint(PromptTheme.mutedViolet)
		}
	}

	private var planSection: some View {
		settingsSection(title: "Plan") {
			Button("Manage Plan") {
				showUpgrade = true
			}
			.buttonStyle(.bordered)
			.tint(PromptTheme.softLilac.opacity(0.9))

			if env.authManager.currentUser?.plan == .dev {
				Button("Reset Usage") {
					Task { await viewModel.resetUsage() }
				}
				.buttonStyle(.bordered)
				.tint(PromptTheme.softLilac.opacity(0.9))
			}
		}
	}

	private var dangerSection: some View {
		settingsSection(title: "Danger Zone") {
			Button("Log Out") {
				env.authManager.logout()
				env.router.rootRoute = .auth
			}
			.buttonStyle(.bordered)

			Button("Delete Account", role: .destructive) {
				showDeleteConfirm = true
			}
			.buttonStyle(.bordered)
		}
	}

	private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: PromptTheme.Spacing.s) {
			Text(title)
				.font(PromptTheme.Typography.rounded(14, .semibold))
				.foregroundStyle(PromptTheme.softLilac.opacity(0.76))

			VStack(alignment: .leading, spacing: PromptTheme.Spacing.xs) {
				content()
			}
		}
		.padding(PromptTheme.Spacing.s)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background { PromptTheme.glassCard(cornerRadius: PromptTheme.Radius.medium) }
		.shadow(color: .black.opacity(0.40), radius: 14, y: 10)
	}

	private func settingsRow(label: String, value: String) -> some View {
		HStack {
			Text(label)
				.foregroundStyle(PromptTheme.softLilac.opacity(0.82))

			Spacer()

			Text(value)
				.foregroundStyle(PromptTheme.paleLilacWhite)
				.multilineTextAlignment(.trailing)
		}
		.font(PromptTheme.Typography.rounded(14, .medium))
	}
}
