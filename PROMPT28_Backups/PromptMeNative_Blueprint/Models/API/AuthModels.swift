import Foundation

struct AuthResponse: Decodable {
	let token: String
	let user: User
}

struct RegisterRequest: Codable {
	let email: String
	let password: String
	let name: String?
}

struct LoginRequest: Codable {
	let email: String
	let password: String
}

struct GoogleAuthRequest: Codable {
	let credential: String
}

struct AppleAuthRequest: Codable {
	let identityToken: String
	let firstName: String?
	let lastName: String?
	let email: String?
}

struct AppConfigResponse: Codable {
	let googleClientId: String?
	let appleClientId: String?
	let apiUrl: String?
}

struct UpdatePlanRequest: Codable {
	let plan: PlanType
	let adminKey: String?
}

struct UpdatePlanResponse: Codable {
	let success: Bool
	let plan: PlanType
	let prompts_remaining: Int?
}

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
