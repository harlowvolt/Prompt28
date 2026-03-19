import Foundation
@preconcurrency import Supabase
#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol HistoryStoring: AnyObject {
    var items: [PromptHistoryItem] { get }
    func add(_ item: PromptHistoryItem)
    func remove(id: UUID)
    func clearAll()
    func toggleFavorite(id: UUID)
    func rename(id: UUID, customName: String?)
}

// MARK: - Supabase DTO

/// Snake_case–keyed Codable struct for inserting / selecting rows in the
/// Supabase `prompts` table.
///
/// Keeps `PromptHistoryItem` (the domain model) free of server-side naming
/// conventions. The `userId` field is only populated on insert — remote
/// records returned by SELECT already carry it, so decoding works symmetrically.
private struct PromptRecord: Codable {
    let id: UUID
    let userId: UUID
    let createdAt: Date
    let mode: String          // PromptMode.rawValue
    let input: String
    let professional: String
    let template: String
    let favorite: Bool
    let customName: String?
    let lastModified: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case createdAt    = "created_at"
        case mode
        case input
        case professional
        case template
        case favorite
        case customName   = "custom_name"
        case lastModified = "last_modified"
    }

    /// Build a `PromptRecord` from a local `PromptHistoryItem` ready for upsert.
    init(item: PromptHistoryItem, userId: UUID) {
        self.id           = item.id
        self.userId       = userId
        self.createdAt    = item.createdAt
        self.mode         = item.mode.rawValue
        self.input        = item.input
        self.professional = item.professional
        self.template     = item.template
        self.favorite     = item.favorite
        self.customName   = item.customName
        self.lastModified = item.lastModified
    }

    /// Convert a remote record back into a local `PromptHistoryItem`.
    func toHistoryItem() -> PromptHistoryItem {
        PromptHistoryItem(
            id:           id,
            createdAt:    createdAt,
            mode:         PromptMode(rawValue: mode) ?? .ai,
            input:        input,
            professional: professional,
            template:     template,
            favorite:     favorite,
            customName:   customName,
            lastModified: lastModified,
            isSynced:     true
        )
    }
}

extension HistoryStore: HistoryStoring {}

// MARK: - HistoryStore

/// Local-first history store with Supabase cloud sync.
///
/// Storage strategy:
/// - **Local**: Codable JSON file in Application Support (survives offline use).
/// - **Cloud**: Supabase `prompts` table — synced automatically when the user
///   signs in via the Supabase auth-state listener, and on demand via
///   `syncWithSupabase(userId:)`.
///   Conflict resolution: `lastModified` drives last-write-wins.
///   `isSynced` flags records that still need to be upserted.
///
/// Note: CloudKit has been removed. Do not reintroduce it.
@Observable
@MainActor
final class HistoryStore {

    // MARK: - Public state

    /// In-memory snapshot, newest-first. Updated after every local mutation
    /// and after each successful Supabase sync.
    private(set) var items: [PromptHistoryItem] = []

    /// `true` while a Supabase sync is in flight.
    private(set) var isSyncing: Bool = false

    /// Last sync error (non-fatal — data is still available locally).
    private(set) var lastSyncError: Error?

    // MARK: - Private

    private let supabase: SupabaseClient
    private let fileURL: URL
    private let pendingDeletesURL: URL
    private let maxItems = 200
    private var pendingDeletedIDs: Set<UUID> = []
    private let sessionUserIDProvider: (() async -> UUID?)?
    private let syncExecutor: ((UUID) async -> Void)?
    #if canImport(UIKit)
    private var lifecycleObserverTokens: [NSObjectProtocol] = []
    #endif

    /// Background task that listens to `supabase.auth.authStateChanges`.
    private var authListenerTask: Task<Void, Never>?

    // MARK: - Init

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        self.sessionUserIDProvider = nil
        self.syncExecutor = nil

        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let appDir = base.appendingPathComponent("OrionOrb", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: appDir, withIntermediateDirectories: true
        )
        self.fileURL = appDir.appendingPathComponent("history.json")
        self.pendingDeletesURL = appDir.appendingPathComponent("history_pending_deletes.json")

        loadFromDisk()
        loadPendingDeletes()
        migrateLegacyJSONIfNeeded()
        startAuthListener()
        startLifecycleObservers()
        Task { [weak self] in
            await self?.reconcileInitialSessionState()
        }
    }

    init(
        supabase: SupabaseClient,
        appDirectoryURL: URL,
        startAuthListenerOnInit: Bool,
        observeAppLifecycle: Bool = true,
        reconcileInitialSessionOnInit: Bool = true,
        sessionUserIDProvider: (() async -> UUID?)? = nil,
        syncExecutor: ((UUID) async -> Void)? = nil
    ) {
        self.supabase = supabase
        self.sessionUserIDProvider = sessionUserIDProvider
        self.syncExecutor = syncExecutor

        try? FileManager.default.createDirectory(
            at: appDirectoryURL, withIntermediateDirectories: true
        )
        self.fileURL = appDirectoryURL.appendingPathComponent("history.json")
        self.pendingDeletesURL = appDirectoryURL.appendingPathComponent("history_pending_deletes.json")

        loadFromDisk()
        loadPendingDeletes()
        migrateLegacyJSONIfNeeded()
        if startAuthListenerOnInit {
            startAuthListener()
        }
        if observeAppLifecycle {
            startLifecycleObservers()
        }
        if reconcileInitialSessionOnInit {
            Task { [weak self] in
                await self?.reconcileInitialSessionState()
            }
        }
    }

    // MARK: - Public API

    var favorites: [PromptHistoryItem] {
        items.filter(\.favorite)
    }

    func add(_ item: PromptHistoryItem) {
        if let existing = fetchByID(item.id) {
            copyFields(from: item, to: existing)
            existing.markModified()
        } else {
            item.markModified()
            items.insert(item, at: 0)
        }
        saveToDisk()
        pruneIfNeeded()
        triggerBestEffortSyncIfAuthenticated()
    }

    func remove(id: UUID) {
        guard fetchByID(id) != nil else { return }
        pendingDeletedIDs.insert(id)
        items.removeAll { $0.id == id }
        savePendingDeletes()
        saveToDisk()
        triggerBestEffortSyncIfAuthenticated()
    }

    func clearAll() {
        items.forEach { pendingDeletedIDs.insert($0.id) }
        items = []
        savePendingDeletes()
        saveToDisk()
        triggerBestEffortSyncIfAuthenticated()
    }

    func toggleFavorite(id: UUID) {
        guard let item = fetchByID(id) else { return }
        item.favorite.toggle()
        item.markModified()
        saveToDisk()
        triggerBestEffortSyncIfAuthenticated()
    }

    func rename(id: UUID, customName: String?) {
        guard let item = fetchByID(id) else { return }
        item.customName = customName
        item.markModified()
        saveToDisk()
        triggerBestEffortSyncIfAuthenticated()
    }

    // MARK: - Supabase Sync

    /// Two-way last-write-wins merge against the Supabase `prompts` table.
    ///
    /// 1. Upserts every local record where `isSynced == false`.
    /// 2. Fetches all remote records for the user.
    /// 3. Merges by `lastModified` — remote wins when it is newer.
    /// 4. Marks successfully uploaded records as `isSynced = true`.
    func syncWithSupabase(userId: UUID) async {
        if let syncExecutor {
            guard !isSyncing else { return }
            isSyncing = true
            defer { isSyncing = false }
            await syncExecutor(userId)
            return
        }

        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // ── Step 1: upload unsynced local records ──────────────────────
            let unsynced = items.filter { !$0.isSynced }
            if !unsynced.isEmpty {
                let records = unsynced.map { PromptRecord(item: $0, userId: userId) }
                try await supabase
                    .from("prompts")
                    .upsert(records)
                    .execute()

                unsynced.forEach { $0.isSynced = true }
                saveToDisk()

                #if DEBUG
                print("☁️ [HistoryStore] Upserted \(records.count) record(s) to Supabase")
                #endif
            }

            // ── Step 1.5: propagate pending deletes ───────────────────────
            if !pendingDeletedIDs.isEmpty {
                let deleteIDs = Array(pendingDeletedIDs)
                for id in deleteIDs {
                    try await supabase
                        .from("prompts")
                        .delete()
                        .eq("user_id", value: userId.uuidString)
                        .eq("id", value: id.uuidString)
                        .execute()
                }

                pendingDeletedIDs.subtract(deleteIDs)
                savePendingDeletes()

                #if DEBUG
                print("☁️ [HistoryStore] Deleted \(deleteIDs.count) record(s) from Supabase")
                #endif
            }

            // ── Step 2: fetch all remote records for this user ─────────────
            let remote: [PromptRecord] = try await supabase
                .from("prompts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            // ── Step 3: last-write-wins merge ──────────────────────────────
            var merged = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            for record in remote {
                if pendingDeletedIDs.contains(record.id) {
                    continue
                }
                if let local = merged[record.id] {
                    if record.lastModified > local.lastModified {
                        // Remote wins — overwrite the local item in place.
                        copyFields(from: record.toHistoryItem(), to: local)
                        local.isSynced = true
                    }
                    // else: local wins — already in `merged`, nothing to do.
                } else {
                    // New remote record — add it locally.
                    merged[record.id] = record.toHistoryItem()
                }
            }

            items = merged.values.sorted { $0.createdAt > $1.createdAt }
            saveToDisk()

            lastSyncError = nil

            #if DEBUG
            print("☁️ [HistoryStore] Sync complete — \(items.count) item(s) total")
            #endif

        } catch {
            lastSyncError = error
            TelemetryService.shared.logStorageError(
                code: "SUPABASE_SYNC_FAILED",
                message: "HistoryStore Supabase sync failed: \(error.localizedDescription)"
            )
            #if DEBUG
            print("❌ [HistoryStore] Supabase sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Force a sync right now (e.g. pull-to-refresh). Fetches the current
    /// session from Supabase so no `userId` parameter is needed at the call site.
    func forceSync() async {
        guard let session = try? await supabase.auth.session else { return }
        await syncWithSupabase(userId: session.user.id)
    }

    // MARK: - Auth listener

    /// Listens to `supabase.auth.authStateChanges` and auto-syncs on `.signedIn`.
    private func startAuthListener() {
        authListenerTask?.cancel()
        authListenerTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { break }
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let userId = session?.user.id {
                        await self.syncWithSupabase(userId: userId)
                    }
                case .signedOut, .userDeleted:
                    self.resetLocalStateForSignedOutUser()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Private helpers

    private func fetchByID(_ id: UUID) -> PromptHistoryItem? {
        items.first { $0.id == id }
    }

    private func reconcileInitialSessionState() async {
        if let userId = await currentSessionUserID() {
            await syncWithSupabase(userId: userId)
        } else {
            resetLocalStateForSignedOutUser()
        }
    }

    private func triggerBestEffortSyncIfAuthenticated() {
        guard !isSyncing else { return }

        Task { [weak self] in
            guard let self else { return }
            guard !self.isSyncing else { return }
            guard let userId = await self.currentSessionUserID() else { return }
            await self.syncWithSupabase(userId: userId)
        }
    }

    private func hasPendingSyncWork() -> Bool {
        items.contains(where: { !$0.isSynced }) || !pendingDeletedIDs.isEmpty
    }

    func handleAppBecameActiveForSyncRetry() {
        guard hasPendingSyncWork() else { return }
        triggerBestEffortSyncIfAuthenticated()
    }

    private func startLifecycleObservers() {
        #if canImport(UIKit)
        let notificationNames: [Notification.Name] = [
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification
        ]

        for name in notificationNames {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppBecameActiveForSyncRetry()
                }
            }
            lifecycleObserverTokens.append(token)
        }
        #endif
    }

    private func currentSessionUserID() async -> UUID? {
        if let sessionUserIDProvider {
            return await sessionUserIDProvider()
        }
        return try? await supabase.auth.session.user.id
    }

    private func resetLocalStateForSignedOutUser() {
        items = []
        pendingDeletedIDs = []
        savePendingDeletes()
        saveToDisk()
    }

    private func copyFields(
        from source: PromptHistoryItem,
        to destination: PromptHistoryItem
    ) {
        destination.createdAt    = source.createdAt
        destination.mode         = source.mode
        destination.input        = source.input
        destination.professional = source.professional
        destination.template     = source.template
        destination.favorite     = source.favorite
        destination.customName   = source.customName
        destination.lastModified = source.lastModified
        destination.isSynced     = source.isSynced
    }

    private func pruneIfNeeded() {
        guard items.count > maxItems else { return }
        items = Array(items.prefix(maxItems))
        saveToDisk()
    }

    // MARK: - Local persistence (Codable JSON)

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
            #if DEBUG
            print("💾 [HistoryStore] Saved \(items.count) item(s) to disk")
            #endif
        } catch {
            TelemetryService.shared.logStorageError(
                code: "SAVE_FAILED",
                message: "Failed to save history: \(error.localizedDescription)"
            )
            #if DEBUG
            print("❌ [HistoryStore] Save failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func savePendingDeletes() {
        do {
            let data = try JSONEncoder().encode(Array(pendingDeletedIDs))
            try data.write(to: pendingDeletesURL, options: [.atomic])
        } catch {
            TelemetryService.shared.logStorageError(
                code: "SAVE_PENDING_DELETES_FAILED",
                message: "Failed to save pending history deletes: \(error.localizedDescription)"
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
            print("💾 [HistoryStore] Loaded \(items.count) item(s) from disk")
            #endif
        } catch {
            items = []
            TelemetryService.shared.logStorageError(
                code: "LOAD_FAILED",
                message: "Failed to load history: \(error.localizedDescription)"
            )
        }
    }

    private func loadPendingDeletes() {
        guard FileManager.default.fileExists(atPath: pendingDeletesURL.path) else {
            pendingDeletedIDs = []
            return
        }

        do {
            let data = try Data(contentsOf: pendingDeletesURL)
            let decoded = try JSONDecoder().decode([UUID].self, from: data)
            pendingDeletedIDs = Set(decoded)
        } catch {
            pendingDeletedIDs = []
            TelemetryService.shared.logStorageError(
                code: "LOAD_PENDING_DELETES_FAILED",
                message: "Failed to load pending history deletes: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Legacy JSON migration

    /// Shape of records written by older versions of HistoryStore that did not
    /// yet have `lastModified` or `isSynced` fields.
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

    /// If the current `history.json` contains pre-Phase-2 records (decoding as
    /// `PromptHistoryItem` failed, leaving `items` empty), attempt to decode them
    /// as `LegacyItem` and up-convert so no history is lost on first upgrade.
    private func migrateLegacyJSONIfNeeded() {
        // If loadFromDisk() succeeded, nothing to migrate.
        guard items.isEmpty else { return }

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let legacy = try? JSONDecoder().decode([LegacyItem].self, from: data),
              !legacy.isEmpty
        else { return }

        items = legacy.map { legacyItem in
            PromptHistoryItem(
                id:           legacyItem.id,
                createdAt:    legacyItem.createdAt,
                mode:         legacyItem.mode,
                input:        legacyItem.input,
                professional: legacyItem.professional,
                template:     legacyItem.template,
                favorite:     legacyItem.favorite,
                customName:   legacyItem.customName,
                lastModified: legacyItem.createdAt,
                isSynced:     false
            )
        }
        saveToDisk()

        #if DEBUG
        print("🔄 [HistoryStore] Migrated \(items.count) legacy item(s)")
        #endif
    }
}
