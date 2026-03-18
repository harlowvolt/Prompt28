import Foundation

/// Persistent model for a single generated-prompt record.
///
/// Storage strategy:
/// - **Local**: Codable JSON file managed by `HistoryStore` (survives offline use).
/// - **Cloud**: Supabase `prompts` table — synced on auth and on every mutation.
///   `lastModified` drives last-write-wins conflict resolution.
///   `isSynced` is `false` while the record is queued for the next Supabase upsert.
///
/// Note: CloudKit has been removed from this model. Do not reintroduce it.
final class PromptHistoryItem: Codable, Identifiable {

    // MARK: - Core properties

    var id: UUID
    var createdAt: Date
    var mode: PromptMode
    var input: String
    var professional: String
    var template: String
    var favorite: Bool
    var customName: String?

    // MARK: - Supabase sync properties

    /// Last local modification date — used for last-write-wins merge.
    var lastModified: Date

    /// `true` once the record has been successfully upserted to Supabase.
    /// Reset to `false` by `markModified()` on any local mutation.
    var isSynced: Bool

    // MARK: - Init

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        mode: PromptMode,
        input: String,
        professional: String,
        template: String,
        favorite: Bool = false,
        customName: String? = nil,
        lastModified: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.input = input
        self.professional = professional
        self.template = template
        self.favorite = favorite
        self.customName = customName
        self.lastModified = lastModified
        self.isSynced = isSynced
    }

    // MARK: - Helpers

    /// Mark as locally modified — clears the sync flag so the record will be
    /// included in the next Supabase upsert cycle.
    func markModified() {
        lastModified = Date()
        isSynced = false
    }
}
