import SwiftUI
import WidgetKit
import ExergyCore
import ExergyTheme

@main
struct ExergyComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ExergyComplication", provider: ComplicationProvider()) { entry in
            WatchDial(rings: entry.payload.rings)
                .containerBackground(for: .widget) { Color.exergyBackground }
        }
        .configurationDisplayName(ExergyIdentity.displayName)
        .description(ExergyIdentity.taglineEN)
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
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
