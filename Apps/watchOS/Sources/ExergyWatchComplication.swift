import SwiftUI
import WidgetKit
import ExergyCore
import ExergyTheme

@main
struct ExergyComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ExergyComplication", provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName(ExergyIdentity.displayName)
        .description(ExergyIdentity.taglineEN)
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ExergyWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            Text(entry.payload.combinedChip ?? ExergyCopy.unknown.resolved)
                .font(.caption2)
                .foregroundStyle(Color.exergyInk)
                .containerBackground(for: .widget) { Color.exergyBackground }
                .accessibilityLabel(entry.payload.combinedChip ?? ExergyCopy.unknown.resolved)
        case .accessoryCorner:
            Text(entry.payload.rings.first?.remainingPercent.map { "\(Int($0.rounded()))" } ?? "—")
                .font(.caption.monospacedDigit())
                .containerBackground(for: .widget) { Color.exergyBackground }
        case .accessoryCircular, .accessoryInline:
            WatchDial(rings: entry.payload.rings)
                .containerBackground(for: .widget) { Color.exergyBackground }
        @unknown default:
            WatchDial(rings: entry.payload.rings)
                .containerBackground(for: .widget) { Color.exergyBackground }
        }
    }
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExergyWidgetEntry {
        ExergyWidgetEntry(date: Date(), payload: DemoCatalog.snapshot().glance)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExergyWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExergyWidgetEntry>) -> Void) {
        let entry = placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}
