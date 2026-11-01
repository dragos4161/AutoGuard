//
//  WidgetDataManager.swift
//  AutoGuard
//
//  Manager pentru sincronizarea stării de mentenanță către WidgetKit (Home Screen Widget).
//  Partajează datele prin App Group (UserDefaults) și solicită reîncărcarea widget-urilor.
//

import Foundation
import SwiftUI
import WidgetKit

/// Model compact pentru datele afișate pe Home Screen Widget
struct MaintenanceWidgetData: Codable {
    let vehicleName: String
    let plateNumber: String
    let kmProgress: Double
    let timeProgress: Double
    let kmUsed: Int
    let intervalKm: Int
    let remainingKm: Int
    let remainingDays: Int
    let dueDateFormatted: String
    let limitingFactor: String // "mileage" sau "time"
    let isOverdue: Bool
    let isDueSoon: Bool
    let lastUpdated: Date

    var kmProgressPercent: Int {
        Int(min(1.0, max(0.0, kmProgress)) * 100)
    }

    var timeProgressPercent: Int {
        Int(min(1.0, max(0.0, timeProgress)) * 100)
    }
}

@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    /// ID-ul App Group configurat în Xcode pentru partajarea datelor între App și Widget
    static let appGroupSuiteName = "group.com.ascend.AutoGuard"
    private let widgetDataKey = "saved_maintenance_widget_data"

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupSuiteName) ?? UserDefaults.standard
    }

    private init() {}

    /// Actualizează datele widget-ului pentru cel mai relevant vehicul (sau vehiculul specificat)
    func updateWidgetData(for vehicle: Vehicle) {
        guard let status = vehicle.oilChangeStatus else {
            clearWidgetData()
            return
        }

        let data = MaintenanceWidgetData(
            vehicleName: vehicle.displayName,
            plateNumber: vehicle.plateNumber,
            kmProgress: status.kmProgress,
            timeProgress: status.timeProgress,
            kmUsed: status.kmUsed,
            intervalKm: vehicle.oilChangeIntervalKm,
            remainingKm: status.remainingKm,
            remainingDays: status.remainingDays,
            dueDateFormatted: status.dueDate.formatted(.dateTime.month().year()),
            limitingFactor: status.limitingFactor == .mileage ? "mileage" : "time",
            isOverdue: status.isOverdue,
            isDueSoon: status.isDueSoon,
            lastUpdated: Date()
        )

        if let encoded = try? JSONEncoder().encode(data) {
            sharedDefaults.set(encoded, forKey: widgetDataKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Citește datele curente ale widget-ului (folosit de WidgetKit Extension)
    func loadWidgetData() -> MaintenanceWidgetData? {
        guard let data = sharedDefaults.data(forKey: widgetDataKey),
              let decoded = try? JSONDecoder().decode(MaintenanceWidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }

    /// Șterge datele widget-ului
    func clearWidgetData() {
        sharedDefaults.removeObject(forKey: widgetDataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
