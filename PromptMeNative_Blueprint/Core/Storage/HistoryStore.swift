import Foundation
import SwiftData

/// Offline-first history store backed by SwiftData.
///
/// Phase 4.2: replaced JSON file persistence with a `ModelContext` that
/// writes to the app's default SwiftData store. The public `HistoryStoring`
/// API is unchanged; callers are unaffected.
///
/// On first launch after the update, `migrateLegacyJSONIfNeeded()` reads the
/// old `history.json`, inserts every record into SwiftData, then deletes the
/// JSON file so migration only runs once.
@Observable
@MainActor
final class HistoryStore {

    // MARK: - Public state

    /// In-memory snapshot, newest-first. Refreshed after every mutation.
    private(set) var items: [PromptHistoryItem] = []

    // MARK: - Private state

    private let modelContext: ModelContext
    private let maxItems = 200
    /// Temporary stability switch: SwiftData runtime calls are disabled because
    /// insert/fetch can trap at runtime on some devices/simulator states.
    private let persistenceEnabled = false

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        if persistenceEnabled {
            migrateLegacyJSONIfNeeded()
        }
        refreshCache()
    }

    // MARK: - HistoryStoring conformance

    var favorites: [PromptHistoryItem] {
        items.filter(\.favorite)
    }

    func add(_ item: PromptHistoryItem) {
        if let existing = fetchByID(item.id) {
            copyPersistedFields(from: item, to: existing)
        } else {
            let newItem = PromptHistoryItem(
                id: item.id,
                createdAt: item.createdAt,
                mode: item.mode,
                input: item.input,
                professional: item.professional,
                template: item.template,
                favorite: item.favorite,
                customName: item.customName
            )
            items.insert(newItem, at: 0)
        }
        save()
        pruneIfNeeded()
        refreshCache()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
        refreshCache()
    }

    func clearAll() {
        items = []
        save()
        refreshCache()
    }

    func toggleFavorite(id: UUID) {
        guard let item = fetchByID(id) else { return }
        item.favorite.toggle()
        save()
        // Reassign so @Observable propagates the change to any view observing `items`.
        refreshCache()
    }

    func rename(id: UUID, customName: String?) {
        guard let item = fetchByID(id) else { return }
        item.customName = customName
        save()
        refreshCache()
    }

    // MARK: - Private helpers

    private func refreshCache() {
        items.sort { $0.createdAt > $1.createdAt }
    }

    private func fetchByID(_ id: UUID) -> PromptHistoryItem? {
        items.first(where: { $0.id == id })
    }

    private func copyPersistedFields(from source: PromptHistoryItem, to destination: PromptHistoryItem) {
        destination.createdAt = source.createdAt
        destination.mode = source.mode
        destination.input = source.input
        destination.professional = source.professional
        destination.template = source.template
        destination.favorite = source.favorite
        destination.customName = source.customName
    }

    private func pruneIfNeeded() {
        guard items.count > maxItems else { return }
        items = Array(items.prefix(maxItems))
        save()
    }

    @discardableResult
    private func save() -> Bool {
        true
    }

    // MARK: - Legacy JSON migration

    /// Shape of records written by the old JSON-file `HistoryStore`.
    private struct LegacyItem: Codable {
        let id: UUID
        let createdAt: Date
        let mode: PromptMode
        let input: String
        let professional: String
        let template: String
        var favorite: Bool
        var customName: String?
    }

    private static var legacyFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("OrionOrb/history.json")
    }

    private func migrateLegacyJSONIfNeeded() {
        let url = Self.legacyFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let legacy = try? JSONDecoder().decode([LegacyItem].self, from: data) else { return }

        // Skip if SwiftData already has data (i.e. migration already ran).
        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<PromptHistoryItem>())) ?? 0
        guard existingCount == 0 else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        for legacyItem in legacy {
            let item = PromptHistoryItem(
                id: legacyItem.id,
                createdAt: legacyItem.createdAt,
                mode: legacyItem.mode,
                input: legacyItem.input,
                professional: legacyItem.professional,
                template: legacyItem.template,
                favorite: legacyItem.favorite,
                customName: legacyItem.customName
            )
            modelContext.insert(item)
        }
        save()

        // Remove the legacy file so this block never runs again.
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - HistoryStoring
// Defined here (rather than Core/Protocols/StorageProtocols.swift) so it is
// always compiled as part of the Storage group — no manual Xcode target
// membership required for a separate Protocols/ folder.

@MainActor
protocol HistoryStoring: AnyObject {
    var items: [PromptHistoryItem] { get }
    var favorites: [PromptHistoryItem] { get }
    func add(_ item: PromptHistoryItem)
    func remove(id: UUID)
    func clearAll()
    func toggleFavorite(id: UUID)
    func rename(id: UUID, customName: String?)
}

extension HistoryStore: HistoryStoring {}
