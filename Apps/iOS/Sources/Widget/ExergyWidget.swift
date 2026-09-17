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
    var entry: ExergyWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            ForEach(entry.payload.rings.prefix(3), id: \.accountID) { ring in
                VStack {
                    QuotaRing(
                        usedPercent: ring.usedPercent,
                        accent: Color.exergyBrand(ring.accentHex),
                        lineWidth: 6,
                        showsPaceDot: false
                    )
                    Text(ring.provider.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.exergyBackground }
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
