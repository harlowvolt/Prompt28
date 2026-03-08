import Foundation

enum PromptMode: String, Codable, CaseIterable {
	case ai
	case human
}

struct GenerateRequest: Codable {
	let input: String
	let refinement: String?
	let mode: PromptMode
}

struct GenerateResponse: Codable, Equatable {
	let professional: String
	let template: String
	let prompts_used: Int
	let prompts_remaining: Int?
	let plan: PlanType
}
