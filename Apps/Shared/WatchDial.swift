import SwiftUI
import ExergyCore
import ExergyTheme

public struct WatchDial: View {
    public var rings: [ExergyGlancePayload.Ring]

    public init(rings: [ExergyGlancePayload.Ring]) {
        self.rings = rings
    }

    public var body: some View {
        ZStack {
            ForEach(Array(rings.prefix(3).enumerated()), id: \.element.accountID) { index, ring in
                QuotaRing(
                    usedPercent: ring.usedPercent,
                    expectedPercent: nil,
                    accent: Color.exergyBrand(ring.accentHex),
                    lineWidth: 8 - CGFloat(index) * 1.5,
                    showsPaceDot: false
                )
                .padding(CGFloat(index) * 10)
            }
        }
        .accessibilityLabel(rings.compactMap(\.chip).joined(separator: ", "))
    }
}
