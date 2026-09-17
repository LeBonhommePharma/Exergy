import Foundation

/// Widget / Watch / Shannon glance payload. Contains meters only — never tokens.
public struct ExergyGlancePayload: Equatable, Sendable, Codable {
    public struct Ring: Equatable, Sendable, Codable {
        public var accountID: UUID
        public var provider: ProviderKind
        public var title: String
        public var accentHex: UInt32
        public var usedPercent: Double?
        public var remainingPercent: Double?
        public var windowTag: String?
        public var pace: PaceState

        public init(
            accountID: UUID,
            provider: ProviderKind,
            title: String,
            accentHex: UInt32,
            usedPercent: Double?,
            remainingPercent: Double?,
            windowTag: String?,
            pace: PaceState
        ) {
            self.accountID = accountID
            self.provider = provider
            self.title = title
            self.accentHex = accentHex
            self.usedPercent = usedPercent
            self.remainingPercent = remainingPercent
            self.windowTag = windowTag
            self.pace = pace
        }

        public var chip: String? {
            guard let used = usedPercent else { return nil }
            let tag = windowTag ?? provider.displayName
            return String(format: "%@ %.0f%%", tag, used)
        }
    }

    public var generatedAt: Date
    public var demo: Bool
    public var rings: [Ring]

    public init(generatedAt: Date, demo: Bool, rings: [Ring]) {
        self.generatedAt = generatedAt
        self.demo = demo
        self.rings = rings
    }

    public var combinedChip: String? {
        let parts = rings.compactMap(\.chip)
        guard !parts.isEmpty else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    public static func make(
        snapshot: ExergySnapshot,
        now: Date = Date(),
        limit: Int = 3
    ) -> ExergyGlancePayload {
        let focus = Metering.focus(accounts: snapshot.accounts, limit: limit)
        let usageByID = Dictionary(uniqueKeysWithValues: snapshot.usage.map { ($0.accountID, $0) })
        let rings: [Ring] = focus.map { account in
            let usage = usageByID[account.id]
            let window = usage?.primaryWindow
            return Ring(
                accountID: account.id,
                provider: account.provider,
                title: account.displayTitle,
                accentHex: account.resolvedAccentHex,
                usedPercent: window?.usedPercent,
                remainingPercent: window?.remainingPercent,
                windowTag: window?.kind.shortTag,
                pace: window.map { Metering.pace(now: now, window: $0) } ?? .unknown
            )
        }
        return ExergyGlancePayload(
            generatedAt: snapshot.generatedAt,
            demo: snapshot.settings.demoMode,
            rings: rings
        )
    }
}

public struct ExergySnapshot: Equatable, Sendable {
    public var accounts: [ExergyAccount]
    public var usage: [AccountUsage]
    public var settings: SyncedSettings
    public var iCloud: ICloudAccountStatus
    public var generatedAt: Date
    public var lastError: String?

    public init(
        accounts: [ExergyAccount] = [],
        usage: [AccountUsage] = [],
        settings: SyncedSettings = SyncedSettings(),
        iCloud: ICloudAccountStatus = .unsupported,
        generatedAt: Date = Date(),
        lastError: String? = nil
    ) {
        self.accounts = accounts
        self.usage = usage
        self.settings = settings
        self.iCloud = iCloud
        self.generatedAt = generatedAt
        self.lastError = lastError
    }

    public var isEmpty: Bool {
        accounts.filter(\.enabled).isEmpty && !settings.demoMode
    }

    public var visibleAccounts: [ExergyAccount] {
        if settings.demoMode { return DemoCatalog.accounts(now: generatedAt) }
        return accounts.filter(\.enabled).sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.createdAt < $1.createdAt
        }
    }

    public var visibleUsage: [AccountUsage] {
        if settings.demoMode { return DemoCatalog.usage(now: generatedAt) }
        return usage
    }

    public func usage(for accountID: UUID) -> AccountUsage? {
        visibleUsage.first { $0.accountID == accountID }
    }

    public var glance: ExergyGlancePayload {
        ExergyGlancePayload.make(snapshot: self, now: generatedAt)
    }
}

/// App-group JSON so widgets and Shannon's glance can read meters without CloudKit.
public enum WidgetBridge {
    public static let fileName = "exergy-glance.json"

    public static func write(_ payload: ExergyGlancePayload, encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    public static func read(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> ExergyGlancePayload {
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExergyGlancePayload.self, from: data)
    }
}
