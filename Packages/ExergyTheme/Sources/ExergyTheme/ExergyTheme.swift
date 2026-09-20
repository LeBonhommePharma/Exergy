import SwiftUI
import ExergyCore

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Palette v2, the values in thebonhomme.com `tokens.css`. Hex lives here only —
/// views use these tokens, never raw RGB.
///
/// This replaced a Tailwind slate ramp plus an invented gold (`0xC4A359`, and a
/// near-duplicate `0xC4A35A` that had already drifted one digit — which is what
/// an unowned colour does). Nothing here is chosen by eye: every value is a
/// token from `tokens.css`, and the ratios in the comments are the measured
/// ones that file records against its own ground.
public enum ExergyPalette: Sendable {
    // Surfaces. Indigo ink, never navy.
    public static let darkBackground: UInt32 = 0x08091A   // --bg
    public static let lightBackground: UInt32 = 0xF4F6FB  // --bg light
    public static let darkSurface: UInt32 = 0x111226      // --bg-card, opaque form
    public static let lightSurface: UInt32 = 0xFFFFFF     // --bg-card light

    // Text.
    public static let darkInk: UInt32 = 0xE4E3F5          // --fg        15.60:1
    public static let lightInk: UInt32 = 0x1E293B         // --fg light
    public static let darkMute: UInt32 = 0x8D8CB0         // --fg-muted   6.12:1
    public static let lightMute: UInt32 = 0x5A6478        // --fg-muted light

    // Hairlines are --fg-muted washes; tokens.css defines no --border, and the
    // site's own boundary value is rgba(141, 140, 176, 0.7) — this hex at 0.7.
    public static let darkBorder: UInt32 = 0x8D8CB0
    public static let lightBorder: UInt32 = 0x5A6478

    /// Brand accent. Tangerine is ΔG — free energy, the work a system can still
    /// do. That is literally what Exergy measures, and it is the colour the
    /// homepage card now carries, so the app and the site agree.
    public static let accentDark: UInt32 = 0xFF9300       // --tangerine     8.86:1
    public static let accentLight: UInt32 = 0xA85F00      // --tangerine-fg  4.51:1

    /// Plenty left: mint, ΔH, the family's brand primary.
    public static let plentifulDark: UInt32 = 0x45E0A8    // --mint         11.73:1
    public static let plentifulLight: UInt32 = 0x00815C   // --mint-fg       4.52:1

    /// Nearly out. Failure text goes DARKER on a light ground, not lighter:
    /// #FF6B6B is a dark-mode lift and collapses to 2.57:1 on #f4f6fb.
    public static let destructiveDark: UInt32 = 0xFF6B6B  // --state-fail-text  7.11:1
    public static let destructiveLight: UInt32 = 0xBE123C // --state-fail-text  5.81:1

    public static let scrimAlpha: Double = 0.5
    /// The one documented hairline alpha on the site.
    public static let borderAlpha: Double = 0.7
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
    /// Gap ABOVE a section header. Sections need more air above than their own
    /// rows need between each other, or every level reads as one flat list —
    /// which is what a uniform 8pt stack was doing here.
    public static let section: CGFloat = 28
    /// Gap between a section header and its first row. Deliberately tighter
    /// than `section`: a label belongs to what follows it.
    public static let sectionLead: CGFloat = 10
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

/// Remaining-first gauge geometry. The fill is leftover work, never spent %.
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
    /// 300ms is the top of the micro-interaction band; 320 sat just outside it.
    public static let reveal: Double = 0.30

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
    static let exergyAccent = ExergyAdaptiveColor.make(
        light: ExergyPalette.accentLight,
        dark: ExergyPalette.accentDark
    )
    static let exergyPlentiful = ExergyAdaptiveColor.make(
        light: ExergyPalette.plentifulLight,
        dark: ExergyPalette.plentifulDark
    )
    static let exergyDestructive = ExergyAdaptiveColor.make(
        light: ExergyPalette.destructiveLight,
        dark: ExergyPalette.destructiveDark
    )
    static let exergyScrim = Color.black.opacity(ExergyPalette.scrimAlpha)

    static func exergyBrand(_ hex: UInt32) -> Color {
        ExergyRGBA(hex: hex).color
    }

    static func exergyRemaining(_ band: RemainingBand) -> Color {
        switch band {
        case .unknown: return .exergyMute
        case .plentiful: return .exergyPlentiful
        case .watch: return .exergyAccent
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
