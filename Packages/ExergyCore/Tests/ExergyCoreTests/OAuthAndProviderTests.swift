import XCTest
@testable import ExergyCore

final class OAuthTests: XCTestCase {
    func testPKCEVerifierIsBase64URL() {
        let pkce = PKCE.make(digest: FixtureDigest256())
        XCTAssertFalse(pkce.verifier.contains("+"))
        XCTAssertFalse(pkce.verifier.contains("/"))
        XCTAssertFalse(pkce.verifier.contains("="))
        XCTAssertEqual(pkce.method, "S256")
        XCTAssertFalse(pkce.challenge.isEmpty)
    }

    func testAuthorizationURLContainsPKCE() {
        let config = OAuthCatalog.configuration(for: .copilot, clientID: "iv1")!
        let pkce = PKCEChallenge(verifier: "ver", challenge: "chal")
        let request = OAuthURLBuilder.authorizationRequest(config: config, pkce: pkce, state: "st")
        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "code_challenge" }?.value, "chal")
        XCTAssertEqual(items.first { $0.name == "code_challenge_method" }?.value, "S256")
        XCTAssertEqual(items.first { $0.name == "state" }?.value, "st")
        XCTAssertEqual(items.first { $0.name == "client_id" }?.value, "iv1")
        XCTAssertTrue(request.url.absoluteString.hasPrefix("https://github.com/"))
    }

    func testCallbackStateMismatch() {
        let url = URL(string: "exergy://oauth?code=abc&state=nope")!
        XCTAssertThrowsError(try OAuthURLBuilder.parseCallback(url, expectedState: "yes")) { error in
            XCTAssertEqual(error as? OAuthError, .stateMismatch)
        }
    }

    func testCallbackExtractsCode() throws {
        let url = URL(string: "exergy://oauth?code=abc&state=yes")!
        XCTAssertEqual(try OAuthURLBuilder.parseCallback(url, expectedState: "yes"), "abc")
    }

    func testTokenParse() throws {
        let json = Data("{\"access_token\":\"tok\",\"refresh_token\":\"r\",\"expires_in\":3600}".utf8)
        let now = Date(timeIntervalSince1970: 1000)
        let tokens = try OAuthTokenExchange.parseTokenResponse(json, now: now)
        XCTAssertEqual(tokens.accessToken, "tok")
        XCTAssertEqual(tokens.refreshToken, "r")
        XCTAssertEqual(tokens.expiresAt, now.addingTimeInterval(3600))
    }

    func testManualProvidersHaveNoOAuthConfig() {
        XCTAssertNil(OAuthCatalog.configuration(for: .cursor, clientID: "x"))
        XCTAssertNil(OAuthCatalog.configuration(for: .manual, clientID: "x"))
        XCTAssertNil(OAuthCatalog.configuration(for: .codex, clientID: "x"))
    }

    func testUnconfiguredClientID() {
        let config = OAuthCatalog.configuration(for: .copilot, clientID: "YOUR_GITHUB_CLIENT_ID")!
        XCTAssertFalse(config.isConfigured)
        XCTAssertTrue(OAuthCatalog.configuration(for: .copilot, clientID: "Iv1.real")!.isConfigured)
    }
}

final class UsageParserTests: XCTestCase {
    func testCodexRateLimits() {
        let json: [String: Any] = [
            "primary": ["used_percent": 26.0, "window_minutes": 300, "resets_at": 1_800_000_000],
            "secondary": ["used_percent": 94.0, "window_minutes": 10_080, "resets_at": 1_800_500_000],
            "plan_type": "plus",
        ]
        let windows = UsageParser.windowsFromCodexRateLimits(json)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].kind, .fiveHour)
        XCTAssertEqual(windows[0].usedPercent, 26)
        XCTAssertEqual(windows[1].kind, .sevenDay)
        XCTAssertEqual(UsageParser.planLabelFromCodexRateLimits(json), "plus")
    }

    func testEmptyRateLimitsStayEmpty() {
        XCTAssertTrue(UsageParser.windowsFromCodexRateLimits(nil).isEmpty)
        XCTAssertTrue(UsageParser.windowsFromCodexRateLimits([:]).isEmpty)
    }

    func testGenericFetcherUsesFixtureHTTP() async throws {
        let body = Data("{\"used_percent\":41,\"resets_at\":\"2026-09-20T00:00:00Z\"}".utf8)
        let client = FixtureHTTPClient(responses: [
            "api.anthropic.com": HTTPResponse(status: 200, body: body),
        ])
        let fetcher = GenericJSONFetcher(
            provider: .claude,
            endpoint: URL(string: "https://api.anthropic.com/v1/organizations/usage")!,
            client: client
        )
        let windows = try await fetcher.fetch(
            credential: Credential(method: .apiKey, apiKey: "test-key"),
            now: Date()
        )
        XCTAssertEqual(windows.first?.usedPercent, 41)
    }

    func testUnauthorized() async {
        let client = FixtureHTTPClient(responses: [
            "api.openai.com": HTTPResponse(status: 401, body: Data()),
        ])
        let fetcher = GenericJSONFetcher(
            provider: .codex,
            endpoint: URL(string: "https://api.openai.com/v1/organization/usage")!,
            client: client
        )
        do {
            _ = try await fetcher.fetch(
                credential: Credential(method: .apiKey, apiKey: "bad"),
                now: Date()
            )
            XCTFail("expected unauthorized")
        } catch UsageFetchError.unauthorized {
            // expected
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testLocalJSONImportCodexShape() async throws {
        let json = Data("""
        {"rate_limits":{"primary":{"used_percent":10,"window_minutes":300,"resets_at":1800000000}}}
        """.utf8)
        let fetcher = LocalJSONImportFetcher(provider: .codex, fileData: json)
        let windows = try await fetcher.fetch(
            credential: Credential(method: .localImport),
            now: Date()
        )
        XCTAssertEqual(windows.first?.usedPercent, 10)
    }
}

final class StoreAndGlanceTests: XCTestCase {
    func testStoreRecordsUsageWithoutSecrets() async throws {
        let store = ExergyStore()
        let account = DemoCatalog.accounts()[0]
        try await store.upsert(account)
        try store.storeCredential(Credential(method: .oauth, token: TokenSet(accessToken: "tok")), for: account)
        let observation = DemoCatalog.usage()[0]
        try await store.record(observation)
        let snap = store.snapshot()
        XCTAssertEqual(snap.accounts.count, 1)
        XCTAssertEqual(snap.usage.first?.usedPercent, observation.usedPercent)
        XCTAssertNotNil(try store.credential(for: account).token)
    }

    func testDemoGlanceHasThreeRings() {
        let payload = DemoCatalog.snapshot().glance
        XCTAssertEqual(payload.rings.count, 3)
        XCTAssertTrue(payload.demo)
        XCTAssertNotNil(payload.combinedChip)
        XCTAssertFalse(payload.combinedChip!.contains("tok"))
    }

    func testWidgetBridgeRoundtrip() throws {
        let payload = DemoCatalog.snapshot().glance
        let data = try WidgetBridge.write(payload)
        let again = try WidgetBridge.read(data)
        XCTAssertEqual(again.rings.count, payload.rings.count)
        XCTAssertEqual(again.demo, true)
    }

    func testAttentionLevels() {
        XCTAssertEqual(AttentionPolicy.level(usedPercent: nil), .quiet)
        XCTAssertEqual(AttentionPolicy.level(usedPercent: 50), .quiet)
        XCTAssertEqual(AttentionPolicy.level(usedPercent: 80), .warn)
        XCTAssertEqual(AttentionPolicy.level(usedPercent: 96), .critical)
    }

    func testICloudPolicyFailClosed() {
        XCTAssertFalse(
            ICloudAccountPolicy.shouldUseCloudKit(
                optIn: true,
                hasProvisioningProfile: false,
                accountStatus: .available
            )
        )
        XCTAssertTrue(
            ICloudAccountPolicy.shouldUseCloudKit(
                optIn: true,
                hasProvisioningProfile: true,
                accountStatus: .available
            )
        )
    }

    func testProviderSwitchExhaustive() {
        for kind in ProviderKind.allCases {
            _ = kind.displayName
            _ = kind.brandColorHex
            _ = kind.systemImage
            _ = kind.primaryAuth
            _ = kind.supportsOAuth
            _ = kind.supportsAPIKey
            _ = kind.supportsLocalImport
        }
        XCTAssertEqual(ProviderKind.allCases.count, 8)
    }

    func testIdentityURLsAreHTTPS() {
        XCTAssertTrue(ExergyIdentity.privacyURL.hasPrefix("https://"))
        XCTAssertTrue(ExergyIdentity.supportURL.hasPrefix("https://"))
        XCTAssertEqual(ExergyIdentity.developmentTeam, "ZJLX84G8QV")
        XCTAssertEqual(ExergyIdentity.iCloudContainer, "iCloud.com.lebonhommepharma.exergy")
    }
}
