import Foundation

/// Observation of one account's quota. This is what CloudKit is allowed to carry.
public struct AccountUsage: Sendable, Equatable, Identifiable, Codable {
    public var accountID: UUID
    public var provider: ProviderKind
    public var label: String
    public var observedAt: Date
    public var sourceDevice: String
    public var windows: [QuotaWindow]
    /// Spend in the provider's currency, only when the source reported it.
    public var spend: Double?
    public var spendCurrency: String?
    public var planLabel: String?
    public var errorDescription: String?

    public var id: UUID { accountID }

    public init(
        accountID: UUID,
        provider: ProviderKind,
        label: String,
        observedAt: Date,
        sourceDevice: String,
        windows: [QuotaWindow] = [],
        spend: Double? = nil,
        spendCurrency: String? = nil,
        planLabel: String? = nil,
        errorDescription: String? = nil
    ) {
        self.accountID = accountID
        self.provider = provider
        self.label = label
        self.observedAt = observedAt
        self.sourceDevice = sourceDevice
        self.windows = windows.filter {
            $0.usedPercent != nil || $0.label != nil || $0.resetsAt != nil || $0.windowMinutes != nil
        }
        self.spend = spend.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let currency = spendCurrency?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.spendCurrency = (currency?.isEmpty == false) ? currency : nil
        let plan = planLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.planLabel = (plan?.isEmpty == false) ? plan : nil
        let err = errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.errorDescription = (err?.isEmpty == false) ? err : nil
    }

    public var hasMeter: Bool { windows.contains { $0.usedPercent != nil } }

    public var primaryWindow: QuotaWindow? {
        windows.first { $0.kind == .sevenDay && $0.usedPercent != nil }
            ?? windows.first { $0.kind == .fiveHour && $0.usedPercent != nil }
            ?? windows.first { $0.usedPercent != nil }
    }

    public var remainingPercent: Double? { primaryWindow?.remainingPercent }

    public var usedPercent: Double? { primaryWindow?.usedPercent }

    public var chipLabel: String? {
        let parts = windows.compactMap(\.shortLabel)
        guard !parts.isEmpty else { return planLabel }
        return parts.prefix(2).joined(separator: " · ")
    }
}
