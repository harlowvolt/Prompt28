import Foundation
@preconcurrency import Supabase

/// Wrapper around the Supabase Swift SDK client.
/// Provides a centralized configuration point for Supabase services.
@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()
    
    /// The underlying Supabase client instance
    let client: Supabase.SupabaseClient
    
    /// Auth service for authentication operations
    var auth: AuthClient {
        client.auth
    }
    
    /// Database service for Supabase Postgres operations
    var database: PostgrestClient {
        client.database
    }
    
    /// Realtime service for live updates
    var realtime: RealtimeClient {
        client.realtime
    }
    
    /// Storage service for file operations
    var storage: SupabaseStorageClient {
        client.storage
    }
    
    /// Functions service for Edge Functions
    var functions: FunctionsClient {
        client.functions
    }
    
    private init() {
        // Supabase project configuration
        // These should be replaced with actual project credentials
        let supabaseURL = URL(string: "https://your-project.supabase.co")!
        let supabaseKey = "your-anon-public-key"
        
        self.client = Supabase.SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    /// Initialize with custom configuration (useful for testing)
    init(supabaseURL: URL, supabaseKey: String) {
        self.client = Supabase.SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
}

// MARK: - Supabase Auth Extensions

extension SupabaseClient {
    /// Get the current session if available
    var currentSession: Session? {
        get async throws {
            try await auth.session
        }
    }
    
    /// Get the current user if authenticated
    var currentUser: Supabase.User? {
        auth.currentUser
    }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }
}

// MARK: - Supabase Errors

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case sessionExpired
    case invalidCredentials
    case userNotFound
    case networkError(String)
    case serverError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .sessionExpired:
            return "Session expired. Please sign in again."
        case .invalidCredentials:
            return "Invalid email or password."
        case .userNotFound:
            return "User not found."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
