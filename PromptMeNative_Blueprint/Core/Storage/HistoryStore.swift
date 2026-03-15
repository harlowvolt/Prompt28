import Foundation

/// History store with CloudKit sync and JSON local persistence.
///
/// Phase 2: Migrated from SwiftData to Codable JSON + CloudKit.
/// - Local persistence: Codable JSON file
/// - Cloud sync: CloudKitService for cross-device sync
/// - Conflict resolution: Last modified wins
@Observable
@MainActor
final class HistoryStore {
    
    // MARK: - Public state
    
    /// In-memory snapshot, newest-first. Refreshed after every mutation.
    private(set) var items: [PromptHistoryItem] = []
    
    /// CloudKit sync status
    private(set) var isSyncing: Bool = false
    
    /// Last sync error (if any)
    private(set) var lastSyncError: Error?
    
    // MARK: - Private state
    
    private let cloudKitService: CloudKitService
    private let maxItems = 200
    private let fileURL: URL
    private var syncTask: Task<Void, Never>?
    
    // MARK: - Init
    
    init(cloudKitService: CloudKitService) {
        self.cloudKitService = cloudKitService
        
        // Set up file URL for local JSON persistence
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = base.appendingPathComponent("OrionOrb", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.fileURL = appDir.appendingPathComponent("history.json")
        
        // Load from disk
        loadFromDisk()
        
        // Migrate legacy data if present
        migrateLegacyJSONIfNeeded()
        
        // Initial CloudKit sync
        Task {
            await syncWithCloud()
        }
    }
    
    // MARK: - HistoryStoring conformance
    
    var favorites: [PromptHistoryItem] {
        items.filter(\.favorite)
    }
    
    func add(_ item: PromptHistoryItem) {
        item.markModified() // Update lastModified timestamp
        
        if let existing = fetchByID(item.id) {
            copyPersistedFields(from: item, to: existing)
            existing.markModified()
        } else {
            items.insert(item, at: 0)
        }
        
        saveToDisk()
        pruneIfNeeded()
        refreshCache()
        
        // Trigger CloudKit sync
        syncWithCloud()
    }
    
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        saveToDisk()
        refreshCache()
        
        // Delete from CloudKit
        Task {
            do {
                try await cloudKitService.deleteFromCloud(id: id)
            } catch {
                // Silently fail - item will be re-synced later if needed
                #if DEBUG
                print("⚠️ [HistoryStore] Failed to delete from CloudKit: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    func clearAll() {
        items = []
        saveToDisk()
        refreshCache()
        
        // Note: We're not deleting from CloudKit here to prevent accidental data loss
        // A separate "clear cloud data" function could be added if needed
    }
    
    func toggleFavorite(id: UUID) {
        guard let item = fetchByID(id) else { return }
        item.favorite.toggle()
        item.markModified()
        saveToDisk()
        refreshCache()
        syncWithCloud()
    }
    
    func rename(id: UUID, customName: String?) {
        guard let item = fetchByID(id) else { return }
        item.customName = customName
        item.markModified()
        saveToDisk()
        refreshCache()
        syncWithCloud()
    }
    
    // MARK: - CloudKit Sync
    
    /// Sync local items with CloudKit (two-way sync)
    func syncWithCloud() {
        // Cancel any pending sync
        syncTask?.cancel()
        
        syncTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Debounce: wait 2 seconds before syncing
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            await performSync()
        }
    }
    
    /// Perform the actual sync operation
    private func performSync() async {
        guard cloudKitService.isCloudKitAvailable else {
            #if DEBUG
            print("⚠️ [HistoryStore] CloudKit not available, skipping sync")
            #endif
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let syncedItems = try await cloudKitService.sync(items: items)
            
            // Update local items with merged results
            items = syncedItems
            refreshCache()
            saveToDisk()
            
            lastSyncError = nil
            
            #if DEBUG
            print("☁️ [HistoryStore] Synced \(items.count) items with CloudKit")
            #endif
            
        } catch {
            lastSyncError = error
            
            #if DEBUG
            print("❌ [HistoryStore] CloudKit sync failed: \(error.localizedDescription)")
            #endif
            
            // Silently fail - data is still saved locally
            // Will retry on next mutation
        }
    }
    
    /// Force immediate sync (for manual pull-to-refresh)
    func forceSync() async {
        syncTask?.cancel()
        await performSync()
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
        destination.recordID = source.recordID
    }
    
    private func pruneIfNeeded() {
        guard items.count > maxItems else { return }
        items = Array(items.prefix(maxItems))
        saveToDisk()
    }
    
    // MARK: - Local Persistence (Codable JSON)
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
            
            #if DEBUG
            print("💾 [HistoryStore] Saved \(items.count) items to disk")
            #endif
        } catch {
            #if DEBUG
            print("❌ [HistoryStore] Failed to save: \(error.localizedDescription)")
            #endif
            
            TelemetryService.shared.logStorageError(
                code: "SAVE_FAILED",
                message: "Failed to save history: \(error.localizedDescription)"
            )
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            items = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([PromptHistoryItem].self, from: data)
            
            #if DEBUG
            print("💾 [HistoryStore] Loaded \(items.count) items from disk")
            #endif
        } catch {
            #if DEBUG
            print("❌ [HistoryStore] Failed to load: \(error.localizedDescription)")
            #endif
            items = []
        }
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
              let legacy = try? JSONDecoder().decode([LegacyItem].self, from: data),
              !legacy.isEmpty,
              items.isEmpty else { return }
        
        // Convert legacy items to new format
        let migratedItems = legacy.map { legacyItem in
            PromptHistoryItem(
                id: legacyItem.id,
                createdAt: legacyItem.createdAt,
                mode: legacyItem.mode,
                input: legacyItem.input,
                professional: legacyItem.professional,
                template: legacyItem.template,
                favorite: legacyItem.favorite,
                customName: legacyItem.customName,
                recordID: nil,
                lastModified: legacyItem.createdAt,
                isSynced: false
            )
        }
        
        items = migratedItems
        saveToDisk()
        
        #if DEBUG
        print("🔄 [HistoryStore] Migrated \(migratedItems.count) legacy items")
        #endif
        
        // Sync migrated items to CloudKit
        syncWithCloud()
    }
}

