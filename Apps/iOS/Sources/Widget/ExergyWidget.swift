import SwiftUI
import WidgetKit
import ExergyCore
import ExergyTheme

struct ExergyProvider: TimelineProvider {
    /// Gallery / widget-picker sample only — never a live cache-miss fallback.
    func placeholder(in context: Context) -> ExergyWidgetEntry {
        .demo()
    }

    func getSnapshot(in context: Context, completion: @escaping (ExergyWidgetEntry) -> Void) {
        completion(.live())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExergyWidgetEntry>) -> Void) {
        completion(Timeline(entries: [.live()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct ExergyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ExergyWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium, .systemLarge, .systemExtraLarge:
            medium
        case .accessoryCircular:
            WatchDial(rings: entry.payload.rings)
        case .accessoryRectangular, .accessoryInline:
            rectangular
        @unknown default:
            medium
        }
    }

    private var small: some View {
        let ring = entry.payload.rings.first
        return VStack(spacing: ExergySpacing.xs) {
            ExergyFocusRing(
                usedPercent: ring?.usedPercent,
                accent: Color.exergyBrand(ring?.accentHex ?? ExergyPalette.accentDark),
                lineWidth: 8,
                showsPaceDot: false
            )
            .frame(height: 72)
            Text(ring?.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.exergyRemaining(RemainingBand.classify(ring?.remainingPercent)))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(ring.map { RemainingBand.classify($0.remainingPercent).copy.resolved } ?? ExergyCopy.unknown.resolved)
                .font(.caption2)
                .foregroundStyle(Color.exergyMute)
                .lineLimit(1)
        }
        .padding(ExergySpacing.sm)
        .containerBackground(for: .widget) { Color.exergyBackground }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.payload.combinedChip ?? ExergyCopy.unknown.resolved)
    }

    private var medium: some View {
        HStack(spacing: ExergySpacing.sm) {
            ForEach(entry.payload.rings.prefix(3), id: \.accountID) { ring in
                VStack(spacing: ExergySpacing.xs) {
                    ExergyFocusRing(
                        usedPercent: ring.usedPercent,
                        accent: Color.exergyBrand(ring.accentHex),
                        lineWidth: 6,
                        showsPaceDot: false
                    )
                    .frame(height: 52)
                    Text(ring.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.exergyRemaining(RemainingBand.classify(ring.remainingPercent)))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(ring.provider.displayName)
                        .font(.caption2)
                        .foregroundStyle(Color.exergyMute)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(ExergySpacing.sm)
        .containerBackground(for: .widget) { Color.exergyBackground }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.payload.combinedChip ?? ExergyCopy.unknown.resolved)
    }

    private var rectangular: some View {
        HStack {
            Image(systemName: ExergySymbol.usage.systemName)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.exergyAccent)
            Text(entry.payload.combinedChip ?? ExergyCopy.unknown.resolved)
                .font(.caption2)
                .foregroundStyle(Color.exergyInk)
                .lineLimit(2)
        }
        .containerBackground(for: .widget) { Color.exergyBackground }
        .accessibilityLabel(entry.payload.combinedChip ?? ExergyCopy.unknown.resolved)
    }
}

@main
struct ExergyWidgets: WidgetBundle {
    var body: some Widget {
        ExergyRingsWidget()
    }
}

struct ExergyRingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ExergyRings", provider: ExergyProvider()) { entry in
            ExergyWidgetView(entry: entry)
        }
        .configurationDisplayName(ExergyIdentity.displayName)
        .description(ExergyIdentity.taglineEN)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
