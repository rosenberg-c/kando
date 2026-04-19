import Foundation
import OSLog
import Security

protocol AuthSessionStoring {
    func save(_ session: PersistedSession)
    func load() -> PersistedSession?
    func clear()
}

final class EphemeralSessionStore: AuthSessionStoring {
    private var session: PersistedSession?

    func save(_ session: PersistedSession) {
        self.session = session
    }

    func load() -> PersistedSession? {
        session
    }

    func clear() {
        session = nil
    }
}

struct PersistedSession: Codable {
    let email: String
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
}

final class KeychainSessionStore: AuthSessionStoring {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "TodoMacOS",
        category: "SessionStore"
    )
    private let account = "auth.session"

    private var service: String {
        Bundle.main.bundleIdentifier ?? "TodoMacOS"
    }

    func save(_ session: PersistedSession) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(session) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                logger.error("Keychain update failed: \(self.describe(status: updateStatus), privacy: .public)")
            }
        } else if status != errSecSuccess {
            logger.error("Keychain save failed: \(self.describe(status: status), privacy: .public)")
        }
    }

    func load() -> PersistedSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(PersistedSession.self, from: data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed: \(self.describe(status: status), privacy: .public)")
        }
    }

    private func describe(status: OSStatus) -> String {
        let fallback = "OSStatus \(status)"
        guard let message = SecCopyErrorMessageString(status, nil) as String? else {
            return fallback
        }
        return "\(message) (\(status))"
    }
}
