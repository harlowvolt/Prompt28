import Foundation
@preconcurrency import Supabase
import AuthenticationServices

/// Authentication manager using Supabase Auth.
/// Handles email/password, Google Sign-In, and Apple Sign-In authentication.
@Observable
@MainActor
final class AuthManager {
    private(set) var currentUser: User?
    private(set) var token: String?
    var isBootstrapping = false
    var isAuthenticating = false
    var lastError: String?
    
    /// The Supabase client for auth operations
    private let supabase: SupabaseClient
    
    /// Legacy API client for backward compatibility with Railway API
    private let apiClient: APIClient
    
    /// Keychain service for secure token storage
    private let keychain: KeychainService
    
    /// Auth state change listener task
    private var authStateTask: Task<Void, Never>?
    
    private let tokenKey = "orionorb_token"
    private let refreshTokenKey = "orionorb_refresh_token"
    
    init(supabase: SupabaseClient, apiClient: APIClient, keychain: KeychainService) {
        self.supabase = supabase
        self.apiClient = apiClient
        self.keychain = keychain
        
        // Load existing session
        self.token = keychain.get(tokenKey)
        
        // Start listening for auth state changes
        startAuthStateListener()
    }
    
    deinit {
        // The auth state listener task will be cancelled when the task is deallocated
    }
    
    var isAuthenticated: Bool {
        token != nil && currentUser != nil
    }
    
    // MARK: - Bootstrap
    
    /// Bootstrap the auth state on app launch
    /// Attempts to restore the existing session from Supabase
    func bootstrap() async {
        isBootstrapping = true
        lastError = nil
        defer { isBootstrapping = false }
        
        do {
            // Try to restore session from Supabase
            let session = try await supabase.auth.session
            await handleSuccessfulAuth(session: session)
        } catch {
            // No valid session found
            clearSession()
        }
    }
    
    // MARK: - Auth State Listener
    
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await (event, session) in supabase.auth.authStateChanges {
                await self.handleAuthStateChange(event: event, session: session)
            }
        }
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            if let session = session {
                await handleSuccessfulAuth(session: session)
            }
        case .signedOut:
            clearSession()
        case .tokenRefreshed:
            if let session = session {
                await handleSuccessfulAuth(session: session)
            }
        case .userUpdated:
            if let session = session {
                await handleSuccessfulAuth(session: session)
            }
        case .userDeleted:
            clearSession()
        case .passwordRecovery:
            // Handle password recovery if needed
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Email/Password Auth
    
    func register(email: String, password: String, name: String?) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }
        
        do {
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: name != nil ? ["full_name": AnyJSON.string(name!)] : nil
            )
            
            // After sign up, the session might be nil if email confirmation is required
            if let session = authResponse.session {
                await handleSuccessfulAuth(session: session)
            }
        } catch {
            handleAuthFailure(error)
        }
    }
    
    func login(email: String, password: String) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            await handleSuccessfulAuth(session: session)
        } catch {
            handleAuthFailure(error)
        }
    }
    
    // MARK: - Google Sign-In
    
    func loginWithGoogle(credential: String) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }
        
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: credential
                )
            )
            
            await handleSuccessfulAuth(session: session)
        } catch {
            handleAuthFailure(error)
        }
    }
    
    // MARK: - Apple Sign-In
    
    func loginWithApple(identityToken: String, firstName: String?, lastName: String?, email: String?) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }
        
        do {
            // Build full name if available
            var fullName: String?
            if let firstName = firstName {
                fullName = firstName
                if let lastName = lastName {
                    fullName = "\(firstName) \(lastName)"
                }
            }
            
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityToken
                )
            )
            
            // Update user metadata with name if provided (Apple only sends this on first sign-in)
            if let fullName = fullName {
                try? await supabase.auth.update(user: UserAttributes(
                    data: ["full_name": AnyJSON.string(fullName)]
                ))
            }
            
            await handleSuccessfulAuth(session: session)
        } catch {
            handleAuthFailure(error)
        }
    }
    
    // MARK: - Session Management
    
    func refreshMe() async {
        do {
            let session = try await supabase.auth.session
            await handleSuccessfulAuth(session: session)
        } catch {
            if isSessionExpiredError(error) {
                clearSession()
                lastError = "Session expired. Please sign in again."
            } else {
                lastError = error.localizedDescription
            }
        }
    }
    
    func logout() {
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                // Still clear local session even if server sign-out fails
            }
            clearSession()
        }
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - Private Helpers
    
    private func handleSuccessfulAuth(session: Session) async {
        // Store tokens in keychain
        do {
            try keychain.set(session.accessToken, for: tokenKey)
            // refreshToken is non-optional in Supabase Session
            try keychain.set(session.refreshToken, for: refreshTokenKey)
        } catch {
            lastError = "Failed to save session"
            return
        }
        
        self.token = session.accessToken
        
        // Convert Supabase user to app User model
        // For now, default to starter plan - plan sync happens via StoreManager
        let appUser = convertSupabaseUserToAppUser(session.user, plan: .starter)
        self.currentUser = appUser
        
        // Track auth success
        AnalyticsService.shared.track(.authSuccess(provider: appUser.provider))
        AnalyticsService.shared.setUserId(appUser.id)
        TelemetryService.shared.setUserId(appUser.id)
        
        // Sync with server for plan info (backward compatibility)
        await syncUserWithServer()
    }
    
    /// Convert Supabase User to app User model
    private func convertSupabaseUserToAppUser(_ supabaseUser: Supabase.User, plan: PlanType) -> User {
        let metadata = supabaseUser.userMetadata
        
        // Extract name from user metadata or email
        let name = metadata["full_name"] as? String
            ?? metadata["name"] as? String
            ?? supabaseUser.email?.components(separatedBy: "@").first
            ?? "User"
        
        // Extract provider from app metadata
        let provider = (supabaseUser.appMetadata["provider"] as? String) ?? "email"
        
        return User(
            id: supabaseUser.id.uuidString,
            email: supabaseUser.email ?? "",
            name: name,
            provider: provider,
            plan: plan,
            prompts_used: 0,
            prompts_remaining: nil,
            period_end: ""
        )
    }
    
    private func syncUserWithServer() async {
        // Fetch full user profile from Railway API for plan information
        // This maintains backward compatibility during migration
        guard let token = token else { return }
        
        do {
            let serverUser = try await apiClient.me(token: token)
            // Update only the plan-related fields from server
            if let currentUser = currentUser {
                let updatedUser = User(
                    id: currentUser.id,
                    email: currentUser.email,
                    name: currentUser.name,
                    provider: currentUser.provider,
                    plan: serverUser.plan,
                    prompts_used: serverUser.prompts_used,
                    prompts_remaining: serverUser.prompts_remaining,
                    period_end: serverUser.period_end
                )
                self.currentUser = updatedUser
            }
        } catch {
            // Silently fail - user can still use app with local auth
            // Plan info will sync on next refreshMe() call
        }
    }
    
    private func clearSession() {
        keychain.delete(tokenKey)
        keychain.delete(refreshTokenKey)
        token = nil
        currentUser = nil
    }
    
    private func handleAuthFailure(_ error: Error) {
        if let authError = error as? AuthError {
            switch authError {
            case .api(let apiError):
                lastError = apiError.message
            case .sessionNotFound:
                lastError = "Session expired. Please sign in again."
            default:
                lastError = error.localizedDescription
            }
        } else {
            lastError = error.localizedDescription
        }
        
        // Track auth failure
        TelemetryService.shared.logAuthError(
            code: "AUTH_FAILED",
            message: lastError ?? "Unknown auth error"
        )
    }
    
    private func isSessionExpiredError(_ error: Error) -> Bool {
        if let authError = error as? AuthError {
            if case .sessionNotFound = authError {
                return true
            }
        }
        return false
    }
}
