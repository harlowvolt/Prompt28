import Foundation

/// Protocol for the prompt-history store.
/// `@MainActor` matches `HistoryStore`'s own isolation.
@MainActor
protocol HistoryStoring: AnyObject {
    /// All saved history items (newest-insert order maintained by `HistoryStore`).
    var items: [PromptHistoryItem] { get }
    /// Convenience subset of `items` where `favorite == true`.
    var favorites: [PromptHistoryItem] { get }

    func add(_ item: PromptHistoryItem)
    func remove(id: UUID)
    func clearAll()
    func toggleFavorite(id: UUID)
    func rename(id: UUID, customName: String?)
}

// MARK: - Conformance
extension HistoryStore: HistoryStoring {}

// ---------------------------------------------------------------------------

/// Protocol for the user-preferences store.
/// `@MainActor` matches `PreferencesStore`'s own isolation.
@MainActor
protocol PreferenceStoring: AnyObject {
    var preferences: AppPreferences { get }
    func update(_ transform: (inout AppPreferences) -> Void)
    func setMode(_ mode: PromptMode)
}

// MARK: - Conformance
extension PreferencesStore: PreferenceStoring {}
