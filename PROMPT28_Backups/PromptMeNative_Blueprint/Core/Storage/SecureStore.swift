import Foundation

final class SecureStore {
    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    func setToken(_ token: String) throws {
        try keychain.set(token, for: "promptme_token")
    }

    func getToken() -> String? {
        keychain.get("promptme_token")
    }

    func clearToken() {
        keychain.delete("promptme_token")
    }

    func setAdminKey(_ key: String) throws {
        try keychain.set(key, for: "promptme_admin_key")
    }

    func getAdminKey() -> String? {
        keychain.get("promptme_admin_key")
    }

    func clearAdminKey() {
        keychain.delete("promptme_admin_key")
    }
}
