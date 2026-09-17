import Foundation

/// The subset of CKRecord field types Exergy syncs. Bound to this enum so the
/// serialization layer can be tested on Linux CI without CloudKit.
public enum CloudValue: Equatable, Sendable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case stringList([String])
}

public typealias CloudFields = [String: CloudValue]

public enum CloudDecodeError: Error, Equatable {
    case missingField(String)
    case typeMismatch(field: String, expected: String)
    case unknownEnumValue(field: String, value: String)
}

public extension Dictionary where Key == String, Value == CloudValue {
    func string(_ key: String) throws -> String {
        guard let v = self[key] else { throw CloudDecodeError.missingField(key) }
        guard case .string(let s) = v else {
            throw CloudDecodeError.typeMismatch(field: key, expected: "string")
        }
        return s
    }

    func double(_ key: String) throws -> Double {
        guard let v = self[key] else { throw CloudDecodeError.missingField(key) }
        switch v {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: throw CloudDecodeError.typeMismatch(field: key, expected: "double")
        }
    }

    func int(_ key: String) throws -> Int {
        guard let v = self[key] else { throw CloudDecodeError.missingField(key) }
        switch v {
        case .int(let i): return i
        case .double(let d): return Int(d.rounded())
        default: throw CloudDecodeError.typeMismatch(field: key, expected: "int")
        }
    }

    func bool(_ key: String) throws -> Bool {
        guard let v = self[key] else { throw CloudDecodeError.missingField(key) }
        switch v {
        case .bool(let b): return b
        case .int(let i): return i != 0
        case .double(let d): return d != 0
        default: throw CloudDecodeError.typeMismatch(field: key, expected: "bool")
        }
    }

    func date(_ key: String) throws -> Date {
        guard let v = self[key] else { throw CloudDecodeError.missingField(key) }
        guard case .date(let d) = v else {
            throw CloudDecodeError.typeMismatch(field: key, expected: "date")
        }
        return d
    }

    func stringList(_ key: String) throws -> [String] {
        guard let v = self[key] else { throw CloudDecodeError.missingField(key) }
        guard case .stringList(let l) = v else {
            throw CloudDecodeError.typeMismatch(field: key, expected: "stringList")
        }
        return l
    }

    func optionalString(_ key: String) throws -> String? {
        self[key] == nil ? nil : try string(key)
    }

    func optionalDouble(_ key: String) throws -> Double? {
        self[key] == nil ? nil : try double(key)
    }

    func optionalInt(_ key: String) throws -> Int? {
        self[key] == nil ? nil : try int(key)
    }

    func optionalDate(_ key: String) throws -> Date? {
        self[key] == nil ? nil : try date(key)
    }

    func optionalBool(_ key: String) throws -> Bool? {
        self[key] == nil ? nil : try bool(key)
    }
}

public protocol CloudSyncable: Equatable, Sendable {
    static var recordType: String { get }
    var recordName: String { get }
    var cloudFields: CloudFields { get }
    init(cloudFields: CloudFields) throws
}

public extension CloudSyncable {
    func reencoded() throws -> Self {
        try Self(cloudFields: cloudFields)
    }
}

public enum CloudKeys {
    public static let updatedAt = "updatedAt"
    public static let deviceName = "deviceName"
    public static let accountID = "accountID"
    public static let provider = "provider"
    public static let label = "label"
    public static let enabled = "enabled"
    public static let sortIndex = "sortIndex"
    public static let createdAt = "createdAt"
    public static let authMethod = "authMethod"
    public static let accentHex = "accentHex"
    public static let observedAt = "observedAt"
    public static let windowsJSON = "windowsJSON"
    public static let spend = "spend"
    public static let spendCurrency = "spendCurrency"
    public static let planLabel = "planLabel"
    public static let errorDescription = "errorDescription"
    public static let focusIDs = "focusIDs"
    public static let demoMode = "demoMode"
    public static let showSpend = "showSpend"
    public static let iCloudOptIn = "iCloudOptIn"
}

public enum ExergySyncConfig {
    public static let containerID = ExergyIdentity.iCloudContainer
    public static let zoneName = "ExergyState"
    public static let subscriptionID = "exergy-state-changes"

    public static let allRecordTypes = [
        SyncedAccount.recordType,
        SyncedUsage.recordType,
        SyncedSettings.recordType,
    ]
}

public enum SyncError: Error {
    case notAvailable(String)
    case secretInCloudFields(String)
    case underlying(Error)
}

public protocol ExergySyncBackend: AnyObject, Sendable {
    func save(recordType: String, recordName: String, fields: CloudFields) async throws
    func delete(recordType: String, recordName: String) async throws
    func fetchAll(recordType: String) async throws -> [(recordName: String, fields: CloudFields)]
}

public extension ExergySyncBackend {
    func save<T: CloudSyncable>(_ value: T) async throws {
        try SecretPolicy.assertNoSecrets(value.cloudFields)
        try await save(
            recordType: T.recordType,
            recordName: value.recordName,
            fields: value.cloudFields
        )
    }

    func delete<T: CloudSyncable>(_ value: T) async throws {
        try await delete(recordType: T.recordType, recordName: value.recordName)
    }

    func fetch<T: CloudSyncable>(_ type: T.Type) async throws -> [T] {
        try await fetchAll(recordType: T.recordType).compactMap { try? T(cloudFields: $0.fields) }
    }
}

public final class InMemorySyncBackend: ExergySyncBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: [String: CloudFields]] = [:]
    public private(set) var writeLog: [String] = []

    public init() {}

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public func save(recordType: String, recordName: String, fields: CloudFields) async throws {
        try SecretPolicy.assertNoSecrets(fields)
        withLock {
            storage[recordType, default: [:]][recordName] = fields
            writeLog.append("save:\(recordType):\(recordName)")
        }
    }

    public func delete(recordType: String, recordName: String) async throws {
        withLock {
            storage[recordType]?.removeValue(forKey: recordName)
            writeLog.append("delete:\(recordType):\(recordName)")
        }
    }

    public func fetchAll(
        recordType: String
    ) async throws -> [(recordName: String, fields: CloudFields)] {
        withLock {
            (storage[recordType] ?? [:])
                .map { (recordName: $0.key, fields: $0.value) }
                .sorted { $0.recordName < $1.recordName }
        }
    }

    public func recordCount(_ recordType: String) -> Int {
        withLock { storage[recordType]?.count ?? 0 }
    }
}
