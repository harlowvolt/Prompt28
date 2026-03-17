import Foundation

struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String

    static let infoPlistURLKey = "SUPABASE_URL"
    static let infoPlistAnonKey = "SUPABASE_ANON_KEY"

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
}

