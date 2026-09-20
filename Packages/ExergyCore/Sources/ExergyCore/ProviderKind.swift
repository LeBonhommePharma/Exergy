import Foundation

/// How an account proves identity. Secrets never enter CloudKit regardless of method.
public enum AuthMethod: String, Sendable, Codable, CaseIterable, Equatable {
    case oauth
    case apiKey
    case localImport
    case manual
}

/// AI / coding quota sources Exergy knows how to meter.
public enum ProviderKind: String, Sendable, Codable, CaseIterable, Equatable {
    case claude
    case codex
    case cursor
    case grok
    case copilot
    case gemini
    case openrouter
    case manual

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .grok: return "Grok"
        case .copilot: return "Copilot"
        case .gemini: return "Gemini"
        case .openrouter: return "OpenRouter"
        case .manual: return L10n.pick(en: "Manual meter", fr: "Jauge manuelle")
        }
    }

    /// Brand accent as 0xRRGGBB. Live rings use this; the app icon uses CMY so arcs stay distinct at 1024.
    public var brandColorHex: UInt32 {
        switch self {
        case .claude: return 0xD97757
        case .codex: return 0x10A37F
        case .cursor: return 0xF54E00
        case .grok: return 0x1DA1F2
        case .copilot: return 0x7C3AED
        case .gemini: return 0x4285F4
        case .openrouter: return 0x6566F1
        // Not a vendor mark — a manual meter is Exergy's own, so it wears the
        // brand accent. Was 0xC4A35A: the invented gold, already drifted a digit
        // from the 0xC4A359 it was copied from.
        case .manual: return 0xFF9300
        }
    }

    public var systemImage: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "macwindow"
        case .grok: return "sparkle"
        case .copilot: return "airplane"
        case .gemini: return "diamond.fill"
        case .openrouter: return "arrow.triangle.branch"
        case .manual: return "slider.horizontal.3"
        }
    }

    /// Preferred sign-in on iPhone / iPad. Mac may also offer ``localImport``.
    public var primaryAuth: AuthMethod {
        switch self {
        case .claude, .copilot, .gemini: return .oauth
        case .codex, .grok, .openrouter: return .apiKey
        case .cursor: return .localImport
        case .manual: return .manual
        }
    }

    public var supportsOAuth: Bool {
        switch self {
        case .claude, .copilot, .gemini: return true
        case .codex, .cursor, .grok, .openrouter, .manual: return false
        }
    }

    public var supportsAPIKey: Bool {
        switch self {
        case .claude, .codex, .grok, .openrouter, .gemini: return true
        case .cursor, .copilot, .manual: return false
        }
    }

    public var supportsLocalImport: Bool {
        switch self {
        case .claude, .codex, .cursor, .gemini: return true
        case .grok, .copilot, .openrouter, .manual: return false
        }
    }

    /// Compact surfaces show at most three. Default pin order is this array order.
    public static var defaultFocusOrder: [ProviderKind] {
        [.claude, .codex, .cursor, .grok, .copilot, .gemini, .openrouter, .manual]
    }
}
