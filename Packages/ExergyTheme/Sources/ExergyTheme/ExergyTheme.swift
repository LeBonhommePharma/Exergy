import SwiftUI
import ExergyCore

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Semantic palette from `design-system/exergy/MASTER.md` with the Exergy gold
/// brand override. Hex lives here only — views use these tokens, never raw RGB.
public enum ExergyPalette: Sendable {
    public static let darkBackground: UInt32 = 0x0F172A
    public static let lightBackground: UInt32 = 0xF8FAFC
    public static let darkSurface: UInt32 = 0x1E293B
    public static let lightSurface: UInt32 = 0xFFFFFF
    public static let darkInk: UInt32 = 0xF8FAFC
    public static let lightInk: UInt32 = 0x0F172A
    public static let darkMute: UInt32 = 0x94A3B8
    public static let lightMute: UInt32 = 0x475569
    public static let darkBorder: UInt32 = 0x475569
    public static let lightBorder: UInt32 = 0xCBD5E1
    /// Gold chrome (Shannon sibling). MASTER CTA green is not used.
    public static let goldDark: UInt32 = 0xC4A359
    public static let goldLight: UInt32 = 0x8A6E2F
    public static let destructive: UInt32 = 0xEF4444
    public static let warning: UInt32 = 0xD97706
    public static let scrimAlpha: Double = 0.5
}

/// Density 8 dashboard grid (4/8pt). `md` stays 16 so existing padding rhythm holds.
public enum ExergySpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let compact: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum ExergyRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
}

public enum ExergyIconSize {
    public static let sm: CGFloat = 16
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 24
    public static let hit: CGFloat = 44
}

/// Remaining-first gauge geometry. Gold fill is leftover work, never spent %.
public enum ExergyRingGeometry {
    public static func remainingTrim(usedPercent: Double?) -> Double? {
        guard let used = usedPercent, let remaining = Metering.remainingPercent(used: used) else {
            return nil
        }
        return remaining / 100
    }
}

/// Subtle motion (dial 3). Pair with `accessibilityReduceMotion`.
public enum ExergyMotion {
    public static let short: Double = 0.18
    public static let standard: Double = 0.22
    public static let reveal: Double = 0.32

    public static func animation(reduceMotion: Bool, duration: Double = standard) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }
}

/// Outline SF Symbols — one family, one weight, never emoji.
public enum ExergySymbol: String, Sendable {
    case usage = "gauge.with.needle"
    case add = "plus.circle"
    case settings = "gearshape"
    case accounts = "person.crop.circle"
    case icloud = "icloud"
    case key = "key"
    case hud = "rectangle.inset.filled"
    case pace = "timer"
    case remaining = "hourglass"

    public var systemName: String { rawValue }
}

/// SF Pro on Apple platforms maps the Inter recommendation in MASTER.md.
public enum ExergyType {
    public static var display: Font { .system(.largeTitle, design: .default).weight(.semibold) }
    public static var title: Font { .system(.title2, design: .default).weight(.semibold) }
    public static var headline: Font { .headline }
    public static var body: Font { .body }
    public static var caption: Font { .caption }
    public static var mono: Font { .body.monospacedDigit().weight(.medium) }
    public static var metric: Font { .system(.title, design: .default).weight(.semibold).monospacedDigit() }
}

public struct ExergyRGBA: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

public enum ExergyAdaptiveColor {
    public static func make(light: UInt32, dark: UInt32, alpha: Double = 1) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let rgba = ExergyRGBA(hex: darkMode ? dark : light, alpha: alpha)
            return NSColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        }))
        #elseif canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let rgba = ExergyRGBA(
                hex: traits.userInterfaceStyle == .dark ? dark : light,
                alpha: alpha
            )
            return UIColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        })
        #else
        return ExergyRGBA(hex: dark, alpha: alpha).color
        #endif
    }
}

public extension Color {
    static let exergyBackground = ExergyAdaptiveColor.make(
        light: ExergyPalette.lightBackground,
        dark: ExergyPalette.darkBackground
    )
    static let exergySurface = ExergyAdaptiveColor.make(
        light: ExergyPalette.lightSurface,
        dark: ExergyPalette.darkSurface
    )
    static let exergyInk = ExergyAdaptiveColor.make(
        light: ExergyPalette.lightInk,
        dark: ExergyPalette.darkInk
    )
    static let exergyMute = ExergyAdaptiveColor.make(
        light: ExergyPalette.lightMute,
        dark: ExergyPalette.darkMute
    )
    static let exergyBorder = ExergyAdaptiveColor.make(
        light: ExergyPalette.lightBorder,
        dark: ExergyPalette.darkBorder
    )
    static let exergyGold = ExergyAdaptiveColor.make(
        light: ExergyPalette.goldLight,
        dark: ExergyPalette.goldDark
    )
    static let exergyDestructive = ExergyRGBA(hex: ExergyPalette.destructive).color
    static let exergyWarning = ExergyRGBA(hex: ExergyPalette.warning).color
    static let exergyScrim = Color.black.opacity(ExergyPalette.scrimAlpha)

    static func exergyBrand(_ hex: UInt32) -> Color {
        ExergyRGBA(hex: hex).color
    }

    static func exergyRemaining(_ band: RemainingBand) -> Color {
        switch band {
        case .unknown: return .exergyMute
        case .plentiful: return .exergyGold
        case .watch: return .exergyWarning
        case .low: return .exergyDestructive
        }
    }
}

public enum ExergySurfaceKind: String, Sendable {
    case macPopover
    case macWindow
    case macHUD
    case iPhone
    case iPad
    case watch
    case widget
}

public struct ExergyFocusRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var usedPercent: Double?
    public var expectedPercent: Double?
    public var accent: Color
    public var lineWidth: CGFloat
    public var showsPaceDot: Bool

    public init(
        usedPercent: Double?,
        expectedPercent: Double? = nil,
        accent: Color,
        lineWidth: CGFloat = 10,
        showsPaceDot: Bool = true
    ) {
        self.usedPercent = usedPercent
        self.expectedPercent = expectedPercent
        self.accent = accent
        self.lineWidth = lineWidth
        self.showsPaceDot = showsPaceDot
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let remainingTrim = ExergyRingGeometry.remainingTrim(usedPercent: usedPercent)
            let expectedRemaining = ExergyRingGeometry.remainingTrim(usedPercent: expectedPercent)
            ZStack {
                Circle()
                    .stroke(Color.exergyBorder.opacity(0.7), lineWidth: lineWidth)
                if let remainingTrim, remainingTrim > 0 {
                    Circle()
                        .trim(from: 0, to: remainingTrim)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(ExergyMotion.animation(reduceMotion: reduceMotion), value: remainingTrim)
                }
                if showsPaceDot, let expectedRemaining, expectedRemaining > 0 {
                    let angle = Angle.degrees(expectedRemaining * 360 - 90)
                    let radius = size / 2
                    Circle()
                        .fill(Color.exergyInk)
                        .frame(width: max(4, lineWidth * 0.7), height: max(4, lineWidth * 0.7))
                        .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var label: String {
        ExergyCopy.remaining.resolved
    }

    private var value: String {
        guard let used = usedPercent, let remaining = Metering.remainingPercent(used: used) else {
            return ExergyCopy.unknown.resolved
        }
        return "\(Int(remaining.rounded())) percent"
    }
}

public typealias QuotaRing = ExergyFocusRing

public struct RemainingNumber: View {
    public var remaining: Double?
    public var caption: String
    public var band: RemainingBand

    public init(remaining: Double?, caption: String) {
        self.remaining = remaining
        self.caption = caption
        self.band = RemainingBand.classify(remaining)
    }

    public var body: some View {
        VStack(spacing: ExergySpacing.xxs) {
            Text(remaining.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(ExergyType.metric)
                .foregroundStyle(Color.exergyRemaining(band))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(ExergyType.caption)
                .foregroundStyle(Color.exergyMute)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(band.copy.resolved)
                .font(.caption2)
                .foregroundStyle(Color.exergyInk)
        }
        .accessibilityElement(children: .combine)
    }
}
