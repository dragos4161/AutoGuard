//
//  MileageEntry.swift
//  AutoGuard
//
//  Model SwiftData pentru înregistrarea istoricului de kilometri al mașinii.
//

import Foundation
import SwiftData

@Model
final class MileageEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var mileage: Int = 0
    var note: String? = nil

    // Relația inversă către mașină
    var vehicle: Vehicle?

    init(
        mileage: Int,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = UUID()
        self.mileage = mileage
        self.date = date
        self.note = note
    }

    /// Formatare cu separator de mii
    var formattedMileage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)"
        return "\(formatted) km"
    }
}
