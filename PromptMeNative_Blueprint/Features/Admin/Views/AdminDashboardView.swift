import SwiftUI

struct AdminDashboardView: View {
#if DEBUG
	private enum RootBackgroundTarget {
		case home
		case trending
		case history
		case favorites
	}
#endif

	@Environment(\.apiClient) private var scopedAPIClient
	@Environment(\.keychainService) private var scopedKeychain
#if DEBUG
	@AppStorage(ExperimentFlags.RootBackground.home) private var useRootBackgroundHome = false
	@AppStorage(ExperimentFlags.RootBackground.trending) private var useRootBackgroundTrending = false
	@AppStorage(ExperimentFlags.RootBackground.history) private var useRootBackgroundHistory = false
	@AppStorage(ExperimentFlags.RootBackground.favorites) private var useRootBackgroundFavorites = false
#endif
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
#if DEBUG
							Text("Experiments").tag(2)
#endif
						}
						.pickerStyle(.segmented)

						switch selection {
						case 0:
							AdminTextSettingsView(viewModel: viewModel)
						case 1:
							AdminPromptsView(viewModel: viewModel)
						#if DEBUG
						default:
							experimentFlagsPanel
						#else
						default:
							AdminPromptsView(viewModel: viewModel)
						#endif
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

#if DEBUG
	private var experimentFlagsPanel: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Root Background Flags")
				.font(.headline)

			Text("Enable one flag at a time while running the background QA matrix.")
				.font(.footnote)
				.foregroundStyle(.secondary)

			Text("Active: \(activeRootBackgroundLabel)")
				.font(.footnote)
				.foregroundStyle(.secondary)

			Toggle("Home", isOn: $useRootBackgroundHome)
			Toggle("Trending", isOn: $useRootBackgroundTrending)
			Toggle("History", isOn: $useRootBackgroundHistory)
			Toggle("Favorites", isOn: $useRootBackgroundFavorites)

			Button("Reset All Flags") {
				useRootBackgroundHome = false
				useRootBackgroundTrending = false
				useRootBackgroundHistory = false
				useRootBackgroundFavorites = false
			}
			.buttonStyle(.borderedProminent)
			.tint(.red)

			Spacer(minLength: 0)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.onChange(of: useRootBackgroundHome) { _, isOn in
			if isOn { activateExclusiveRootBackground(.home) }
		}
		.onChange(of: useRootBackgroundTrending) { _, isOn in
			if isOn { activateExclusiveRootBackground(.trending) }
		}
		.onChange(of: useRootBackgroundHistory) { _, isOn in
			if isOn { activateExclusiveRootBackground(.history) }
		}
		.onChange(of: useRootBackgroundFavorites) { _, isOn in
			if isOn { activateExclusiveRootBackground(.favorites) }
		}
	}

	private var activeRootBackgroundLabel: String {
		if useRootBackgroundHome { return "Home" }
		if useRootBackgroundTrending { return "Trending" }
		if useRootBackgroundHistory { return "History" }
		if useRootBackgroundFavorites { return "Favorites" }
		return "None"
	}

	private func activateExclusiveRootBackground(_ target: RootBackgroundTarget) {
		useRootBackgroundHome = target == .home
		useRootBackgroundTrending = target == .trending
		useRootBackgroundHistory = target == .history
		useRootBackgroundFavorites = target == .favorites
	}
#endif
}
