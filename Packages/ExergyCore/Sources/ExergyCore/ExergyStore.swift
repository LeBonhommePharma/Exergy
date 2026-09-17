import Foundation

/// In-memory orchestrator. Shipping apps wrap this with CloudKit + Keychain.
public final class ExergyStore: @unchecked Sendable {
    private let lock = NSLock()
    private var accounts: [UUID: ExergyAccount] = [:]
    private var usage: [UUID: [AccountUsage]] = [:]
    private var settings: SyncedSettings
    private let backend: ExergySyncBackend
    private let secrets: MemorySecretStore
    private var iCloud: ICloudAccountStatus
    public private(set) var lastError: String?

    public init(
        backend: ExergySyncBackend = InMemorySyncBackend(),
        secrets: MemorySecretStore = MemorySecretStore(),
        settings: SyncedSettings = SyncedSettings(),
        iCloud: ICloudAccountStatus = .unsupported
    ) {
        self.backend = backend
        self.secrets = secrets
        self.settings = settings
        self.iCloud = iCloud
    }

    public func snapshot(now: Date = Date()) -> ExergySnapshot {
        lock.lock()
        let accountList = Array(accounts.values)
        let mergedUsage: [AccountUsage] = accounts.keys.compactMap { id in
            PoolMerge.merge(usage[id] ?? [])
        }
        let settings = self.settings
        let iCloud = self.iCloud
        let error = lastError
        lock.unlock()
        return ExergySnapshot(
            accounts: accountList,
            usage: mergedUsage,
            settings: settings,
            iCloud: iCloud,
            generatedAt: now,
            lastError: error
        )
    }

    public func setICloud(_ status: ICloudAccountStatus) {
        lock.lock()
        iCloud = status
        lock.unlock()
    }

    public func setSettings(_ value: SyncedSettings) async throws {
        lock.lock()
        settings = value
        lock.unlock()
        try await backend.save(SyncedSettings(
            focusIDs: value.focusIDs,
            demoMode: value.demoMode,
            showSpend: value.showSpend,
            iCloudOptIn: value.iCloudOptIn,
            updatedAt: Date()
        ))
    }

    public func upsert(_ account: ExergyAccount) async throws {
        lock.lock()
        accounts[account.id] = account
        lock.unlock()
        try await backend.save(SyncedAccount(account: account))
    }

    public func removeAccount(_ id: UUID) async throws {
        lock.lock()
        accounts[id] = nil
        usage[id] = nil
        lock.unlock()
        secrets.remove(ExergyAccount(
            id: id,
            provider: .manual,
            label: "removed"
        ).keychainAccount)
        try await backend.delete(recordType: SyncedAccount.recordType, recordName: id.uuidString)
        try await backend.delete(recordType: SyncedUsage.recordType, recordName: id.uuidString)
    }

    public func storeCredential(_ credential: Credential, for account: ExergyAccount) throws {
        secrets.set(try credential.jsonData(), for: account.keychainAccount)
    }

    public func credential(for account: ExergyAccount) throws -> Credential {
        guard let data = secrets.data(for: account.keychainAccount) else {
            throw SecureStoreError.notFound
        }
        return try Credential.decode(data)
    }

    public func record(_ observation: AccountUsage) async throws {
        try SecretPolicy.assertNoSecrets(SyncedUsage(usage: observation).cloudFields)
        lock.lock()
        usage[observation.accountID, default: []].append(observation)
        let merged = PoolMerge.merge(usage[observation.accountID] ?? []) ?? observation
        lock.unlock()
        try await backend.save(SyncedUsage(usage: merged))
    }

    public func refresh(
        account: ExergyAccount,
        fetcher: any UsageFetching,
        deviceName: String,
        now: Date = Date()
    ) async throws -> AccountUsage {
        let cred = try credential(for: account)
        let windows = try await fetcher.fetch(credential: cred, now: now)
        let observation = AccountUsage(
            accountID: account.id,
            provider: account.provider,
            label: account.label,
            observedAt: now,
            sourceDevice: deviceName,
            windows: windows
        )
        try await record(observation)
        return observation
    }

    public func loadFromBackend() async throws {
        let remoteAccounts = try await backend.fetch(SyncedAccount.self)
        let remoteUsage = try await backend.fetch(SyncedUsage.self)
        let remoteSettings = try await backend.fetch(SyncedSettings.self)
        lock.lock()
        accounts = Dictionary(uniqueKeysWithValues: remoteAccounts.map { ($0.account.id, $0.account) })
        usage = Dictionary(grouping: remoteUsage.map(\.usage), by: \.accountID)
        if let latest = remoteSettings.max(by: { $0.updatedAt < $1.updatedAt }) {
            settings = latest
        }
        lastError = nil
        lock.unlock()
    }
}
