import Combine
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [PromptHistoryItem] = []

    private let maxItems = 200
    private static let storageDirectoryURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("PromptMeNative", isDirectory: true)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
    private let fileURL: URL

    init() {
        fileURL = Self.storageDirectoryURL.appendingPathComponent("history.json")
        load()
    }

    var favorites: [PromptHistoryItem] {
        items.filter(\.favorite)
    }

    func add(_ item: PromptHistoryItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        persist()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        items = []
        persist()
    }

    func toggleFavorite(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].favorite.toggle()
        persist()
    }

    func rename(id: UUID, customName: String?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].customName = customName
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PromptHistoryItem].self, from: data) else {
            items = []
            return
        }

        items = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
