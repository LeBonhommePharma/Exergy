import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public protocol RandomBytesProviding: Sendable {
    func bytes(_ count: Int) -> [UInt8]
}

public struct SystemRandomBytes: RandomBytesProviding {
    public init() {}
    public func bytes(_ count: Int) -> [UInt8] {
        (0..<count).map { _ in UInt8.random(to: .max) }
    }
}

private extension UInt8 {
    static func random(to upper: UInt8) -> UInt8 {
        UInt8.random(in: 0...upper)
    }
}

public protocol Digest256: Sendable {
    func hash(_ data: Data) -> Data
}

#if canImport(CryptoKit)
public struct CryptoKitSHA256: Digest256 {
    public init() {}
    public func hash(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}
#endif

/// Deterministic hasher for tests. Production Apple targets use CryptoKit.
public struct FixtureDigest256: Digest256 {
    public init() {}
    public func hash(_ data: Data) -> Data {
        // Not cryptographic — tests inject this so PKCE URL building is stable.
        var rolling: UInt8 = 0
        var out = Data(count: 32)
        for (i, b) in data.enumerated() {
            rolling = rolling &+ b &+ UInt8(truncatingIfNeeded: i)
            out[i % 32] = out[i % 32] &+ rolling
        }
        return out
    }
}

public struct PKCEChallenge: Equatable, Sendable {
    public var verifier: String
    public var challenge: String
    public var method: String

    public init(verifier: String, challenge: String, method: String = "S256") {
        self.verifier = verifier
        self.challenge = challenge
        self.method = method
    }
}

public enum Base64URL {
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - s.count % 4
        if pad < 4 { s += String(repeating: "=", count: pad) }
        return Data(base64Encoded: s)
    }
}

public enum PKCE {
    public static func make(
        random: RandomBytesProviding = SystemRandomBytes(),
        digest: Digest256
    ) -> PKCEChallenge {
        let raw = Data(random.bytes(32))
        let verifier = Base64URL.encode(raw)
        let challenge = Base64URL.encode(digest.hash(Data(verifier.utf8)))
        return PKCEChallenge(verifier: verifier, challenge: challenge)
    }
}

public struct OAuthConfiguration: Equatable, Sendable {
    public var provider: ProviderKind
    public var clientID: String
    public var clientSecret: String?
    public var authorizeURL: URL
    public var tokenURL: URL
    public var scopes: [String]
    public var redirectURI: URL

    public init(
        provider: ProviderKind,
        clientID: String,
        clientSecret: String? = nil,
        authorizeURL: URL,
        tokenURL: URL,
        scopes: [String],
        redirectURI: URL = URL(string: ExergyIdentity.oauthCallbackURL)!
    ) {
        self.provider = provider
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.authorizeURL = authorizeURL
        self.tokenURL = tokenURL
        self.scopes = scopes
        self.redirectURI = redirectURI
    }

    public var isConfigured: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientID.hasPrefix("YOUR_")
    }
}

public enum OAuthCatalog {
    public static func configuration(for provider: ProviderKind, clientID: String) -> OAuthConfiguration? {
        let redirect = URL(string: ExergyIdentity.oauthCallbackURL)!
        switch provider {
        case .copilot:
            return OAuthConfiguration(
                provider: .copilot,
                clientID: clientID,
                authorizeURL: URL(string: "https://github.com/login/oauth/authorize")!,
                tokenURL: URL(string: "https://github.com/login/oauth/access_token")!,
                scopes: ["read:user", "read:org"],
                redirectURI: redirect
            )
        case .gemini:
            return OAuthConfiguration(
                provider: .gemini,
                clientID: clientID,
                authorizeURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
                scopes: ["https://www.googleapis.com/auth/generative-language.tuning.readonly"],
                redirectURI: redirect
            )
        case .claude:
            return OAuthConfiguration(
                provider: .claude,
                clientID: clientID,
                authorizeURL: URL(string: "https://console.anthropic.com/oauth/authorize")!,
                tokenURL: URL(string: "https://console.anthropic.com/oauth/token")!,
                scopes: ["usage:read"],
                redirectURI: redirect
            )
        case .codex, .cursor, .grok, .openrouter, .manual:
            return nil
        }
    }
}

public struct OAuthAuthorizationRequest: Equatable, Sendable {
    public var url: URL
    public var state: String
    public var pkce: PKCEChallenge
    public var provider: ProviderKind

    public init(url: URL, state: String, pkce: PKCEChallenge, provider: ProviderKind) {
        self.url = url
        self.state = state
        self.pkce = pkce
        self.provider = provider
    }
}

public enum OAuthURLBuilder {
    public static func authorizationRequest(
        config: OAuthConfiguration,
        pkce: PKCEChallenge,
        state: String
    ) -> OAuthAuthorizationRequest {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI.absoluteString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method),
        ]
        if !config.scopes.isEmpty {
            items.append(URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")))
        }
        var components = URLComponents(url: config.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = items
        return OAuthAuthorizationRequest(
            url: components.url ?? config.authorizeURL,
            state: state,
            pkce: pkce,
            provider: config.provider
        )
    }

    public static func parseCallback(_ url: URL, expectedState: String) throws -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let state = items.first(where: { $0.name == "state" })?.value
        guard state == expectedState else {
            throw OAuthError.stateMismatch
        }
        if let err = items.first(where: { $0.name == "error" })?.value {
            throw OAuthError.provider(err)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw OAuthError.missingCode
        }
        return code
    }
}

public enum OAuthError: Error, Equatable {
    case notConfigured
    case stateMismatch
    case missingCode
    case provider(String)
    case tokenExchange
    case unsupportedProvider
}

public struct TokenSet: Equatable, Sendable, Codable {
    public var accessToken: String
    public var refreshToken: String?
    public var tokenType: String
    public var expiresAt: Date?
    public var accountHint: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        accountHint: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.accountHint = accountHint
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow < 60
    }

    public func jsonData() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> TokenSet {
        try JSONDecoder().decode(TokenSet.self, from: data)
    }
}

public struct Credential: Equatable, Sendable, Codable {
    public var method: AuthMethod
    public var token: TokenSet?
    public var apiKey: String?
    public var localBookmark: Data?

    public init(method: AuthMethod, token: TokenSet? = nil, apiKey: String? = nil, localBookmark: Data? = nil) {
        self.method = method
        self.token = token
        self.apiKey = apiKey
        self.localBookmark = localBookmark
    }

    public func jsonData() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> Credential {
        try JSONDecoder().decode(Credential.self, from: data)
    }
}
