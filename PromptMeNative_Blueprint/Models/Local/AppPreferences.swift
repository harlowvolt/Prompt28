import Foundation

struct AppPreferences: Codable, Equatable {
	var saveHistory: Bool
	var aiModeDefault: Bool
	var selectedMode: PromptMode
	var hasAcceptedAIConsent: Bool

	static let `default` = AppPreferences(
		saveHistory: true,
		aiModeDefault: true,
		selectedMode: .ai,
		hasAcceptedAIConsent: false
	)
}
