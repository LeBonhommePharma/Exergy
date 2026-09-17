import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

#if canImport(CloudKit)

public enum CKRecordCodec {
    public static func apply(_ fields: CloudFields, to record: CKRecord) {
        for (key, value) in fields {
            switch value {
            case .string(let v): record[key] = v as CKRecordValue
            case .double(let v): record[key] = v as CKRecordValue
            case .int(let v): record[key] = v as CKRecordValue
            case .bool(let v): record[key] = (v ? 1 : 0) as CKRecordValue
            case .date(let v): record[key] = v as CKRecordValue
            case .data(let v): record[key] = v as CKRecordValue
            case .stringList(let v): record[key] = v as CKRecordValue
            }
        }
    }

    public static func fields(from record: CKRecord) -> CloudFields {
        var out: CloudFields = [:]
        for key in record.allKeys() {
            switch record[key] {
            case let v as String: out[key] = .string(v)
            case let v as Date: out[key] = .date(v)
            case let v as Data: out[key] = .data(v)
            case let v as [String]: out[key] = .stringList(v)
            case let v as NSNumber:
                if v.doubleValue == v.doubleValue.rounded(),
                   abs(v.doubleValue) < Double(Int.max) {
                    out[key] = .int(v.intValue)
                } else {
                    out[key] = .double(v.doubleValue)
                }
            default:
                continue
            }
        }
        return out
    }
}

public final class CloudKitSyncBackend: ExergySyncBackend, @unchecked Sendable {
    private let container: CKContainer
    private let zoneID: CKRecordZone.ID

    public init(containerID: String = ExergySyncConfig.containerID) {
        container = CKContainer(identifier: containerID)
        zoneID = CKRecordZone.ID(zoneName: ExergySyncConfig.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    private var database: CKDatabase { container.privateCloudDatabase }

    public func save(recordType: String, recordName: String, fields: CloudFields) async throws {
        try SecretPolicy.assertNoSecrets(fields)
        let id = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: id)
        CKRecordCodec.apply(fields, to: record)
        do {
            _ = try await database.save(record)
        } catch {
            throw SyncError.underlying(error)
        }
    }

    public func delete(recordType: String, recordName: String) async throws {
        let id = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        do {
            try await database.deleteRecord(withID: id)
        } catch {
            throw SyncError.underlying(error)
        }
    }

    public func fetchAll(
        recordType: String
    ) async throws -> [(recordName: String, fields: CloudFields)] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
            var out: [(recordName: String, fields: CloudFields)] = []
            for (id, result) in results {
                if case .success(let record) = result {
                    out.append((id.recordName, CKRecordCodec.fields(from: record)))
                }
            }
            return out.sorted { $0.recordName < $1.recordName }
        } catch {
            throw SyncError.underlying(error)
        }
    }
}

public final class CloudKitAccountStatusReader: ICloudAccountStatusReading, @unchecked Sendable {
    private let containerID: String

    public init(containerID: String = ExergySyncConfig.containerID) {
        self.containerID = containerID
    }

    public func currentStatus() async -> ICloudAccountStatus {
        let container = CKContainer(identifier: containerID)
        do {
            let ck = try await container.accountStatus()
            return ICloudAccountPolicy.status(fromCKAccountStatusRawValue: ck.rawValue)
        } catch {
            return .temporarilyUnavailable
        }
    }
}

#endif

public enum OAuthTokenExchange {
    public static func tokenRequest(
        config: OAuthConfiguration,
        code: String,
        pkce: PKCEChallenge
    ) -> URLRequest {
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var parts = [
            "grant_type=authorization_code",
            "code=\(urlEncode(code))",
            "redirect_uri=\(urlEncode(config.redirectURI.absoluteString))",
            "client_id=\(urlEncode(config.clientID))",
            "code_verifier=\(urlEncode(pkce.verifier))",
        ]
        if let secret = config.clientSecret, !secret.isEmpty {
            parts.append("client_secret=\(urlEncode(secret))")
        }
        request.httpBody = Data(parts.joined(separator: "&").utf8)
        return request
    }

    public static func parseTokenResponse(_ data: Data, now: Date = Date()) throws -> TokenSet {
        guard let object = UsageParser.jsonObject(data) else {
            throw OAuthError.tokenExchange
        }
        guard let access = object["access_token"] as? String, !access.isEmpty else {
            throw OAuthError.tokenExchange
        }
        let refresh = object["refresh_token"] as? String
        let type = (object["token_type"] as? String) ?? "Bearer"
        let expires: Date?
        if let seconds = object["expires_in"] as? Int {
            expires = now.addingTimeInterval(TimeInterval(seconds))
        } else if let seconds = object["expires_in"] as? Double {
            expires = now.addingTimeInterval(seconds)
        } else {
            expires = nil
        }
        return TokenSet(
            accessToken: access,
            refreshToken: refresh,
            tokenType: type,
            expiresAt: expires,
            accountHint: object["login"] as? String ?? object["email"] as? String
        )
    }

    public static func exchange(
        config: OAuthConfiguration,
        code: String,
        pkce: PKCEChallenge,
        client: HTTPClient,
        now: Date = Date()
    ) async throws -> TokenSet {
        let request = tokenRequest(config: config, code: code, pkce: pkce)
        let response = try await client.perform(request)
        guard response.status == 200 else { throw OAuthError.tokenExchange }
        return try parseTokenResponse(response.body, now: now)
    }

    private static func urlEncode(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
    }
}

/// Low remaining is attention; we never invent a zero.
public enum AttentionPolicy {
    public static let warnUsedPercent: Double = 80
    public static let criticalUsedPercent: Double = 95

    public enum Level: String, Sendable, Equatable {
        case quiet
        case warn
        case critical
    }

    public static func level(usedPercent: Double?) -> Level {
        guard let used = usedPercent, used.isFinite else { return .quiet }
        if used >= criticalUsedPercent { return .critical }
        if used >= warnUsedPercent { return .warn }
        return .quiet
    }
}
