import Foundation

// MARK: - Shared response types (used by admin endpoints and Edge Functions)

struct SuccessResponse: Codable {
	let success: Bool
}

struct AdminVerifyResponse: Codable {
	let ok: Bool
}

struct APIErrorResponse: Codable, Error {
	let error: String
	let upgrade: Bool?
	let plan: String?
	let prompts_remaining: Int?
}
