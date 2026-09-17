import Foundation

/// Pace of spend against a quota window. Usage itself is never invented.
public enum PaceState: String, Sendable, Equatable, CaseIterable, Codable {
    case unknown
    case behind
    case onPace
    case ahead

    public var copy: LocalizedCopy {
        switch self {
        case .unknown: return ExergyCopy.unknown
        case .behind: return ExergyCopy.behind
        case .onPace: return ExergyCopy.onPace
        case .ahead: return ExergyCopy.ahead
        }
    }
}

/// Remaining-work band. Color is never the only cue — pair with ``copy``.
public enum RemainingBand: String, Sendable, Equatable, CaseIterable, Codable {
    case unknown
    case plentiful
    case watch
    case low

    public static let lowCeiling: Double = 15
    public static let watchCeiling: Double = 35

    public static func classify(_ remaining: Double?) -> RemainingBand {
        guard let remaining, remaining.isFinite else { return .unknown }
        if remaining <= lowCeiling { return .low }
        if remaining <= watchCeiling { return .watch }
        return .plentiful
    }

    public var copy: LocalizedCopy {
        switch self {
        case .unknown: return ExergyCopy.unknown
        case .plentiful: return ExergyCopy.remainingPlenty
        case .watch: return ExergyCopy.remainingWatch
        case .low: return ExergyCopy.remainingLow
        }
    }
}

/// Pure metering. Formulas are the product spec; Swift and the Python contract tests share them.
public enum Metering: Sendable {
    /// Percentage points of slack around even spend before we call it ahead/behind.
    public static let paceBand: Double = 5

    public static func remainingPercent(used: Double) -> Double? {
        guard used.isFinite else { return nil }
        return min(100, max(0, 100 - used))
    }

    /// Compact HUD chip. Uses remaining, never invents a percent from tokens.
    public static func remainingChip(tag: String, usedPercent: Double) -> String? {
        guard let remaining = remainingPercent(used: usedPercent) else { return nil }
        let label = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = label.isEmpty ? ExergyCopy.usage.resolved : label
        return String(format: "%@ %.0f%% %@", head, remaining, ExergyCopy.remaining.resolved.lowercased())
    }

    public static func remainingBand(_ remaining: Double?) -> RemainingBand {
        RemainingBand.classify(remaining)
    }

    /// Expected used % if spend were linear across the window. Nil when the window cannot be timed.
    public static func expectedUsedPercent(now: Date, startedAt: Date, resetsAt: Date) -> Double? {
        let duration = resetsAt.timeIntervalSince(startedAt)
        guard duration > 0 else { return nil }
        let elapsed = now.timeIntervalSince(startedAt)
        let ratio = elapsed / duration
        guard ratio.isFinite else { return nil }
        return min(100, max(0, ratio * 100))
    }

    public static func expectedUsedPercent(now: Date, window: QuotaWindow) -> Double? {
        guard let resets = window.resetsAt else { return nil }
        if let start = window.windowStartedAt {
            return expectedUsedPercent(now: now, startedAt: start, resetsAt: resets)
        }
        if let minutes = window.windowMinutes {
            let start = resets.addingTimeInterval(-TimeInterval(minutes) * 60)
            return expectedUsedPercent(now: now, startedAt: start, resetsAt: resets)
        }
        if let typical = window.kind.typicalMinutes {
            let start = resets.addingTimeInterval(-TimeInterval(typical) * 60)
            return expectedUsedPercent(now: now, startedAt: start, resetsAt: resets)
        }
        return nil
    }

    public static func pace(used: Double, expected: Double?, band: Double = paceBand) -> PaceState {
        guard used.isFinite else { return .unknown }
        guard let expected, expected.isFinite else { return .unknown }
        let delta = used - expected
        if delta > band { return .ahead }
        if delta < -band { return .behind }
        return .onPace
    }

    public static func pace(now: Date, window: QuotaWindow) -> PaceState {
        guard let used = window.usedPercent else { return .unknown }
        return pace(used: used, expected: expectedUsedPercent(now: now, window: window))
    }

    /// First `limit` enabled accounts in sort order. Compact surfaces (menu bar, watch, widget) share this.
    public static func focus(accounts: [ExergyAccount], limit: Int = 3) -> [ExergyAccount] {
        let enabled = accounts.filter(\.enabled).sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.createdAt < $1.createdAt
        }
        return Array(enabled.prefix(max(0, limit)))
    }
}

/// A quota pool is one global thing observed from several devices.
///
/// Merge rule: usage only rises inside a window, so the truthful used % is the
/// **max** among observations that share kind + reset instant. Device identity
/// is provenance, not ownership.
public enum PoolMerge: Sendable {
    public static func merge(_ observations: [AccountUsage]) -> AccountUsage? {
        guard let newest = observations.max(by: { $0.observedAt < $1.observedAt }) else {
            return nil
        }
        var buckets: [String: QuotaWindow] = [:]
        for obs in observations {
            for window in obs.windows {
                let key = bucketKey(window)
                if let existing = buckets[key], let existingUsed = existing.usedPercent {
                    if let next = window.usedPercent, next > existingUsed {
                        buckets[key] = window
                    }
                } else if buckets[key] == nil {
                    buckets[key] = window
                } else if window.usedPercent != nil {
                    buckets[key] = window
                }
            }
        }
        let windows = buckets.values.sorted { lhs, rhs in
            kindRank(lhs.kind) < kindRank(rhs.kind)
        }
        var spend: Double?
        var currency: String?
        for obs in observations.sorted(by: { $0.observedAt < $1.observedAt }) {
            if let s = obs.spend {
                spend = s
                currency = obs.spendCurrency
            }
        }
        return AccountUsage(
            accountID: newest.accountID,
            provider: newest.provider,
            label: newest.label,
            observedAt: newest.observedAt,
            sourceDevice: newest.sourceDevice,
            windows: windows,
            spend: spend,
            spendCurrency: currency,
            planLabel: newest.planLabel,
            errorDescription: newest.errorDescription
        )
    }

    public static func bucketKey(_ window: QuotaWindow) -> String {
        let reset = window.resetsAt.map { String($0.timeIntervalSince1970) } ?? "open"
        return "\(window.kind.rawValue)|\(window.label ?? "")|\(reset)"
    }

    private static func kindRank(_ kind: QuotaWindow.Kind) -> Int {
        switch kind {
        case .fiveHour: return 0
        case .sevenDay: return 1
        case .monthly: return 2
        case .other: return 3
        }
    }
}

public struct DailyBurn: Sendable, Equatable, Codable {
    public var day: String
    public var points: Double

    public init(day: String, points: Double) {
        self.day = day
        self.points = points.isFinite ? max(0, points) : 0
    }

    public static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Percentage-point burn between two observations of the same pool.
    public static func delta(from: AccountUsage, to: AccountUsage) -> Double? {
        guard from.accountID == to.accountID,
              let a = from.usedPercent,
              let b = to.usedPercent,
              to.observedAt > from.observedAt
        else { return nil }
        let d = b - a
        return d > 0 ? d : 0
    }
}
