import Foundation

struct PromptCatalog: Codable, Equatable {
	var categories: [PromptCategory]
}

struct PromptCategory: Codable, Identifiable, Equatable {
	var id: String { key }
	let key: String
	var name: String
	var items: [PromptItem]
}

struct PromptItem: Codable, Identifiable, Equatable {
	let id: String
	var title: String
	var prompt: String
}
