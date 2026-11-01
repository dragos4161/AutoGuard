//
//  TorpedouWidget.swift
//  AutoGuard
//
//  Definiția widget-ului WidgetKit pentru extensia de sistem (Home Screen & Lock Screen).
//  Folosește datele sincronizate prin App Group din `WidgetDataManager`.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

public struct MaintenanceWidgetTimelineProvider: TimelineProvider {
    public typealias Entry = MaintenanceTimelineEntry

    public init() {}

    public func placeholder(in context: Context) -> MaintenanceTimelineEntry {
        MaintenanceTimelineEntry(date: Date(), data: MaintenanceWidgetData.sample)
    }

    public func getSnapshot(in context: Context, completion: @escaping (MaintenanceTimelineEntry) -> Void) {
        let currentData = WidgetDataManager.shared.loadWidgetData() ?? MaintenanceWidgetData.sample
        let entry = MaintenanceTimelineEntry(date: Date(), data: currentData)
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<MaintenanceTimelineEntry>) -> Void) {
        let currentData = WidgetDataManager.shared.loadWidgetData()
        let entry = MaintenanceTimelineEntry(date: Date(), data: currentData)

        // Reîmprospătare la fiecare 2 ore sau la solicitarea explicită prin WidgetCenter
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

public struct MaintenanceTimelineEntry: TimelineEntry {
    public let date: Date
    public let data: MaintenanceWidgetData?

    public init(date: Date, data: MaintenanceWidgetData?) {
        self.date = date
        self.data = data
    }
}

// MARK: - Widget Configuration

public struct TorpedouWidget: Widget {
    public let kind: String = "com.ascend.AutoGuard.MaintenanceWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MaintenanceWidgetTimelineProvider()) { entry in
            MaintenanceWidgetEntryView(data: entry.data)
        }
        .configurationDisplayName("Torpedou")
        .description("Monitorizează starea reviziei, alerte de expirare RCA/ITP și consumul de combustibil.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
