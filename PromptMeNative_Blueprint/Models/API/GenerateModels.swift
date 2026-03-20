import Foundation

enum PromptMode: String, Codable, CaseIterable {
	case ai
	case human
}

struct GenerateRequest: Codable {
	let input: String
	let refinement: String?
	let mode: PromptMode
	let systemPrompt: String?
}

struct GenerateResponse: Codable, Equatable {
	let professional: String
	let template: String
	let prompts_used: Int
	let prompts_remaining: Int?
	let plan: PlanType
    // Intent classifier output — nil when running against an older deployed Edge Function
    let intent_category: String?
    // Total server-side generation latency — nil when running against an older deployed Edge Function
    let latency_ms: Int?
}
