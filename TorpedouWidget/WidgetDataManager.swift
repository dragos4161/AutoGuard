//
//  WidgetDataManager.swift
//  TorpedouWidget
//
//  Manager pentru citirea stării vehiculului și mentenanței în WidgetKit Extension
//  (Home Screen Widgets & Lock Screen Accessory Widgets).
//  Partajează datele prin App Group (UserDefaults).
//

import Foundation
import SwiftUI
import WidgetKit

/// Model complet pentru datele afișate pe widget-urile de Home Screen și Lock Screen
public struct MaintenanceWidgetData: Codable, Equatable {
    public let vehicleId: String
    public let vehicleName: String
    public let plateNumber: String
    public let odometer: Int
    public let kmProgress: Double
    public let timeProgress: Double
    public let kmUsed: Int
    public let intervalKm: Int
    public let remainingKm: Int
    public let remainingDays: Int
    public let dueDateFormatted: String
    public let limitingFactor: String // "mileage" sau "time"
    public let isOverdue: Bool
    public let isDueSoon: Bool

    // Documente expirabile (RCA, ITP, Rovinietă)
    public let nextDocTitle: String?
    public let nextDocDaysLeft: Int?
    public let nextDocIsOverdue: Bool
    public let nextDocIsUrgent: Bool

    // Consum combustibil
    public let lastConsumptionFormatted: String?

    // Timestamp actualizare
    public let lastUpdated: Date

    public init(
        vehicleId: String,
        vehicleName: String,
        plateNumber: String,
        odometer: Int,
        kmProgress: Double,
        timeProgress: Double,
        kmUsed: Int,
        intervalKm: Int,
        remainingKm: Int,
        remainingDays: Int,
        dueDateFormatted: String,
        limitingFactor: String,
        isOverdue: Bool,
        isDueSoon: Bool,
        nextDocTitle: String? = nil,
        nextDocDaysLeft: Int? = nil,
        nextDocIsOverdue: Bool = false,
        nextDocIsUrgent: Bool = false,
        lastConsumptionFormatted: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.vehicleId = vehicleId
        self.vehicleName = vehicleName
        self.plateNumber = plateNumber
        self.odometer = odometer
        self.kmProgress = kmProgress
        self.timeProgress = timeProgress
        self.kmUsed = kmUsed
        self.intervalKm = intervalKm
        self.remainingKm = remainingKm
        self.remainingDays = remainingDays
        self.dueDateFormatted = dueDateFormatted
        self.limitingFactor = limitingFactor
        self.isOverdue = isOverdue
        self.isDueSoon = isDueSoon
        self.nextDocTitle = nextDocTitle
        self.nextDocDaysLeft = nextDocDaysLeft
        self.nextDocIsOverdue = nextDocIsOverdue
        self.nextDocIsUrgent = nextDocIsUrgent
        self.lastConsumptionFormatted = lastConsumptionFormatted
        self.lastUpdated = lastUpdated
    }

    public var kmProgressPercent: Int {
        Int(min(1.0, max(0.0, kmProgress)) * 100)
    }

    public var timeProgressPercent: Int {
        Int(min(1.0, max(0.0, timeProgress)) * 100)
    }

    /// Date demonstrative pentru previzualizări în Simulator / Xcode Previews
    public static var sample: MaintenanceWidgetData {
        MaintenanceWidgetData(
            vehicleId: UUID().uuidString,
            vehicleName: "Dacia Duster",
            plateNumber: "B 123 ABC",
            odometer: 48500,
            kmProgress: 0.72,
            timeProgress: 0.45,
            kmUsed: 7200,
            intervalKm: 10000,
            remainingKm: 2800,
            remainingDays: 195,
            dueDateFormatted: "Iun 2027",
            limitingFactor: "mileage",
            isOverdue: false,
            isDueSoon: false,
            nextDocTitle: "RCA",
            nextDocDaysLeft: 14,
            nextDocIsOverdue: false,
            nextDocIsUrgent: true,
            lastConsumptionFormatted: "6.4 L/100km",
            lastUpdated: Date()
        )
    }
}

public final class WidgetDataManager: @unchecked Sendable {
    public static let shared = WidgetDataManager()

    /// ID-ul App Group pentru partajarea datelor între aplicație și extensia WidgetKit
    public static let appGroupSuiteName = "group.com.ascend.AutoGuard"
    private let widgetDataKey = "saved_maintenance_widget_data"

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupSuiteName) ?? UserDefaults.standard
    }

    private init() {}

    /// Citește datele curente ale widget-ului (folosit de WidgetKit Extension)
    public func loadWidgetData() -> MaintenanceWidgetData? {
        guard let data = sharedDefaults.data(forKey: widgetDataKey),
              let decoded = try? JSONDecoder().decode(MaintenanceWidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
