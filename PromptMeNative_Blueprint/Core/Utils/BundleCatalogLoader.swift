import Foundation

/// Loads the bundled `trending_prompts.json` that ships with the app.
///
/// This enables zero-latency Trending content on first launch and serves
/// as a fallback when the device has no network connectivity.
enum BundleCatalogLoader {

    /// Returns the `PromptCatalog` decoded from `Resources/trending_prompts.json`
    /// in the main bundle, or `nil` if the file is missing or malformed.
    static func loadTrendingCatalog() -> PromptCatalog? {
        guard let url = Bundle.main.url(forResource: "trending_prompts", withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PromptCatalog.self, from: data)
    }
}
