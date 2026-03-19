import Foundation
@preconcurrency import Supabase

enum TrendingCategory: String, CaseIterable {
	case all = "All"
	case school = "School"
	case work = "Work"
	case business = "Business"
	case fitness = "Fitness"
}

@Observable
@MainActor
final class TrendingViewModel {
	private(set) var catalog: PromptCatalog?
	private(set) var isLoading = false
	var errorMessage: String?
	var selectedCategory: TrendingCategory = .all

    // MARK: - Realtime

    /// Live indicator: true while the Supabase Realtime channel is connected.
    private(set) var isRealtimeConnected = false

    private var realtimeTask: Task<Void, Never>?

	// MARK: - Derived

	var categories: [PromptCategory] {
		catalog?.categories ?? []
	}

	var prompts: [PromptItem] {
		categories.flatMap(\.items)
	}

	var filteredPrompts: [PromptItem] {
		if selectedCategory == .all {
			return prompts
		}
		let key = selectedCategory.rawValue.lowercased()
		return categories
			.filter { $0.key.lowercased() == key }
			.flatMap(\.items)
	}

	func selectCategory(_ category: TrendingCategory) {
		selectedCategory = category
	}

	func promptItem(id: String) -> PromptItem? {
		prompts.first(where: { $0.id == id })
	}

	// MARK: - Load & Refresh

	/// Loads content for display. On the first call:
	///   1. Immediately populates the catalog from the bundled JSON (zero-latency).
	///   2. Fires a background API refresh to pull the latest server-side prompts.
	/// Subsequent calls are no-ops unless `refresh` is called explicitly.
	func loadIfNeeded(apiClient: any APIClientProtocol) async {
		guard catalog == nil else { return }
		// Seed from bundle first so the view renders immediately even if the API is slow.
		loadBundledCatalog()
		await refresh(apiClient: apiClient)
	}

	/// Fetches the latest trending catalog from the server.
	/// Updates `catalog` on success; preserves the existing (bundled or cached)
	/// catalog on failure so the view remains functional offline.
	func refresh(apiClient: any APIClientProtocol) async {
		isLoading = true
		errorMessage = nil
		defer { isLoading = false }

		do {
			let data = try await apiClient.promptsTrending()
			catalog = data
		} catch {
			// Only surface the error if we have nothing to show.
			// The bundled catalog will already be showing thanks to loadBundledCatalog().
			if catalog == nil {
				errorMessage = "Could not load trending prompts."
			}
		}
	}

	/// Synchronously loads `trending_prompts.json` from the app bundle.
	/// Used as a zero-latency seed before the network request returns.
	private func loadBundledCatalog() {
		guard catalog == nil,
			  let url = Bundle.main.url(forResource: "trending_prompts", withExtension: "json"),
			  let data = try? Data(contentsOf: url),
			  let loaded = try? JSONDecoder().decode(PromptCatalog.self, from: data)
		else { return }
		catalog = loaded
	}

    // MARK: - Supabase Realtime

    /// Subscribes to the `trending_prompts` Supabase channel.
    /// When any INSERT or UPDATE arrives, triggers a `refresh` so the UI
    /// reflects new curated prompts without requiring a manual pull-to-refresh.
    ///
    /// - Parameters:
    ///   - supabase: The live SupabaseClient from `AppEnvironment`.
    ///   - apiClient: Used to re-fetch the catalog on change events.
    func subscribeToRealtime(supabase: SupabaseClient, apiClient: any APIClientProtocol) {
        // Cancel any previous subscription before creating a new one
        realtimeTask?.cancel()

        realtimeTask = Task { [weak self] in
            guard let self else { return }

            let channel = supabase.channel("trending_prompts_live")

            // Listen for INSERT and UPDATE events on the trending_prompts table.
            // We don't need the payload — any change is enough to re-fetch.
            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table:  "trending_prompts"
            )

            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table:  "trending_prompts"
            )

            await channel.subscribe()

            await MainActor.run { self.isRealtimeConnected = true }

            #if DEBUG
            print("📡 [Trending] Realtime channel subscribed to trending_prompts")
            #endif

            // Fan-in both streams into one refresh trigger
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in insertions {
                        await MainActor.run {
                            Task { await self.refresh(apiClient: apiClient) }
                        }
                        #if DEBUG
                        print("📡 [Trending] Realtime INSERT detected — refreshing catalog")
                        #endif
                    }
                }

                group.addTask {
                    for await _ in updates {
                        await MainActor.run {
                            Task { await self.refresh(apiClient: apiClient) }
                        }
                        #if DEBUG
                        print("📡 [Trending] Realtime UPDATE detected — refreshing catalog")
                        #endif
                    }
                }
            }

            await channel.unsubscribe()
            await MainActor.run { self.isRealtimeConnected = false }

            #if DEBUG
            print("📡 [Trending] Realtime channel unsubscribed")
            #endif
        }
    }

    /// Cancels the active Realtime subscription.
    /// Call from `TrendingView.onDisappear` or when the scene goes to background.
    func unsubscribeFromRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        isRealtimeConnected = false
    }
}
