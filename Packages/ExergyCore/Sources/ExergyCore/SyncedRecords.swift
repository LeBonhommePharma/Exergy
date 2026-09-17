import Foundation

public struct SyncedAccount: CloudSyncable, Codable {
    public static let recordType = "ExergyAccount"

    public var account: ExergyAccount
    public var updatedAt: Date

    public init(account: ExergyAccount, updatedAt: Date = Date()) {
        self.account = account
        self.updatedAt = updatedAt
    }

    public var recordName: String { account.id.uuidString }

    public var cloudFields: CloudFields {
        var fields: CloudFields = [
            CloudKeys.accountID: .string(account.id.uuidString),
            CloudKeys.provider: .string(account.provider.rawValue),
            CloudKeys.label: .string(account.label),
            CloudKeys.enabled: .bool(account.enabled),
            CloudKeys.sortIndex: .int(account.sortIndex),
            CloudKeys.createdAt: .date(account.createdAt),
            CloudKeys.authMethod: .string(account.authMethod.rawValue),
            CloudKeys.updatedAt: .date(updatedAt),
        ]
        if let hex = account.accentHex {
            fields[CloudKeys.accentHex] = .int(Int(hex))
        }
        return fields
    }

    public init(cloudFields: CloudFields) throws {
        let idRaw = try cloudFields.string(CloudKeys.accountID)
        guard let id = UUID(uuidString: idRaw) else {
            throw CloudDecodeError.typeMismatch(field: CloudKeys.accountID, expected: "uuid")
        }
        let providerRaw = try cloudFields.string(CloudKeys.provider)
        guard let provider = ProviderKind(rawValue: providerRaw) else {
            throw CloudDecodeError.unknownEnumValue(field: CloudKeys.provider, value: providerRaw)
        }
        let methodRaw = try cloudFields.string(CloudKeys.authMethod)
        guard let method = AuthMethod(rawValue: methodRaw) else {
            throw CloudDecodeError.unknownEnumValue(field: CloudKeys.authMethod, value: methodRaw)
        }
        let accent = try cloudFields.optionalInt(CloudKeys.accentHex)
        account = ExergyAccount(
            id: id,
            provider: provider,
            label: try cloudFields.string(CloudKeys.label),
            enabled: try cloudFields.bool(CloudKeys.enabled),
            sortIndex: try cloudFields.int(CloudKeys.sortIndex),
            createdAt: try cloudFields.date(CloudKeys.createdAt),
            authMethod: method,
            accentHex: accent.map { UInt32(truncatingIfNeeded: $0) }
        )
        updatedAt = try cloudFields.date(CloudKeys.updatedAt)
    }
}

public struct SyncedUsage: CloudSyncable {
    public static let recordType = "ExergyUsage"

    public var usage: AccountUsage

    public init(usage: AccountUsage) {
        self.usage = usage
    }

    public var recordName: String { usage.accountID.uuidString }

    public var cloudFields: CloudFields {
        var fields: CloudFields = [
            CloudKeys.accountID: .string(usage.accountID.uuidString),
            CloudKeys.provider: .string(usage.provider.rawValue),
            CloudKeys.label: .string(usage.label),
            CloudKeys.observedAt: .date(usage.observedAt),
            CloudKeys.deviceName: .string(usage.sourceDevice),
            CloudKeys.windowsJSON: .string(Self.encodeWindows(usage.windows)),
        ]
        if let spend = usage.spend {
            fields[CloudKeys.spend] = .double(spend)
        }
        if let currency = usage.spendCurrency {
            fields[CloudKeys.spendCurrency] = .string(currency)
        }
        if let plan = usage.planLabel {
            fields[CloudKeys.planLabel] = .string(plan)
        }
        if let err = usage.errorDescription {
            fields[CloudKeys.errorDescription] = .string(err)
        }
        return fields
    }

    public init(cloudFields: CloudFields) throws {
        let idRaw = try cloudFields.string(CloudKeys.accountID)
        guard let id = UUID(uuidString: idRaw) else {
            throw CloudDecodeError.typeMismatch(field: CloudKeys.accountID, expected: "uuid")
        }
        let providerRaw = try cloudFields.string(CloudKeys.provider)
        guard let provider = ProviderKind(rawValue: providerRaw) else {
            throw CloudDecodeError.unknownEnumValue(field: CloudKeys.provider, value: providerRaw)
        }
        let windowsJSON = try cloudFields.string(CloudKeys.windowsJSON)
        usage = AccountUsage(
            accountID: id,
            provider: provider,
            label: try cloudFields.string(CloudKeys.label),
            observedAt: try cloudFields.date(CloudKeys.observedAt),
            sourceDevice: try cloudFields.string(CloudKeys.deviceName),
            windows: Self.decodeWindows(windowsJSON),
            spend: try cloudFields.optionalDouble(CloudKeys.spend),
            spendCurrency: try cloudFields.optionalString(CloudKeys.spendCurrency),
            planLabel: try cloudFields.optionalString(CloudKeys.planLabel),
            errorDescription: try cloudFields.optionalString(CloudKeys.errorDescription)
        )
    }

    public static func encodeWindows(_ windows: [QuotaWindow]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(windows),
              let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }

    public static func decodeWindows(_ json: String) -> [QuotaWindow] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8),
              let windows = try? decoder.decode([QuotaWindow].self, from: data)
        else { return [] }
        return windows
    }
}

public struct SyncedSettings: CloudSyncable, Equatable {
    public static let recordType = "ExergySettings"
    public static let singletonName = "user-settings"

    public var focusIDs: [UUID]
    public var demoMode: Bool
    public var showSpend: Bool
    public var iCloudOptIn: Bool
    public var updatedAt: Date

    public init(
        focusIDs: [UUID] = [],
        demoMode: Bool = true,
        showSpend: Bool = false,
        iCloudOptIn: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.focusIDs = focusIDs
        self.demoMode = demoMode
        self.showSpend = showSpend
        self.iCloudOptIn = iCloudOptIn
        self.updatedAt = updatedAt
    }

    public var recordName: String { Self.singletonName }

    public var cloudFields: CloudFields {
        [
            CloudKeys.focusIDs: .stringList(focusIDs.map(\.uuidString)),
            CloudKeys.demoMode: .bool(demoMode),
            CloudKeys.showSpend: .bool(showSpend),
            CloudKeys.iCloudOptIn: .bool(iCloudOptIn),
            CloudKeys.updatedAt: .date(updatedAt),
        ]
    }

    public init(cloudFields: CloudFields) throws {
        let ids = (try cloudFields.stringList(CloudKeys.focusIDs)).compactMap(UUID.init(uuidString:))
        focusIDs = ids
        demoMode = try cloudFields.bool(CloudKeys.demoMode)
        showSpend = try cloudFields.bool(CloudKeys.showSpend)
        iCloudOptIn = try cloudFields.bool(CloudKeys.iCloudOptIn)
        updatedAt = try cloudFields.date(CloudKeys.updatedAt)
    }
}
