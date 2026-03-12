import Foundation

/// Protocol describing the full API surface consumed by ViewModels and services.
/// Conforming `APIClient` to this protocol allows ViewModels to depend on the
/// abstraction rather than the concrete network layer, enabling test-double injection.
protocol APIClientProtocol: AnyObject {

    // MARK: Auth
    func register(_ request: RegisterRequest) async throws -> AuthResponse
    func login(_ request: LoginRequest) async throws -> AuthResponse
    func googleAuth(_ request: GoogleAuthRequest) async throws -> AuthResponse
    func appleAuth(_ request: AppleAuthRequest) async throws -> AuthResponse

    // MARK: User
    func me(token: String) async throws -> User
    func updatePlan(_ request: UpdatePlanRequest, token: String) async throws -> UpdatePlanResponse
    func deleteUser(token: String) async throws -> SuccessResponse
    func resetUsage(token: String) async throws -> SuccessResponse

    // MARK: Generation
    func generate(_ request: GenerateRequest, token: String) async throws -> GenerateResponse

    // MARK: Config
    func config() async throws -> AppConfigResponse
    func settings() async throws -> AppSettings
    func promptsTrending() async throws -> PromptCatalog

    // MARK: Admin
    func adminVerify(key: String) async throws -> AdminVerifyResponse
    func adminSettings(key: String) async throws -> AppSettings
    func adminUpdateSettings(key: String, payload: [String: Any]) async throws -> SuccessResponse
    func adminPrompts(key: String) async throws -> PromptCatalog
    func adminUpdatePrompts(key: String, catalog: PromptCatalog) async throws -> SuccessResponse
}

// MARK: - Conformance
extension APIClient: APIClientProtocol {}
