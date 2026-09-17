import Foundation
import Observation
import ExergyCore

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@MainActor
@Observable
public final class ExergyAppModel {
    public var store: ExergyStore
    public var snapshot: ExergySnapshot
    public var addingProvider: ProviderKind?
    public var draftLabel: String = ""
    public var draftAPIKey: String = ""
    public var formError: String?
    public var oauthClientIDs: [ProviderKind: String]
    public var http: HTTPClient
    public let hasProvisioningProfile: Bool

    public init(
        store: ExergyStore = ExergyStore(),
        http: HTTPClient = FixtureHTTPClient(),
        hasProvisioningProfile: Bool = false,
        oauthClientIDs: [ProviderKind: String] = [:]
    ) {
        self.store = store
        self.http = http
        self.hasProvisioningProfile = hasProvisioningProfile
        self.oauthClientIDs = oauthClientIDs
        self.snapshot = store.snapshot()
    }

    public func refreshSnapshot() {
        snapshot = store.snapshot()
    }

    public func bootstrapDemoIfNeeded() async {
        if snapshot.settings.demoMode, snapshot.accounts.isEmpty {
            refreshSnapshot()
        }
    }

    public func addAccount(provider: ProviderKind, method: AuthMethod) async throws {
        formError = nil
        if method == .apiKey, draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formError = ExergyCopy.keyRequired.resolved
            throw UsageFetchError.notConfigured
        }
        let label = draftLabel.isEmpty ? provider.displayName : draftLabel
        let account = ExergyAccount(
            provider: provider,
            label: label,
            sortIndex: snapshot.accounts.count,
            authMethod: method
        )
        try await store.upsert(account)
        switch method {
        case .apiKey:
            let key = draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { throw UsageFetchError.notConfigured }
            try store.storeCredential(Credential(method: .apiKey, apiKey: key), for: account)
        case .manual:
            try store.storeCredential(Credential(method: .manual), for: account)
        case .oauth:
            try store.storeCredential(Credential(method: .oauth), for: account)
        case .localImport:
            try store.storeCredential(Credential(method: .localImport), for: account)
        }
        var settings = snapshot.settings
        settings.demoMode = false
        settings.updatedAt = Date()
        try await store.setSettings(settings)
        draftAPIKey = ""
        draftLabel = ""
        addingProvider = nil
        refreshSnapshot()
    }

    public func startOAuth(provider: ProviderKind, digest: Digest256) throws -> OAuthAuthorizationRequest {
        guard let clientID = oauthClientIDs[provider], !clientID.isEmpty,
              let config = OAuthCatalog.configuration(for: provider, clientID: clientID),
              config.isConfigured
        else { throw OAuthError.notConfigured }
        let pkce = PKCE.make(digest: digest)
        let state = Base64URL.encode(Data((0..<16).map { _ in UInt8.random(in: 0...255) }))
        return OAuthURLBuilder.authorizationRequest(config: config, pkce: pkce, state: state)
    }

    public func finishOAuth(
        provider: ProviderKind,
        callback: URL,
        request: OAuthAuthorizationRequest
    ) async throws {
        guard let clientID = oauthClientIDs[provider],
              let config = OAuthCatalog.configuration(for: provider, clientID: clientID)
        else { throw OAuthError.notConfigured }
        let code = try OAuthURLBuilder.parseCallback(callback, expectedState: request.state)
        let tokens = try await OAuthTokenExchange.exchange(
            config: config,
            code: code,
            pkce: request.pkce,
            client: http
        )
        let account = ExergyAccount(
            provider: provider,
            label: tokens.accountHint ?? provider.displayName,
            sortIndex: snapshot.accounts.count,
            authMethod: .oauth
        )
        try await store.upsert(account)
        try store.storeCredential(Credential(method: .oauth, token: tokens), for: account)
        var settings = snapshot.settings
        settings.demoMode = false
        try await store.setSettings(settings)
        refreshSnapshot()
    }

    public func refreshAll(deviceName: String = ExergyAppModel.currentDeviceName) async {
        for account in snapshot.accounts where account.enabled {
            if let fetcher = ProviderEndpoints.fetcher(for: account.provider, client: http) {
                do {
                    _ = try await store.refresh(
                        account: account,
                        fetcher: fetcher,
                        deviceName: deviceName
                    )
                } catch {
                    store.setICloud(snapshot.iCloud)
                }
            }
        }
        refreshSnapshot()
    }

    public func setDemoMode(_ on: Bool) async {
        var settings = snapshot.settings
        settings.demoMode = on
        try? await store.setSettings(settings)
        refreshSnapshot()
    }

    public func setICloudOptIn(_ on: Bool) async {
        var settings = snapshot.settings
        settings.iCloudOptIn = on
        try? await store.setSettings(settings)
        refreshSnapshot()
    }

    public static var currentDeviceName: String {
        #if canImport(UIKit) && !os(watchOS)
        return UIDevice.current.name
        #elseif os(watchOS)
        return "Apple Watch"
        #elseif canImport(AppKit)
        return Host.current().localizedName ?? "Mac"
        #else
        return "device"
        #endif
    }
}
