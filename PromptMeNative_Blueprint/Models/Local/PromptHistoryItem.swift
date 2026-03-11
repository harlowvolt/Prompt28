import Foundation

struct PromptHistoryItem: Codable, Identifiable, Equatable {
	let id: UUID
	let createdAt: Date
	let mode: PromptMode
	let input: String
	let professional: String
	let template: String
	var favorite: Bool
	var customName: String?

	init(
		id: UUID = UUID(),
		createdAt: Date = Date(),
		mode: PromptMode,
		input: String,
		professional: String,
		template: String,
		favorite: Bool = false,
		customName: String? = nil
	) {
		self.id = id
		self.createdAt = createdAt
		self.mode = mode
		self.input = input
		self.professional = professional
		self.template = template
		self.favorite = favorite
		self.customName = customName
	}
}
