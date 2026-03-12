import Foundation

@Observable
@MainActor
final class PreferencesStore {
    private(set) var preferences: AppPreferences

    private let defaults = UserDefaults.standard
    private let key = "promptme_prefs"

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .default
        }
    }

    func update(_ transform: (inout AppPreferences) -> Void) {
        var copy = preferences
        transform(&copy)
        preferences = copy
        persist()
    }

    func setMode(_ mode: PromptMode) {
        update { $0.selectedMode = mode }
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            defaults.set(encoded, forKey: key)
        }
    }
}

// MARK: - PreferenceStoring
// Defined here (rather than Core/Protocols/StorageProtocols.swift) so it is
// always compiled as part of the Storage group — no manual Xcode target
// membership required for a separate Protocols/ folder.

@MainActor
protocol PreferenceStoring: AnyObject {
    var preferences: AppPreferences { get }
    func update(_ transform: (inout AppPreferences) -> Void)
    func setMode(_ mode: PromptMode)
}

extension PreferencesStore: PreferenceStoring {}
