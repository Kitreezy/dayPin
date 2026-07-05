import Foundation
import Security

final class KeychainStore {

    static let shared = KeychainStore()
    private init() {}

    private let service = "com.daypin.app"

    // MARK: - Tokens

    var accessToken: String? {
        get { read("access_token") }
        set { set("access_token", to: newValue) }
    }

    var refreshToken: String? {
        get { read("refresh_token") }
        set { set("refresh_token", to: newValue) }
    }

    // MARK: - Apple credentials (stored for silent re-login)

    var appleEmail: String? {
        get { read("apple_email") }
        set { set("apple_email", to: newValue) }
    }

    var applePassword: String? {
        get { read("apple_password") }
        set { set("apple_password", to: newValue) }
    }

    // MARK: - Clear

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }

    func clearAll() {
        accessToken = nil
        refreshToken = nil
        appleEmail = nil
        applePassword = nil
    }

    // MARK: - Private

    private func read(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func set(_ key: String, to value: String?) {
        guard let value else {
            delete(key)
            return
        }
        guard let data = value.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let update: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            SecItemAdd(query.merging(update) { $1 } as CFDictionary, nil)
        }
    }

    private func delete(_ key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
