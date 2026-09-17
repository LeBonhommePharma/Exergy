import SwiftUI
import WidgetKit
import ExergyCore
import ExergyTheme

struct ExergyProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExergyWidgetEntry {
        ExergyWidgetEntry(date: Date(), payload: DemoCatalog.snapshot().glance)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExergyWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExergyWidgetEntry>) -> Void) {
        let entry = load() ?? placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func load() -> ExergyWidgetEntry? {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ExergyIdentity.appGroup)?
            .appendingPathComponent(WidgetBridge.fileName)
        guard let url, let data = try? Data(contentsOf: url),
              let payload = try? WidgetBridge.read(data)
        else { return nil }
        return ExergyWidgetEntry(date: payload.generatedAt, payload: payload)
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
                accent: Color.exergyBrand(ring?.accentHex ?? ExergyPalette.goldDark),
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
                .foregroundStyle(Color.exergyGold)
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
