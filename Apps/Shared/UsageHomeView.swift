import SwiftUI
import ExergyCore
import ExergyTheme

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct UsageHomeView: View {
    @Bindable public var model: ExergyAppModel
    public var surface: ExergySurfaceKind

    public init(model: ExergyAppModel, surface: ExergySurfaceKind = .iPhone) {
        self.model = model
        self.surface = surface
    }

    public var body: some View {
        let accounts = model.snapshot.visibleAccounts
        let focus = Metering.focus(accounts: accounts)
        let compact = surface == .macPopover || surface == .macHUD
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? ExergySpacing.md : ExergySpacing.lg) {
                if showsProductHeader {
                    header
                }
                focusRow(focus, compact: compact)
                accountList(accounts)
            }
            .padding(compact ? ExergySpacing.sm : ExergySpacing.md)
            .frame(maxWidth: readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.exergyBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: ExergySpacing.sm) }
        .task { await model.bootstrapDemoIfNeeded() }
        .tint(Color.exergyGold)
    }

    private var showsProductHeader: Bool {
        switch surface {
        case .iPhone, .watch, .widget:
            return false
        case .macPopover, .macWindow, .macHUD, .iPad:
            return true
        }
    }

    private var readableWidth: CGFloat? {
        surface == .iPad ? 720 : nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ExergySpacing.xs) {
            Text(ExergyIdentity.localizedName)
                .font(ExergyType.display)
                .foregroundStyle(Color.exergyInk)
                .tracking(-0.6)
            Text(ExergyIdentity.tagline)
                .font(ExergyType.headline)
                .foregroundStyle(Color.exergyGold)
            Label {
                Text(
                    ICloudAccountPolicy.operatorLine(
                        optIn: model.snapshot.settings.iCloudOptIn,
                        hasProvisioningProfile: model.hasProvisioningProfile,
                        accountStatus: model.snapshot.iCloud,
                        cloudKitConstructed: false
                    )
                )
            } icon: {
                Image(systemName: ExergySymbol.icloud.systemName)
                    .symbolRenderingMode(.monochrome)
            }
            .font(ExergyType.caption)
            .foregroundStyle(Color.exergyMute)
        }
        .accessibilityElement(children: .combine)
    }

    private func focusRow(_ accounts: [ExergyAccount], compact: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: ExergySpacing.sm) {
                ForEach(accounts) { account in
                    FocusMeterCard(
                        account: account,
                        usage: model.snapshot.usage(for: account.id),
                        now: model.snapshot.generatedAt,
                        compact: compact
                    )
                }
            }
            VStack(spacing: ExergySpacing.sm) {
                ForEach(accounts) { account in
                    FocusMeterCard(
                        account: account,
                        usage: model.snapshot.usage(for: account.id),
                        now: model.snapshot.generatedAt,
                        compact: compact
                    )
                }
            }
        }
    }

    private func accountList(_ accounts: [ExergyAccount]) -> some View {
        VStack(alignment: .leading, spacing: ExergySpacing.sm) {
            Text(ExergyCopy.accounts.resolved)
                .font(ExergyType.headline)
                .foregroundStyle(Color.exergyInk)
            if accounts.isEmpty {
                ExergyEmptyState()
            } else {
                ForEach(accounts) { account in
                    QuotaBullet(
                        account: account,
                        usage: model.snapshot.usage(for: account.id),
                        now: model.snapshot.generatedAt
                    )
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct AddAccountView: View {
    @Bindable public var model: ExergyAppModel

    public init(model: ExergyAppModel) {
        self.model = model
    }

    public var body: some View {
        let provider = model.addingProvider ?? .claude
        Form {
            Picker(selection: Binding(
                get: { model.addingProvider ?? .claude },
                set: { model.addingProvider = $0 }
            )) {
                ForEach(ProviderKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            } label: {
                ExergySymbolLabel(ExergyCopy.provider.resolved, symbol: .accounts)
            }
            TextField(ExergyCopy.nickname.resolved, text: $model.draftLabel)
                #if os(iOS)
                .textContentType(.nickname)
                #endif
            if provider.supportsAPIKey {
                SecureField(ExergyCopy.pasteAPIKey.resolved, text: $model.draftAPIKey)
                ExergyPrimaryButton(
                    ExergyCopy.saveKey.resolved,
                    enabled: !model.draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { try? await model.addAccount(provider: provider, method: .apiKey) }
                }
            }
            if provider.supportsOAuth {
                Text(ExergyCopy.connectWithOAuth.resolved)
                    .foregroundStyle(Color.exergyInk)
                Text(ExergyCopy.oauthUnavailable.resolved)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyMute)
            }
            if provider == .manual {
                ExergyPrimaryButton(ExergyCopy.addAccount.resolved) {
                    Task { try? await model.addAccount(provider: .manual, method: .manual) }
                }
            }
            if let error = model.formError {
                Text(error)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyDestructive)
                    .accessibilityLabel(error)
            }
            Text(ExergyCopy.secretsStayHere.resolved)
                .font(ExergyType.caption)
                .foregroundStyle(Color.exergyMute)
        }
        .navigationTitle(ExergyCopy.addAccount.resolved)
        .tint(Color.exergyGold)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SettingsView: View {
    @Bindable public var model: ExergyAppModel
    public var showsHUDToggle: Bool
    @Binding public var showHUD: Bool

    public init(model: ExergyAppModel, showsHUDToggle: Bool = false, showHUD: Binding<Bool> = .constant(false)) {
        self.model = model
        self.showsHUDToggle = showsHUDToggle
        self._showHUD = showHUD
    }

    public var body: some View {
        Form {
            Toggle(isOn: Binding(
                get: { model.snapshot.settings.demoMode },
                set: { value in Task { await model.setDemoMode(value) } }
            )) {
                ExergySymbolLabel(ExergyCopy.demoMode.resolved, symbol: .usage)
            }
            Text(ExergyCopy.demoModeHint.resolved)
                .font(ExergyType.caption)
                .foregroundStyle(Color.exergyMute)
            Toggle(isOn: Binding(
                get: { model.snapshot.settings.iCloudOptIn },
                set: { value in Task { await model.setICloudOptIn(value) } }
            )) {
                ExergySymbolLabel(ExergyCopy.iCloudOn.resolved, symbol: .icloud)
            }
            if showsHUDToggle {
                Toggle(isOn: $showHUD) {
                    ExergySymbolLabel(ExergyCopy.floatingHUD.resolved, symbol: .hud)
                }
                Text(ExergyCopy.floatingHUDHint.resolved)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyMute)
            }
            Text(ExergyCopy.secretsStayHere.resolved)
                .font(ExergyType.caption)
            Text(ExergyCopy.noServer.resolved)
                .font(ExergyType.caption)
            Link(destination: URL(string: ExergyIdentity.privacyURL)!) {
                ExergySymbolLabel(ExergyCopy.privacy.resolved, symbol: .settings)
            }
        }
        .navigationTitle(ExergyCopy.settings.resolved)
        .tint(Color.exergyGold)
    }
}
