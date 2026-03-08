import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var token: String?
    @Published var isBootstrapping = false
    @Published var isAuthenticating = false
    @Published var lastError: String?

    private let apiClient: APIClient
    private let keychain: KeychainService

    private let tokenKey = "promptme_token"

    init(apiClient: APIClient, keychain: KeychainService) {
        self.apiClient = apiClient
        self.keychain = keychain
        self.token = keychain.get(tokenKey)
    }

    var isAuthenticated: Bool {
        token != nil && currentUser != nil
    }

    func bootstrap() async {
        guard let token = keychain.get(tokenKey), !token.isEmpty else {
            self.token = nil
            self.currentUser = nil
            return
        }

        isBootstrapping = true
        lastError = nil
        defer { isBootstrapping = false }

        do {
            let user = try await apiClient.me(token: token)
            self.token = token
            self.currentUser = user
        } catch {
            clearSession()
        }
    }

    func register(email: String, password: String, name: String?) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let response = try await apiClient.register(RegisterRequest(email: email, password: password, name: name))
            try storeSession(response)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let response = try await apiClient.login(LoginRequest(email: email, password: password))
            try storeSession(response)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loginWithGoogle(credential: String) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let response = try await apiClient.googleAuth(GoogleAuthRequest(credential: credential))
            try storeSession(response)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loginWithApple(identityToken: String, firstName: String?, lastName: String?, email: String?) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let request = AppleAuthRequest(identityToken: identityToken, firstName: firstName, lastName: lastName, email: email)
            let response = try await apiClient.appleAuth(request)
            try storeSession(response)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshMe() async {
        guard let token else { return }

        do {
            currentUser = try await apiClient.me(token: token)
        } catch {
            if case NetworkError.unauthorized = error {
                clearSession()
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func logout() {
        clearSession()
    }

    private func storeSession(_ auth: AuthResponse) throws {
        try keychain.set(auth.token, for: tokenKey)
        token = auth.token
        currentUser = auth.user
    }

    private func clearSession() {
        keychain.delete(tokenKey)
        token = nil
        currentUser = nil
    }
}
