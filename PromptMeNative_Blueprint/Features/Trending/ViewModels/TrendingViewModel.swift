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

    /// Retained so Realtime-triggered refreshes can skip Railway entirely.
    private var storedSupabase: SupabaseClient?

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
	///   2. Fires a background refresh: Supabase table first, Railway as fallback.
	/// Subsequent calls are no-ops unless `refresh` is called explicitly.
    func loadIfNeeded(apiClient: any APIClientProtocol, supabase: SupabaseClient? = nil) async {
		guard catalog == nil else { return }
        if let supabase { storedSupabase = supabase }
		// Seed from bundle first so the view renders immediately even if the network is slow.
		loadBundledCatalog()
        await refresh(apiClient: apiClient, supabase: supabase)
	}

	/// Fetches the latest trending catalog.
	/// Priority: Supabase `trending_prompts` table → Railway API → silent fail (preserves bundle).
    func refresh(apiClient: any APIClientProtocol, supabase: SupabaseClient? = nil) async {
		isLoading = true
		errorMessage = nil
		defer { isLoading = false }

        let client = supabase ?? storedSupabase

        if let client {
            do {
                try await refreshFromSupabase(client)
                return   // ✅ Supabase succeeded — skip Railway entirely
            } catch {
                #if DEBUG
                print("⚠️ [Trending] Supabase fetch failed, falling back to Railway: \(error)")
                #endif
            }
        }

        // Fallback: Railway / bundle
		do {
			let data = try await apiClient.promptsTrending()
			catalog = data
		} catch {
			// Only surface the error if we have nothing to show.
			if catalog == nil {
				errorMessage = "Could not load trending prompts."
			}
		}
	}

    // MARK: - Supabase Direct Fetch

    /// Decodable shape for a single `trending_prompts` row.
    private struct TrendingRow: Decodable {
        let id: UUID
        let category: String
        let title: String
        let prompt: String
        let use_count: Int
    }

    /// Queries `trending_prompts` (WHERE is_active = true, ORDER BY use_count DESC)
    /// and rebuilds the `PromptCatalog` hierarchy in memory.
    private func refreshFromSupabase(_ supabase: SupabaseClient) async throws {
        let rows: [TrendingRow] = try await supabase
            .from("trending_prompts")
            .select("id, category, title, prompt, use_count")
            .eq("is_active", value: true)
            .order("use_count", ascending: false)
            .execute()
            .value

        // Group rows into categories, preserving server-side order.
        var categoryOrder: [String] = []
        var grouped: [String: [PromptItem]] = [:]

        for row in rows {
            let item = PromptItem(id: row.id.uuidString, title: row.title, prompt: row.prompt)
            let key = row.category.lowercased()
            if grouped[key] == nil {
                categoryOrder.append(key)
                grouped[key] = []
            }
            grouped[key]!.append(item)
        }

        let categories = categoryOrder.map { key in
            PromptCategory(
                key: key,
                name: key.prefix(1).uppercased() + key.dropFirst(),
                items: grouped[key] ?? []
            )
        }

        catalog = PromptCatalog(categories: categories)

        #if DEBUG
        print("✅ [Trending] Loaded \(rows.count) prompt(s) from Supabase across \(categories.count) category/categories")
        #endif
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
    /// When any INSERT or UPDATE arrives, re-fetches directly from the Supabase
    /// table (no Railway round-trip needed).
    ///
    /// - Parameters:
    ///   - supabase: The live SupabaseClient from `AppEnvironment`.
    ///   - apiClient: Railway fallback — used only if the Supabase re-fetch fails.
    func subscribeToRealtime(supabase: SupabaseClient, apiClient: any APIClientProtocol) {
        storedSupabase = supabase
        // Cancel any previous subscription before creating a new one
        realtimeTask?.cancel()

        realtimeTask = Task { [weak self] in
            guard let self else { return }

            let channel = supabase.channel("trending_prompts_live")

            // Listen for INSERT and UPDATE events on the trending_prompts table.
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

            try? await channel.subscribeWithError()

            await MainActor.run { self.isRealtimeConnected = true }

            #if DEBUG
            print("📡 [Trending] Realtime channel subscribed to trending_prompts")
            #endif

            // Fan-in both streams — re-fetch from Supabase on any change
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in insertions {
                        await MainActor.run {
                            _ = Task { await self.refresh(apiClient: apiClient, supabase: supabase) }
                        }
                        #if DEBUG
                        print("📡 [Trending] Realtime INSERT — refreshing from Supabase")
                        #endif
                    }
                }

                group.addTask {
                    for await _ in updates {
                        await MainActor.run {
                            _ = Task { await self.refresh(apiClient: apiClient, supabase: supabase) }
                        }
                        #if DEBUG
                        print("📡 [Trending] Realtime UPDATE — refreshing from Supabase")
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
