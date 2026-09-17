import SwiftUI
import ExergyCore

public enum ExergySpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum ExergyRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
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

public extension Color {
    static let exergyBackground = Color(.sRGB, red: 0.04, green: 0.04, blue: 0.05, opacity: 1)
    static let exergySurface = Color(.sRGB, red: 0.09, green: 0.09, blue: 0.10, opacity: 1)
    static let exergyInk = Color(.sRGB, red: 0.96, green: 0.95, blue: 0.93, opacity: 1)
    static let exergyMute = Color(.sRGB, red: 0.62, green: 0.60, blue: 0.56, opacity: 1)
    static let exergyGold = Color(.sRGB, red: 0.77, green: 0.64, blue: 0.35, opacity: 1)

    static func exergyBrand(_ hex: UInt32) -> Color {
        ExergyRGBA(hex: hex).color
    }
}

public struct QuotaRing: View {
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
            let used = (usedPercent ?? 0) / 100
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.2), lineWidth: lineWidth)
                if usedPercent != nil {
                    Circle()
                        .trim(from: 0, to: used)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                if showsPaceDot, let expected = expectedPercent {
                    let angle = Angle.degrees((expected / 100) * 360 - 90)
                    let radius = size / 2
                    Circle()
                        .fill(Color.exergyInk)
                        .frame(width: lineWidth * 0.7, height: lineWidth * 0.7)
                        .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(label)
    }

    private var label: String {
        guard let used = usedPercent else { return ExergyCopy.unknown.resolved }
        let remain = 100 - used
        return "\(ExergyCopy.remaining.resolved) \(Int(remain.rounded())) percent"
    }
}

public struct RemainingNumber: View {
    public var remaining: Double?
    public var caption: String

    public init(remaining: Double?, caption: String) {
        self.remaining = remaining
        self.caption = caption
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(remaining.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.exergyInk)
                .monospacedDigit()
            Text(caption)
                .font(.caption)
                .foregroundStyle(Color.exergyMute)
        }
    }
}
