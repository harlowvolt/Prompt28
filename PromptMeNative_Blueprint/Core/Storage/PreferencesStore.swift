import Foundation

@MainActor
protocol PreferenceStoring: AnyObject {
    var preferences: AppPreferences { get }
    func update(_ transform: (inout AppPreferences) -> Void)
    func setMode(_ mode: PromptMode)
}

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
// Defined here so the concrete store and its protocol stay aligned.
extension PreferencesStore: PreferenceStoring {}
