import Foundation

/// One metered login. Secrets are referenced by `id` in the Keychain, never stored here.
public struct ExergyAccount: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var provider: ProviderKind
    public var label: String
    public var enabled: Bool
    public var sortIndex: Int
    public var createdAt: Date
    public var authMethod: AuthMethod
    /// User accent override. Nil → provider brand.
    public var accentHex: UInt32?

    public init(
        id: UUID = UUID(),
        provider: ProviderKind,
        label: String,
        enabled: Bool = true,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        authMethod: AuthMethod? = nil,
        accentHex: UInt32? = nil
    ) {
        self.id = id
        self.provider = provider
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = trimmed.isEmpty ? provider.displayName : trimmed
        self.enabled = enabled
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.authMethod = authMethod ?? provider.primaryAuth
        self.accentHex = accentHex
    }

    public var displayTitle: String {
        if label == provider.displayName { return provider.displayName }
        return "\(provider.displayName) · \(label)"
    }

    public var resolvedAccentHex: UInt32 {
        accentHex ?? provider.brandColorHex
    }

    public var keychainAccount: String {
        "account.\(id.uuidString)"
    }
}
