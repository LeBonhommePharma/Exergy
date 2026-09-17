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

    /// Widget-picker sample only. Live snapshot/timeline must use `live`.
    public static func unknown(now: Date = Date()) -> ExergyWidgetEntry {
        ExergyWidgetEntry(date: now, payload: .empty(now: now))
    }

    public static func live(now: Date = Date()) -> ExergyWidgetEntry {
        if let payload = WidgetBridge.loadFromAppGroup() {
            return ExergyWidgetEntry(date: payload.generatedAt, payload: payload)
        }
        return unknown(now: now)
    }
}
