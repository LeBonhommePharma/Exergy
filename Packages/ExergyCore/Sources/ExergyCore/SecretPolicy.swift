import Foundation
#if canImport(Security)
import Security
#endif

/// Keys that must never appear in CloudKit fields. Tokens live in the Keychain.
public enum SecretPolicy: Sendable {
    public static let forbiddenKeys: Set<String> = [
        "token",
        "accessToken",
        "refreshToken",
        "idToken",
        "apiKey",
        "apikey",
        "api_key",
        "clientSecret",
        "client_secret",
        "password",
        "secret",
        "authorization",
        "bearer",
        "privateKey",
        "private_key",
        "cookie",
        "session",
        "oauth",
        "verifier",
        "pkce",
    ]

    public static func isForbidden(_ key: String) -> Bool {
        let folded = key.lowercased().replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        return forbiddenKeys.contains { needle in
            folded.contains(needle.lowercased().replacingOccurrences(of: "_", with: ""))
        }
    }

    public static func assertNoSecrets(_ fields: CloudFields) throws {
        for key in fields.keys where isForbidden(key) {
            throw SyncError.secretInCloudFields(key)
        }
        for (key, value) in fields {
            if case .string(let s) = value, looksLikeSecret(s) {
                throw SyncError.secretInCloudFields(key)
            }
        }
    }

    /// Heuristic for accidental token paste into a label field.
    public static func looksLikeSecret(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("sk-") { return true }
        if t.hasPrefix("sk-ant-") { return true }
        if t.hasPrefix("xai-") { return true }
        if t.hasPrefix("ghp_") || t.hasPrefix("github_pat_") { return true }
        if t.count >= 80, t.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) }) {
            return true
        }
        return false
    }
}

public enum SecureStoreError: Error, Equatable {
    case unavailable
    case notFound
    case duplicateItem
    case status(Int32)
    case dataCorrupted
}

/// Keychain-backed secret storage. There is no API on the store that accepts a
/// secret into CloudKit — `ExergyStore` writes credentials only through this type.
public struct SecureStore: Sendable {
    public static let service = "com.lebonhommepharma.exergy.oauth"
    public static let accessGroup = ExergyIdentity.keychainAccessGroup

    public let service: String
    public let accessGroup: String?
    /// When true, items use iCloud Keychain (Apple E2E). Default false: device-bound.
    public let synchronizable: Bool

    public init(
        service: String = SecureStore.service,
        accessGroup: String? = SecureStore.accessGroup,
        synchronizable: Bool = false
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
    }

    #if canImport(Security)

    private func baseQuery(_ account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    public func set(_ value: Data, for account: String) throws {
        var attributes = baseQuery(account)
        attributes[kSecValueData as String] = value
        attributes[kSecAttrAccessible as String] = synchronizable
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let update = [kSecValueData as String: value] as CFDictionary
            let updateStatus = SecItemUpdate(baseQuery(account) as CFDictionary, update)
            guard updateStatus == errSecSuccess else {
                throw SecureStoreError.status(updateStatus)
            }
        default:
            throw SecureStoreError.status(status)
        }
    }

    public func set(_ string: String, for account: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw SecureStoreError.dataCorrupted
        }
        try set(data, for: account)
    }

    public func data(for account: String) throws -> Data {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw SecureStoreError.dataCorrupted }
            return data
        case errSecItemNotFound:
            throw SecureStoreError.notFound
        default:
            throw SecureStoreError.status(status)
        }
    }

    public func string(for account: String) throws -> String {
        guard let string = String(data: try data(for: account), encoding: .utf8) else {
            throw SecureStoreError.dataCorrupted
        }
        return string
    }

    public func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.status(status)
        }
    }

    public func contains(_ account: String) -> Bool {
        do {
            _ = try data(for: account)
            return true
        } catch {
            return false
        }
    }

    #else

    public func set(_ value: Data, for account: String) throws {
        throw SecureStoreError.unavailable
    }
    public func set(_ string: String, for account: String) throws {
        throw SecureStoreError.unavailable
    }
    public func data(for account: String) throws -> Data { throw SecureStoreError.unavailable }
    public func string(for account: String) throws -> String { throw SecureStoreError.unavailable }
    public func remove(_ account: String) throws { throw SecureStoreError.unavailable }
    public func contains(_ account: String) -> Bool { false }

    #endif
}

/// In-memory secret bag for tests and Linux. Never used in shipping apps.
public final class MemorySecretStore: @unchecked Sendable {
    private let lock = NSLock()
    private var bag: [String: Data] = [:]

    public init() {}

    public func set(_ value: Data, for account: String) {
        lock.lock()
        bag[account] = value
        lock.unlock()
    }

    public func set(_ string: String, for account: String) {
        set(Data(string.utf8), for: account)
    }

    public func data(for account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return bag[account]
    }

    public func remove(_ account: String) {
        lock.lock()
        bag[account] = nil
        lock.unlock()
    }
}
