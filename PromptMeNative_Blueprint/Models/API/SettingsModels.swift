import Foundation

struct NavLabels: Codable, Equatable {
	let home: String?
	let favorites: String?
	let history: String?
	let trending: String?
}

struct AppSettings: Codable, Equatable {
	let greetingName: String?
	let greetingSubtitle: String?
	let trendingTitle: String?
	let trendingSubtitle: String?
	let typeButtonText: String?
	let generateButtonText: String?
	let navLabels: NavLabels?
	let voiceEnabled: Bool?

	static let `default` = AppSettings(
		greetingName: nil,
		greetingSubtitle: nil,
		trendingTitle: nil,
		trendingSubtitle: nil,
		typeButtonText: nil,
		generateButtonText: nil,
		navLabels: nil,
		voiceEnabled: true
	)
}
