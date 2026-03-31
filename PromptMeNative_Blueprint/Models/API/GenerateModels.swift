import Foundation

enum PromptMode: String, Codable, CaseIterable {
	case ai
	case human
}

/// The target AI platform — used to tune prompt style & phrasing in the Edge Function.
enum TargetPlatform: String, Codable, CaseIterable, Identifiable {
    case claude   = "claude"
    case chatgpt  = "chatgpt"
    case gemini   = "gemini"
    case grok     = "grok"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .chatgpt: return "ChatGPT"
        case .gemini:  return "Gemini"
        case .grok:    return "Grok"
        }
    }

    /// Accent colour for each platform's indicator dot.
    var accentHex: String {
        switch self {
        case .claude:  return "#8B8FFF"
        case .chatgpt: return "#19C37D"
        case .gemini:  return "#4A9EFF"
        case .grok:    return "#A78BFA"
        }
    }
}

struct GenerateRequest: Codable {
	let input: String
	let refinement: String?
	let mode: PromptMode
    let platform: TargetPlatform?
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
    // Phase 5 MCP: true when a Brave Search web snippet was injected as grounding context
    let web_context_used: Bool?
}
