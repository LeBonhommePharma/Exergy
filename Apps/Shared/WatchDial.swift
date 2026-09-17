import SwiftUI
import ExergyCore
import ExergyTheme

public struct WatchDial: View {
    public var rings: [ExergyGlancePayload.Ring]

    public init(rings: [ExergyGlancePayload.Ring]) {
        self.rings = rings
    }

    public var body: some View {
        let shown = Array(rings.prefix(3))
        ZStack {
            ForEach(Array(shown.enumerated()), id: \.element.accountID) { index, ring in
                ExergyFocusRing(
                    usedPercent: ring.usedPercent,
                    expectedPercent: nil,
                    accent: Color.exergyBrand(ring.accentHex),
                    lineWidth: 8 - CGFloat(index) * 1.5,
                    showsPaceDot: false
                )
                .padding(CGFloat(index) * 10)
            }
            if let remaining = shown.first?.remainingPercent {
                Text("\(Int(remaining.rounded()))")
                    .font(.system(.title3, design: .default).weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.exergyInk)
                    .minimumScaleFactor(0.6)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        let chips = rings.compactMap(\.chip)
        if chips.isEmpty { return ExergyCopy.unknown.resolved }
        return chips.joined(separator: ", ")
    }
}
