import Foundation

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

public protocol HTTPClient: Sendable {
    func perform(_ request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func perform(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(status: status, body: data)
    }
}

public struct FixtureHTTPClient: HTTPClient, Sendable {
    public var responses: [String: HTTPResponse]

    public init(responses: [String: HTTPResponse] = [:]) {
        self.responses = responses
    }

    public func perform(_ request: URLRequest) async throws -> HTTPResponse {
        let key = request.url?.absoluteString ?? ""
        if let hit = responses[key] { return hit }
        for (pattern, response) in responses where key.contains(pattern) {
            return response
        }
        return HTTPResponse(status: 404, body: Data())
    }
}

public enum UsageFetchError: Error, Equatable {
    case unauthorized
    case notConfigured
    case http(Int)
    case unreadable
    case empty
}

public protocol UsageFetching: Sendable {
    var provider: ProviderKind { get }
    func fetch(credential: Credential, now: Date) async throws -> [QuotaWindow]
}

public enum UsageParser {
    /// Fail-closed window from a provider percent.
    public static func window(
        kind: QuotaWindow.Kind,
        percentUsed: Double?,
        resetsAt: Date? = nil,
        label: String? = nil,
        windowMinutes: Int? = nil,
        windowStartedAt: Date? = nil
    ) -> QuotaWindow? {
        let pct = percentUsed.flatMap { $0.isFinite ? min(100, max(0, $0)) : nil }
        guard pct != nil || (label?.isEmpty == false && resetsAt != nil) else {
            return nil
        }
        let w = QuotaWindow(
            kind: kind,
            label: label,
            usedPercent: pct,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes,
            windowStartedAt: windowStartedAt
        )
        return w.hasDisplayable || w.resetsAt != nil ? w : nil
    }

    public static func finiteDouble(_ value: Any?) -> Double? {
        if let d = value as? Double, d.isFinite { return min(100, max(0, d)) }
        if let i = value as? Int { return min(100, max(0, Double(i))) }
        if let n = value as? NSNumber {
            let d = n.doubleValue
            guard d.isFinite else { return nil }
            return min(100, max(0, d))
        }
        if let s = value as? String, let d = Double(s), d.isFinite {
            return min(100, max(0, d))
        }
        return nil
    }

    public static func isoDate(_ value: Any?) -> Date? {
        if let d = value as? Date { return d }
        if let i = value as? Int, i > 1_000_000_000 {
            return Date(timeIntervalSince1970: TimeInterval(i))
        }
        if let d = value as? Double, d > 1_000_000_000, d.isFinite {
            return Date(timeIntervalSince1970: d)
        }
        guard let s = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    public static func jsonObject(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Codex `rate_limits` attached to `token_count` events.
    public static func windowsFromCodexRateLimits(_ rateLimits: [String: Any]?) -> [QuotaWindow] {
        guard let rateLimits else { return [] }
        var out: [QuotaWindow] = []
        if let primary = rateLimits["primary"] as? [String: Any],
           let w = windowFromCodexSlot(primary, preferredKind: .fiveHour) {
            out.append(w)
        }
        if let secondary = rateLimits["secondary"] as? [String: Any],
           let w = windowFromCodexSlot(secondary, preferredKind: .sevenDay) {
            out.append(w)
        }
        return out
    }

    public static func planLabelFromCodexRateLimits(_ rateLimits: [String: Any]?) -> String? {
        guard let raw = rateLimits?["plan_type"] as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func windowFromCodexSlot(
        _ slot: [String: Any],
        preferredKind: QuotaWindow.Kind
    ) -> QuotaWindow? {
        let minutes: Int? = {
            if let i = slot["window_minutes"] as? Int, i > 0 { return i }
            if let d = slot["window_minutes"] as? Double, d > 0 { return Int(d) }
            return nil
        }()
        let kind = QuotaWindow.kind(fromWindowMinutes: minutes, preferred: preferredKind)
        let pct = finiteDouble(slot["used_percent"])
        let resets = isoDate(slot["resets_at"])
        guard pct != nil || (minutes != nil && resets != nil) else { return nil }
        return QuotaWindow(
            kind: kind,
            usedPercent: pct,
            resetsAt: resets,
            windowMinutes: minutes
        )
    }

    /// Generic remaining/used document used by several provider JSON fixtures.
    public static func windowsFromGenericUsage(_ object: [String: Any]) -> [QuotaWindow] {
        var out: [QuotaWindow] = []
        if let windows = object["windows"] as? [[String: Any]] {
            for item in windows {
                let minutes = (item["window_minutes"] as? Int)
                    ?? (item["window_minutes"] as? Double).map { Int($0) }
                let kindRaw = item["kind"] as? String
                let kind: QuotaWindow.Kind = {
                    if let kindRaw, let parsed = QuotaWindow.Kind(rawValue: kindRaw) {
                        return parsed
                    }
                    return QuotaWindow.kind(fromWindowMinutes: minutes)
                }()
                if let w = window(
                    kind: kind,
                    percentUsed: finiteDouble(item["used_percent"] ?? item["percentUsed"]),
                    resetsAt: isoDate(item["resets_at"] ?? item["resetsAt"]),
                    label: item["label"] as? String,
                    windowMinutes: minutes
                ) {
                    out.append(w)
                }
            }
            return out
        }
        if let w = window(
            kind: .sevenDay,
            percentUsed: finiteDouble(object["used_percent"] ?? object["percentUsed"]),
            resetsAt: isoDate(object["resets_at"] ?? object["resetsAt"]),
            label: object["plan"] as? String
        ) {
            out.append(w)
        }
        return out
    }
}

public struct GenericJSONFetcher: UsageFetching {
    public var provider: ProviderKind
    public var endpoint: URL
    public var client: HTTPClient

    public init(provider: ProviderKind, endpoint: URL, client: HTTPClient) {
        self.provider = provider
        self.endpoint = endpoint
        self.client = client
    }

    public func fetch(credential: Credential, now: Date) async throws -> [QuotaWindow] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        if let token = credential.token?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let key = credential.apiKey {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        } else {
            throw UsageFetchError.notConfigured
        }
        let response = try await client.perform(request)
        switch response.status {
        case 200:
            guard let object = UsageParser.jsonObject(response.body) else {
                throw UsageFetchError.unreadable
            }
            let windows = UsageParser.windowsFromGenericUsage(object)
            if windows.isEmpty { throw UsageFetchError.empty }
            return windows
        case 401, 403:
            throw UsageFetchError.unauthorized
        default:
            throw UsageFetchError.http(response.status)
        }
    }
}

public struct ManualMeterFetcher: UsageFetching {
    public var provider: ProviderKind { .manual }
    public var windows: [QuotaWindow]

    public init(windows: [QuotaWindow]) {
        self.windows = windows
    }

    public func fetch(credential: Credential, now: Date) async throws -> [QuotaWindow] {
        windows
    }
}

public struct LocalJSONImportFetcher: UsageFetching {
    public var provider: ProviderKind
    public var fileData: Data

    public init(provider: ProviderKind, fileData: Data) {
        self.provider = provider
        self.fileData = fileData
    }

    public func fetch(credential: Credential, now: Date) async throws -> [QuotaWindow] {
        if let object = UsageParser.jsonObject(fileData) {
            if let rate = object["rate_limits"] as? [String: Any] {
                let windows = UsageParser.windowsFromCodexRateLimits(rate)
                if !windows.isEmpty { return windows }
            }
            let windows = UsageParser.windowsFromGenericUsage(object)
            if !windows.isEmpty { return windows }
        }
        throw UsageFetchError.unreadable
    }
}

public enum ProviderEndpoints {
    public static func usageURL(for provider: ProviderKind) -> URL? {
        switch provider {
        case .claude:
            return URL(string: "https://api.anthropic.com/v1/organizations/usage")
        case .codex:
            return URL(string: "https://api.openai.com/v1/organization/usage")
        case .grok:
            return URL(string: "https://api.x.ai/v1/usage")
        case .openrouter:
            return URL(string: "https://openrouter.ai/api/v1/key")
        case .copilot, .gemini, .cursor, .manual:
            return nil
        }
    }

    public static func fetcher(
        for provider: ProviderKind,
        client: HTTPClient
    ) -> (any UsageFetching)? {
        guard let url = usageURL(for: provider) else { return nil }
        return GenericJSONFetcher(provider: provider, endpoint: url, client: client)
    }
}
