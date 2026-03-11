import Foundation

@Observable
@MainActor
final class AuthManager {
    private(set) var currentUser: User?
    private(set) var token: String?
    var isBootstrapping = false
    var isAuthenticating = false
    var lastError: String?

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
            if let networkError = error as? NetworkError {
                if networkError.isSessionExpired {
                    lastError = "Session expired. Please sign in again."
                } else {
                    lastError = networkError.errorDescription
                }
            } else {
                lastError = error.localizedDescription
            }
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
            handleAuthFailure(error)
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
            handleAuthFailure(error)
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
            handleAuthFailure(error)
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
            handleAuthFailure(error)
        }
    }

    func refreshMe() async {
        guard let token else { return }

        do {
            currentUser = try await apiClient.me(token: token)
        } catch {
            if let networkError = error as? NetworkError, networkError.isSessionExpired {
                clearSession()
                lastError = "Session expired. Please sign in again."
            } else {
                if let networkError = error as? NetworkError {
                    lastError = networkError.errorDescription
                } else {
                    lastError = error.localizedDescription
                }
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

    private func handleAuthFailure(_ error: Error) {
        if let networkError = error as? NetworkError {
            if networkError.isSessionExpired {
                clearSession()
                lastError = "Session expired. Please sign in again."
            } else {
                lastError = networkError.errorDescription
            }
        } else {
            lastError = error.localizedDescription
        }
    }
}
