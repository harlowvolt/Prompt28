import Foundation

final class APIClient {
    private let session: URLSession
    private let builder: RequestBuilder
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.session = session
        self.builder = RequestBuilder(baseURL: baseURL)
        self.decoder = JSONDecoder()
    }

    func send<T: Decodable>(
        _ endpoint: APIEndpoint,
        bearerToken: String? = nil,
        adminKey: String? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try builder.build(endpoint: endpoint, bearerToken: bearerToken, adminKey: adminKey)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let nsError = error as NSError
            // Log transport errors to telemetry (fire-and-forget, main-actor hop).
            Task { @MainActor in
                TelemetryService.shared.logNetworkError(
                    code: "\(nsError.code)",
                    message: error.localizedDescription,
                    url: request.url?.absoluteString
                )
            }
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                throw NetworkError.transport(message: "The server took too long to respond. Please try again.")
            }
            throw NetworkError.transport(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.transport(message: "Invalid HTTP response.")
        }

        if (200...299).contains(httpResponse.statusCode) {
            do {
                return try decoder.decode(type, from: data)
            } catch {
                Task { @MainActor in
                    TelemetryService.shared.logAPIError(
                        code: "DECODE_ERROR",
                        message: "Failed to decode response: \(error.localizedDescription)",
                        endpoint: request.url?.path
                    )
                }
                throw NetworkError.decoding
            }
        }

        let apiError = try? decoder.decode(APIErrorResponse.self, from: data)
        let fallbackMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        let message = apiError?.error ?? fallbackMessage

        // Log API-level errors by status code.
        Task { @MainActor in
            TelemetryService.shared.logAPIError(
                code: "HTTP_\(httpResponse.statusCode)",
                message: message,
                endpoint: request.url?.path
            )
        }

        switch httpResponse.statusCode {
        case 401:
            let isSessionScoped = endpoint.auth != .none
            let defaultMessage = isSessionScoped
                ? "Session expired. Please sign in again."
                : "Invalid email or password."
            throw NetworkError.unauthorized(
                message: apiError?.error ?? defaultMessage,
                sessionExpired: isSessionScoped
            )
        case 403:
            throw NetworkError.forbidden(message: message)
        case 404:
            throw NetworkError.notFound(message: message)
        case 429:
            throw NetworkError.rateLimited(message: message)
        default:
            throw NetworkError.server(message: message)
        }
    }

    func sendVoid(
        _ endpoint: APIEndpoint,
        bearerToken: String? = nil,
        adminKey: String? = nil
    ) async throws {
        _ = try await send(endpoint, bearerToken: bearerToken, adminKey: adminKey, as: SuccessResponse.self)
    }

    // MARK: Auth

    func register(_ request: RegisterRequest) async throws -> AuthResponse {
        try await send(.register(request), as: AuthResponse.self)
    }

    func login(_ request: LoginRequest) async throws -> AuthResponse {
        try await send(.login(request), as: AuthResponse.self)
    }

    func googleAuth(_ request: GoogleAuthRequest) async throws -> AuthResponse {
        try await send(.googleAuth(request), as: AuthResponse.self)
    }

    func appleAuth(_ request: AppleAuthRequest) async throws -> AuthResponse {
        try await send(.appleAuth(request), as: AuthResponse.self)
    }

    // MARK: User

    func me(token: String) async throws -> User {
        try await send(.me, bearerToken: token, as: User.self)
    }

    func updatePlan(_ request: UpdatePlanRequest, token: String) async throws -> UpdatePlanResponse {
        try await send(.updatePlan(request), bearerToken: token, as: UpdatePlanResponse.self)
    }

    func deleteUser(token: String) async throws -> SuccessResponse {
        try await send(.deleteUser, bearerToken: token, as: SuccessResponse.self)
    }

    func resetUsage(token: String) async throws -> SuccessResponse {
        try await send(.resetUsage, bearerToken: token, as: SuccessResponse.self)
    }

    // MARK: Generation

    func generate(_ request: GenerateRequest, token: String) async throws -> GenerateResponse {
        try await send(.generate(request), bearerToken: token, as: GenerateResponse.self)
    }

    // MARK: Config

    func config() async throws -> AppConfigResponse {
        try await send(.config, as: AppConfigResponse.self)
    }

    func settings() async throws -> AppSettings {
        try await send(.settings, as: AppSettings.self)
    }

    func promptsTrending() async throws -> PromptCatalog {
        try await send(.promptsTrending, as: PromptCatalog.self)
    }

    // MARK: Admin

    func adminVerify(key: String) async throws -> AdminVerifyResponse {
        try await send(.adminVerify(adminKey: key), adminKey: key, as: AdminVerifyResponse.self)
    }

    func adminSettings(key: String) async throws -> AppSettings {
        try await send(.adminSettings, adminKey: key, as: AppSettings.self)
    }

    func adminUpdateSettings(key: String, payload: [String: Any]) async throws -> SuccessResponse {
        try await send(.adminUpdateSettings(payload: payload), adminKey: key, as: SuccessResponse.self)
    }

    func adminPrompts(key: String) async throws -> PromptCatalog {
        try await send(.adminPrompts, adminKey: key, as: PromptCatalog.self)
    }

    func adminUpdatePrompts(key: String, catalog: PromptCatalog) async throws -> SuccessResponse {
        try await send(.adminUpdatePrompts(catalog), adminKey: key, as: SuccessResponse.self)
    }
}

// MARK: - Conformance
// APIClientProtocol is defined in Core/Protocols/APIClientProtocol.swift.
extension APIClient: APIClientProtocol {}
