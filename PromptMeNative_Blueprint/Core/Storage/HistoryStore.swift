import Foundation
import SwiftData

/// Offline-first history store backed by a JSON file.
///
/// SwiftData persistence was disabled after runtime traps on some
/// simulator/device states (see post-closeout incident in HANDOFF.md).
/// This implementation restores persistence via a plain JSON file in the
/// app's Application Support directory — the same location used by the
/// legacy migration path, but now as the primary storage layer.
///
/// The public `HistoryStoring` API is unchanged; callers are unaffected.
@Observable
@MainActor
final class HistoryStore {

    // MARK: - Public state

    /// In-memory snapshot, newest-first. Refreshed after every mutation.
    private(set) var items: [PromptHistoryItem] = []

    // MARK: - Private state

    private let modelContext: ModelContext
    private let maxItems = 200

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFromDisk()
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
        pruneIfNeeded()
        saveToDisk()
        refreshCache()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        saveToDisk()
        refreshCache()
    }

    func clearAll() {
        items = []
        saveToDisk()
        refreshCache()
    }

    func toggleFavorite(id: UUID) {
        guard let item = fetchByID(id) else { return }
        item.favorite.toggle()
        saveToDisk()
        // Reassign so @Observable propagates the change to any view observing `items`.
        refreshCache()
    }

    func rename(id: UUID, customName: String?) {
        guard let item = fetchByID(id) else { return }
        item.customName = customName
        saveToDisk()
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
    }

    // MARK: - JSON persistence

    /// Codable mirror of `PromptHistoryItem` for JSON serialisation.
    /// Using a separate struct avoids coupling the `@Model` class to Codable.
    private struct PersistedItem: Codable {
        let id: UUID
        let createdAt: Date
        let mode: PromptMode
        let input: String
        let professional: String
        let template: String
        var favorite: Bool
        var customName: String?
    }

    private static var jsonFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Prompt28", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    private func loadFromDisk() {
        let url = Self.jsonFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let persisted = try? JSONDecoder().decode([PersistedItem].self, from: data)
        else { return }

        items = persisted.map { p in
            PromptHistoryItem(
                id: p.id,
                createdAt: p.createdAt,
                mode: p.mode,
                input: p.input,
                professional: p.professional,
                template: p.template,
                favorite: p.favorite,
                customName: p.customName
            )
        }
    }

    @discardableResult
    private func saveToDisk() -> Bool {
        let persisted = items.map { item in
            PersistedItem(
                id: item.id,
                createdAt: item.createdAt,
                mode: item.mode,
                input: item.input,
                professional: item.professional,
                template: item.template,
                favorite: item.favorite,
                customName: item.customName
            )
        }
        guard let data = try? JSONEncoder().encode(persisted) else { return false }
        do {
            try data.write(to: Self.jsonFileURL, options: .atomic)
            return true
        } catch {
            return false
        }
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
