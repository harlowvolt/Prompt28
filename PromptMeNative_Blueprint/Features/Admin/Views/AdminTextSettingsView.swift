import SwiftUI

struct AdminTextSettingsView: View {
	@ObservedObject var viewModel: AdminViewModel

	var body: some View {
		Form {
			Section("Home") {
				TextField("Greeting Name", text: bindingString(\.greetingName))
				TextField("Greeting Subtitle", text: bindingString(\.greetingSubtitle))
			}

			Section("Trending") {
				TextField("Trending Title", text: bindingString(\.trendingTitle))
				TextField("Trending Subtitle", text: bindingString(\.trendingSubtitle))
			}

			Section("Buttons") {
				TextField("Type Button Text", text: bindingString(\.typeButtonText))
				TextField("Generate Button Text", text: bindingString(\.generateButtonText))
			}

			Section("Navigation") {
				TextField("Home Label", text: navBinding { $0.home } set: { nav, value in
					NavLabels(home: value, favorites: nav.favorites, history: nav.history, trending: nav.trending)
				})
				TextField("Favorites Label", text: navBinding { $0.favorites } set: { nav, value in
					NavLabels(home: nav.home, favorites: value, history: nav.history, trending: nav.trending)
				})
				TextField("History Label", text: navBinding { $0.history } set: { nav, value in
					NavLabels(home: nav.home, favorites: nav.favorites, history: value, trending: nav.trending)
				})
				TextField("Trending Label", text: navBinding { $0.trending } set: { nav, value in
					NavLabels(home: nav.home, favorites: nav.favorites, history: nav.history, trending: value)
				})
			}

			Section {
				Toggle(
					"Voice Enabled",
					isOn: Binding(
						get: { viewModel.settingsDraft.voiceEnabled ?? true },
						set: { value in
							updateSettings { draft in
								draft.voiceEnabled = value
							}
						}
					)
				)
			}

			Section {
				Button(viewModel.isSaving ? "Saving..." : "Save Settings") {
					Task { await viewModel.saveSettings() }
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
	}

	private func bindingString(_ keyPath: WritableKeyPath<DraftSettings, String?>) -> Binding<String> {
		Binding(
			get: {
				DraftSettings(from: viewModel.settingsDraft)[keyPath: keyPath] ?? ""
			},
			set: { value in
				updateSettings { draft in
					draft[keyPath: keyPath] = value
				}
			}
		)
	}

	private func navBinding(
		_ getValue: @escaping (NavLabels) -> String?,
		set setValue: @escaping (NavLabels, String) -> NavLabels
	) -> Binding<String> {
		Binding(
			get: {
				let nav = DraftSettings(from: viewModel.settingsDraft).navLabels
				return nav.flatMap(getValue) ?? ""
			},
			set: { value in
				updateSettings { draft in
					let nav = draft.navLabels ?? NavLabels(home: nil, favorites: nil, history: nil, trending: nil)
					draft.navLabels = setValue(nav, value)
				}
			}
		)
	}

	private func updateSettings(_ update: (inout DraftSettings) -> Void) {
		var draft = DraftSettings(from: viewModel.settingsDraft)
		update(&draft)
		viewModel.settingsDraft = draft.toAppSettings()
	}
}

private struct DraftSettings {
	var greetingName: String?
	var greetingSubtitle: String?
	var trendingTitle: String?
	var trendingSubtitle: String?
	var typeButtonText: String?
	var generateButtonText: String?
	var navLabels: NavLabels?
	var voiceEnabled: Bool?

	init(from settings: AppSettings) {
		greetingName = settings.greetingName
		greetingSubtitle = settings.greetingSubtitle
		trendingTitle = settings.trendingTitle
		trendingSubtitle = settings.trendingSubtitle
		typeButtonText = settings.typeButtonText
		generateButtonText = settings.generateButtonText
		navLabels = settings.navLabels
		voiceEnabled = settings.voiceEnabled
	}

	func toAppSettings() -> AppSettings {
		AppSettings(
			greetingName: greetingName,
			greetingSubtitle: greetingSubtitle,
			trendingTitle: trendingTitle,
			trendingSubtitle: trendingSubtitle,
			typeButtonText: typeButtonText,
			generateButtonText: generateButtonText,
			navLabels: navLabels,
			voiceEnabled: voiceEnabled
		)
	}
}
