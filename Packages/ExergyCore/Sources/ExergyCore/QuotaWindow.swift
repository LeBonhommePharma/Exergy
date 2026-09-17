import Foundation

/// One provider-reported quota window.
///
/// **Hard rule:** `usedPercent` is only set when the source itself reported a
/// percentage. Never derive a fraction from raw token totals.
public struct QuotaWindow: Sendable, Equatable, Codable, Identifiable {
    public enum Kind: String, Sendable, Codable, CaseIterable, Equatable {
        case fiveHour
        case sevenDay
        case monthly
        case other

        public var shortTag: String {
            switch self {
            case .fiveHour: return ExergyCopy.session.resolved
            case .sevenDay: return ExergyCopy.week.resolved
            case .monthly: return ExergyCopy.month.resolved
            case .other: return ExergyCopy.usage.resolved
            }
        }

        public var typicalMinutes: Int? {
            switch self {
            case .fiveHour: return 300
            case .sevenDay: return 10_080
            case .monthly: return 43_200
            case .other: return nil
            }
        }
    }

    public var kind: Kind
    public var label: String?
    /// 0…100 provider-reported used percent. Never computed from tokens.
    public var usedPercent: Double?
    public var resetsAt: Date?
    public var windowMinutes: Int?
    /// Optional window origin so pace can be computed without inventing usage.
    public var windowStartedAt: Date?

    public var id: String {
        "\(kind.rawValue):\(label ?? "")"
    }

    public init(
        kind: Kind,
        label: String? = nil,
        usedPercent: Double? = nil,
        resetsAt: Date? = nil,
        windowMinutes: Int? = nil,
        windowStartedAt: Date? = nil
    ) {
        self.kind = kind
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = (trimmed?.isEmpty == false) ? trimmed : nil
        self.usedPercent = usedPercent.flatMap {
            $0.isFinite ? min(100, max(0, $0)) : nil
        }
        self.resetsAt = resetsAt
        self.windowMinutes = windowMinutes.flatMap { $0 > 0 ? $0 : nil }
        self.windowStartedAt = windowStartedAt
    }

    public var remainingPercent: Double? {
        usedPercent.map { 100 - $0 }
    }

    public var hasDisplayable: Bool {
        usedPercent != nil || label != nil
    }

    public var shortLabel: String? {
        guard let pct = usedPercent else { return nil }
        let tag: String
        switch kind {
        case .fiveHour: tag = "5h"
        case .sevenDay: tag = "7d"
        case .monthly: tag = "mo"
        case .other:
            if let label, !label.isEmpty {
                tag = String(label.prefix(8))
            } else {
                tag = "win"
            }
        }
        return String(format: "%@ %.0f%%", tag, pct)
    }

    public static func kind(fromWindowMinutes minutes: Int?, preferred: Kind? = nil) -> Kind {
        guard let m = minutes, m > 0 else { return preferred ?? .other }
        switch m {
        case 300: return .fiveHour
        case 10_080: return .sevenDay
        case 43_200: return .monthly
        default: return preferred ?? .other
        }
    }
}
