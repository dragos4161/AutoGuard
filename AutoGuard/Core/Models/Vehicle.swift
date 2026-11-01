//
//  Vehicle.swift
//  AutoGuard
//
//  Modelul principal SwiftData pentru un vehicul din garajul utilizatorului.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Vehicle {
    var id: UUID = UUID()
    var plateNumber: String = ""  // Ex: B 123 ABC
    var make: String = ""  // Ex: Dacia, Volkswagen, BMW
    var model: String = ""  // Ex: Duster, Golf, Seria 3
    var year: Int = 2023
    var vin: String = ""  // Serie șasiu (17 caractere)
    var nickname: String = ""  // Ex: "Mașina familiei"
    var createdAt: Date = Date()

    // Relație one-to-many cu documentele mașinii (opțională pentru compatibilitate CloudKit)
    @Relationship(deleteRule: .cascade, inverse: \VehicleDocument.vehicle)
    var documents: [VehicleDocument]? = []

    // Relație one-to-many cu istoricul de kilometri al mașinii
    @Relationship(deleteRule: .cascade, inverse: \MileageEntry.vehicle)
    var mileageEntries: [MileageEntry]? = []

    // Relație one-to-many cu istoricul de service și revizii
    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.vehicle)
    var serviceRecords: [ServiceRecord]? = []

    // Setări intervale mentenanță (schimb ulei)
    var oilChangeIntervalKm: Int = 10000
    var oilChangeIntervalMonths: Int = 12

    init(
        plateNumber: String,
        make: String,
        model: String,
        year: Int = Calendar.current.component(.year, from: Date()),
        vin: String = "",
        nickname: String = ""
    ) {
        self.id = UUID()
        self.plateNumber = plateNumber.uppercased()
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin.uppercased()
        self.nickname = nickname
        self.createdAt = Date()
    }

    /// Doar documentele active (curente) ale mașinii
    var activeDocuments: [VehicleDocument] {
        (documents ?? []).filter { !$0.isArchived }
    }

    /// Istoricul documentelor vechi (arhivate la reînnoire), de la cel mai recent la cel mai vechi
    var archivedDocuments: [VehicleDocument] {
        (documents ?? [])
            .filter { $0.isArchived }
            .sorted { $0.expirationDate > $1.expirationDate }
    }

    /// Găsește un document activ specific (ex: RCA sau ITP)
    func document(for type: DocumentType) -> VehicleDocument? {
        activeDocuments.first { $0.type == type }
    }

    /// Cel mai urgent document activ (cel cu cele mai puține zile rămase)
    var mostUrgentDocument: VehicleDocument? {
        activeDocuments.min { $0.daysRemaining < $1.daysRemaining }
    }

    /// Titlul complet al mașinii pentru interfață
    var displayName: String {
        let name = "\(make) \(model)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? plateNumber : name
    }

    // MARK: - Kilometraj
    /// Toate intrările de kilometraj sortate de la cea mai recentă la cea mai veche
    var sortedMileageEntries: [MileageEntry] {
        (mileageEntries ?? []).sorted { $0.date > $1.date }
    }

    /// Kilometrajul curent (cea mai recentă înregistrare)
    var currentMileage: Int? {
        sortedMileageEntries.first?.mileage
    }

    /// Formatare frumoasă cu separator de mii (ex: "145.200 km")
    var formattedMileage: String? {
        guard let currentMileage else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formattedNumber = formatter.string(from: NSNumber(value: currentMileage)) ?? "\(currentMileage)"
        return "\(formattedNumber) km"
    }

    // MARK: - Istoric Service & Mentenanță
    /// Înregistrările de service sortate descrescător după dată
    var sortedServiceRecords: [ServiceRecord] {
        (serviceRecords ?? []).sorted { $0.date > $1.date }
    }

    /// Ultima intrare de schimb ulei / revizie filtre
    var lastOilChangeRecord: ServiceRecord? {
        sortedServiceRecords.first { $0.category == .oilAndFilters }
    }

    /// Calculul statusului pentru următorul schimb de ulei
    var oilChangeStatus: MaintenanceStatus? {
        guard let lastRecord = lastOilChangeRecord else {
            return nil
        }

        let baseMileage = lastRecord.mileage
        let targetMileage = baseMileage + oilChangeIntervalKm
        let currentKm = currentMileage ?? baseMileage
        let remainingKm = targetMileage - currentKm

        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .month, value: oilChangeIntervalMonths, to: lastRecord.date) ?? Date()
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: dueDate)
        let remainingDays = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0

        let isOverdue = remainingKm <= 0 || remainingDays <= 0
        let isDueSoon = !isOverdue && (remainingKm <= 1000 || remainingDays <= 30)

        let kmUsed = Double(max(0, currentKm - baseMileage))
        let kmProgress = min(1.0, max(0.0, kmUsed / Double(max(1, oilChangeIntervalKm))))

        let daysTotal = Double(max(1, calendar.dateComponents([.day], from: lastRecord.date, to: dueDate).day ?? 365))
        let daysPassed = Double(max(0, calendar.dateComponents([.day], from: lastRecord.date, to: today).day ?? 0))
        let timeProgress = min(1.0, max(0.0, daysPassed / daysTotal))

        return MaintenanceStatus(
            remainingKm: remainingKm,
            remainingDays: remainingDays,
            dueDate: dueDate,
            isOverdue: isOverdue,
            isDueSoon: isDueSoon,
            kmProgress: kmProgress,
            timeProgress: timeProgress,
            kmUsed: Int(kmUsed),
            targetKm: targetMileage,
            lastServiceDate: lastRecord.date
        )
    }
}

/// Structură ajutătoare pentru afișarea statusului de mentenanță
struct MaintenanceStatus {
    let remainingKm: Int
    let remainingDays: Int
    let dueDate: Date
    let isOverdue: Bool
    let isDueSoon: Bool
    let kmProgress: Double
    let timeProgress: Double
    let kmUsed: Int
    let targetKm: Int
    let lastServiceDate: Date

    enum LimitingFactor {
        case mileage
        case time
        case balanced
    }

    var limitingFactor: LimitingFactor {
        let diff = kmProgress - timeProgress
        if abs(diff) < 0.05 { return .balanced }
        return kmProgress > timeProgress ? .mileage : .time
    }

    var kmProgressPercent: Int {
        Int(min(1.0, max(0.0, kmProgress)) * 100)
    }

    var timeProgressPercent: Int {
        Int(min(1.0, max(0.0, timeProgress)) * 100)
    }

    var monthsRemaining: Int {
        max(0, (remainingDays + 15) / 30)
    }

    var statusColor: SwiftUI.Color {
        if isOverdue {
            return .red
        } else if isDueSoon {
            return .orange
        } else {
            return .green
        }
    }
}
