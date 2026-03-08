import Foundation

enum PlanType: String, Codable, CaseIterable {
	case starter
	case pro
	case unlimited
	case dev
}

struct User: Codable, Identifiable, Equatable {
	let id: String
	let email: String
	let name: String
	let provider: String
	let plan: PlanType
	let prompts_used: Int
	let prompts_remaining: Int?
	let period_end: String
}
