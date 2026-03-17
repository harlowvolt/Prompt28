import Foundation

struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String

    static let infoPlistURLKey = "SUPABASE_URL"
    static let infoPlistAnonKey = "SUPABASE_ANON_KEY"

    /// Loads config from Info.plist. Fatal-errors if keys are absent — use in production
    /// only once both `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set in Info.plist.
    static func load(from bundle: Bundle = .main) -> SupabaseConfig {
        guard let rawURL = bundle.object(forInfoDictionaryKey: infoPlistURLKey) as? String,
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: rawURL) else {
            fatalError("Missing or invalid \(infoPlistURLKey) in Info.plist.")
        }

        guard let anonKey = bundle.object(forInfoDictionaryKey: infoPlistAnonKey) as? String,
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("Missing \(infoPlistAnonKey) in Info.plist.")
        }

        return SupabaseConfig(url: url, anonKey: anonKey)
    }

    /// Non-fatal variant. Returns `nil` when either key is absent or malformed.
    /// Use during Phase 2 bootstrapping before Info.plist keys are populated.
    static func tryLoad(from bundle: Bundle = .main) -> SupabaseConfig? {
        guard let rawURL = bundle.object(forInfoDictionaryKey: infoPlistURLKey) as? String,
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: rawURL),
              let anonKey = bundle.object(forInfoDictionaryKey: infoPlistAnonKey) as? String,
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}

