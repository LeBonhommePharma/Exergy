import Foundation

/// Sample meters for first launch and App Review. Clearly labeled as demo — never mixed with real account IDs.
public enum DemoCatalog {
    public static let deviceName = "demo"

    public static func accounts(now: Date = Date()) -> [ExergyAccount] {
        [
            ExergyAccount(
                id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA1")!,
                provider: .claude,
                label: "Work",
                sortIndex: 0,
                createdAt: now.addingTimeInterval(-86400 * 40),
                authMethod: .oauth
            ),
            ExergyAccount(
                id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA2")!,
                provider: .codex,
                label: "Plus",
                sortIndex: 1,
                createdAt: now.addingTimeInterval(-86400 * 20),
                authMethod: .apiKey
            ),
            ExergyAccount(
                id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA3")!,
                provider: .cursor,
                label: "Pro",
                sortIndex: 2,
                createdAt: now.addingTimeInterval(-86400 * 10),
                authMethod: .localImport
            ),
        ]
    }

    public static func usage(now: Date = Date()) -> [AccountUsage] {
        let accounts = accounts(now: now)
        let weekReset = now.addingTimeInterval(86400 * 3)
        let sessionReset = now.addingTimeInterval(60 * 90)
        return [
            AccountUsage(
                accountID: accounts[0].id,
                provider: .claude,
                label: accounts[0].label,
                observedAt: now,
                sourceDevice: deviceName,
                windows: [
                    QuotaWindow(
                        kind: .fiveHour,
                        usedPercent: 38,
                        resetsAt: sessionReset,
                        windowMinutes: 300
                    ),
                    QuotaWindow(
                        kind: .sevenDay,
                        usedPercent: 61,
                        resetsAt: weekReset,
                        windowMinutes: 10_080
                    ),
                ],
                planLabel: "Max"
            ),
            AccountUsage(
                accountID: accounts[1].id,
                provider: .codex,
                label: accounts[1].label,
                observedAt: now,
                sourceDevice: deviceName,
                windows: [
                    QuotaWindow(
                        kind: .fiveHour,
                        usedPercent: 22,
                        resetsAt: sessionReset,
                        windowMinutes: 300
                    ),
                    QuotaWindow(
                        kind: .sevenDay,
                        usedPercent: 74,
                        resetsAt: weekReset,
                        windowMinutes: 10_080
                    ),
                ],
                planLabel: "Plus"
            ),
            AccountUsage(
                accountID: accounts[2].id,
                provider: .cursor,
                label: accounts[2].label,
                observedAt: now,
                sourceDevice: deviceName,
                windows: [
                    QuotaWindow(
                        kind: .monthly,
                        usedPercent: 45,
                        resetsAt: now.addingTimeInterval(86400 * 12),
                        windowMinutes: 43_200
                    ),
                ],
                planLabel: "Pro"
            ),
        ]
    }

    public static func snapshot(now: Date = Date()) -> ExergySnapshot {
        ExergySnapshot(
            accounts: accounts(now: now),
            usage: usage(now: now),
            settings: SyncedSettings(demoMode: true, iCloudOptIn: false, updatedAt: now),
            iCloud: .unsupported,
            generatedAt: now
        )
    }
}

public enum ICloudAccountStatus: String, Sendable, Equatable, CaseIterable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unsupported
}

public enum ICloudAccountPolicy: Sendable {
    public static func canUseCloudKit(_ status: ICloudAccountStatus) -> Bool {
        status == .available
    }

    public static func shouldUseCloudKit(
        optIn: Bool,
        hasProvisioningProfile: Bool,
        accountStatus: ICloudAccountStatus
    ) -> Bool {
        optIn && hasProvisioningProfile && canUseCloudKit(accountStatus)
    }

    public static func status(fromCKAccountStatusRawValue raw: Int) -> ICloudAccountStatus {
        switch raw {
        case 1: return .available
        case 0: return .couldNotDetermine
        case 2: return .restricted
        case 3: return .noAccount
        case 4: return .temporarilyUnavailable
        default: return .couldNotDetermine
        }
    }

    public static func operatorLine(
        optIn: Bool,
        hasProvisioningProfile: Bool,
        accountStatus: ICloudAccountStatus,
        cloudKitConstructed: Bool
    ) -> String {
        if cloudKitConstructed, canUseCloudKit(accountStatus), optIn, hasProvisioningProfile {
            return ExergyCopy.iCloudOn.resolved
        }
        if !optIn {
            return ExergyCopy.iCloudOff.resolved
        }
        if !hasProvisioningProfile {
            return L10n.pick(
                en: "iCloud off (unsigned build)",
                fr: "iCloud off (build non signé)"
            )
        }
        switch accountStatus {
        case .available:
            return ExergyCopy.iCloudOff.resolved
        case .noAccount:
            return ExergyCopy.signInICloud.resolved
        case .restricted:
            return L10n.pick(en: "iCloud restricted", fr: "iCloud restreint")
        case .couldNotDetermine:
            return L10n.pick(en: "iCloud status unknown", fr: "État iCloud inconnu")
        case .temporarilyUnavailable:
            return L10n.pick(en: "iCloud temporarily unavailable", fr: "iCloud temporairement indisponible")
        case .unsupported:
            return ExergyCopy.iCloudOff.resolved
        }
    }
}

public protocol ICloudAccountStatusReading: Sendable {
    func currentStatus() async -> ICloudAccountStatus
}

public struct StaticICloudAccountStatusReader: ICloudAccountStatusReading {
    public let status: ICloudAccountStatus
    public init(_ status: ICloudAccountStatus) { self.status = status }
    public func currentStatus() async -> ICloudAccountStatus { status }
}
