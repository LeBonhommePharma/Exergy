import Foundation
import ExergyCore
import WidgetKit

public struct ExergyWidgetEntry: TimelineEntry {
    public var date: Date
    public var payload: ExergyGlancePayload

    public init(date: Date, payload: ExergyGlancePayload) {
        self.date = date
        self.payload = payload
    }

    public static func demo(now: Date = Date()) -> ExergyWidgetEntry {
        ExergyWidgetEntry(date: now, payload: DemoCatalog.snapshot(now: now).glance)
    }
}
