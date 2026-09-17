import SwiftUI
import ExergyCore
import ExergyTheme

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct UsageHomeView: View {
    @Bindable public var model: ExergyAppModel

    public init(model: ExergyAppModel) {
        self.model = model
    }

    public var body: some View {
        let accounts = model.snapshot.visibleAccounts
        let focus = Metering.focus(accounts: accounts)
        ScrollView {
            VStack(alignment: .leading, spacing: ExergySpacing.lg) {
                header
                focusRow(focus)
                accountList(accounts)
            }
            .padding(ExergySpacing.md)
        }
        .background(Color.exergyBackground.ignoresSafeArea())
        .task { await model.bootstrapDemoIfNeeded() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ExergySpacing.xs) {
            Text(ExergyIdentity.localizedName)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Color.exergyInk)
            Text(ExergyIdentity.tagline)
                .font(.subheadline)
                .foregroundStyle(Color.exergyGold)
            Text(
                ICloudAccountPolicy.operatorLine(
                    optIn: model.snapshot.settings.iCloudOptIn,
                    hasProvisioningProfile: model.hasProvisioningProfile,
                    accountStatus: model.snapshot.iCloud,
                    cloudKitConstructed: false
                )
            )
            .font(.caption)
            .foregroundStyle(Color.exergyMute)
        }
    }

    private func focusRow(_ accounts: [ExergyAccount]) -> some View {
        HStack(spacing: ExergySpacing.md) {
            ForEach(accounts) { account in
                focusCard(account)
            }
        }
    }

    private func focusCard(_ account: ExergyAccount) -> some View {
        let usage = model.snapshot.usage(for: account.id)
        let window = usage?.primaryWindow
        let accent = Color.exergyBrand(account.resolvedAccentHex)
        return VStack(spacing: ExergySpacing.sm) {
            QuotaRing(
                usedPercent: window?.usedPercent,
                expectedPercent: window.map { Metering.expectedUsedPercent(now: Date(), window: $0) } ?? nil,
                accent: accent
            )
            .frame(height: 96)
            RemainingNumber(
                remaining: window?.remainingPercent,
                caption: account.displayTitle
            )
        }
        .frame(maxWidth: .infinity)
        .padding(ExergySpacing.md)
        .background(Color.exergySurface, in: RoundedRectangle(cornerRadius: ExergyRadius.md))
    }

    private func accountList(_ accounts: [ExergyAccount]) -> some View {
        VStack(alignment: .leading, spacing: ExergySpacing.sm) {
            Text(ExergyCopy.accounts.resolved)
                .font(.headline)
                .foregroundStyle(Color.exergyInk)
            if accounts.isEmpty {
                empty
            } else {
                ForEach(accounts) { account in
                    AccountRow(account: account, usage: model.snapshot.usage(for: account.id))
                }
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: ExergySpacing.sm) {
            Text(ExergyCopy.emptyTitle.resolved)
                .foregroundStyle(Color.exergyInk)
            Text(ExergyCopy.emptyBody.resolved)
                .foregroundStyle(Color.exergyMute)
                .font(.footnote)
        }
        .padding(ExergySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.exergySurface, in: RoundedRectangle(cornerRadius: ExergyRadius.md))
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct AccountRow: View {
    public var account: ExergyAccount
    public var usage: AccountUsage?

    public init(account: ExergyAccount, usage: AccountUsage?) {
        self.account = account
        self.usage = usage
    }

    public var body: some View {
        HStack(spacing: ExergySpacing.md) {
            Circle()
                .fill(Color.exergyBrand(account.resolvedAccentHex))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayTitle)
                    .foregroundStyle(Color.exergyInk)
                Text(usage?.chipLabel ?? ExergyCopy.unknown.resolved)
                    .font(.caption)
                    .foregroundStyle(Color.exergyMute)
            }
            Spacer()
            Text(usage?.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(Color.exergyInk)
        }
        .padding(.vertical, ExergySpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct AddAccountView: View {
    @Bindable public var model: ExergyAppModel

    public init(model: ExergyAppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Picker(ExergyCopy.accounts.resolved, selection: Binding(
                get: { model.addingProvider ?? .claude },
                set: { model.addingProvider = $0 }
            )) {
                ForEach(ProviderKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            TextField(ExergyCopy.accounts.resolved, text: $model.draftLabel)
            if let provider = model.addingProvider ?? .claude {
                if provider.supportsAPIKey {
                    SecureField(ExergyCopy.pasteAPIKey.resolved, text: $model.draftAPIKey)
                    Button(ExergyCopy.pasteAPIKey.resolved) {
                        Task { try? await model.addAccount(provider: provider, method: .apiKey) }
                    }
                }
                if provider.supportsOAuth {
                    Text(ExergyCopy.connectWithOAuth.resolved)
                        .foregroundStyle(Color.exergyMute)
                }
                if provider == .manual {
                    Button(ExergyCopy.addAccount.resolved) {
                        Task { try? await model.addAccount(provider: .manual, method: .manual) }
                    }
                }
            }
            Text(ExergyCopy.secretsStayHere.resolved)
                .font(.footnote)
        }
        .navigationTitle(ExergyCopy.addAccount.resolved)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SettingsView: View {
    @Bindable public var model: ExergyAppModel

    public init(model: ExergyAppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Toggle(ExergyCopy.demoMode.resolved, isOn: Binding(
                get: { model.snapshot.settings.demoMode },
                set: { value in Task { await model.setDemoMode(value) } }
            ))
            Text(ExergyCopy.demoModeHint.resolved).font(.footnote)
            Toggle(ExergyCopy.iCloudOn.resolved, isOn: Binding(
                get: { model.snapshot.settings.iCloudOptIn },
                set: { value in Task { await model.setICloudOptIn(value) } }
            ))
            Text(ExergyCopy.secretsStayHere.resolved).font(.footnote)
            Text(ExergyCopy.noServer.resolved).font(.footnote)
            Link(ExergyCopy.privacy.resolved, destination: URL(string: ExergyIdentity.privacyURL)!)
        }
        .navigationTitle(ExergyCopy.settings.resolved)
    }
}
