//
//  FuelEntry.swift
//  AutoGuard
//
//  Modelul SwiftData pentru o înregistrare de alimentare cu carburant.
//

import Foundation
import SwiftData

@Model
final class FuelEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var odometer: Int = 0           // Kilometraj bord la alimentare
    var liters: Double = 0.0        // Cantitate litri (sau kWh)
    var totalPrice: Double = 0.0    // Preț total plătit
    var isFullTank: Bool = true     // Plin complet
    var fuelTypeRaw: String = "petrol95"
    var notes: String? = nil
    var createdAt: Date = Date()

    // Relația inversă către vehicul
    var vehicle: Vehicle?

    init(
        odometer: Int,
        liters: Double,
        totalPrice: Double,
        date: Date = Date(),
        isFullTank: Bool = true,
        fuelType: FuelType = .petrol95,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.odometer = odometer
        self.liters = liters
        self.totalPrice = totalPrice
        self.date = date
        self.isFullTank = isFullTank
        self.fuelTypeRaw = fuelType.rawValue
        self.notes = notes
        self.createdAt = Date()
    }

    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .petrol95 }
        set { fuelTypeRaw = newValue.rawValue }
    }

    /// Preț pe unitate (per litru sau per kWh)
    var pricePerLiter: Double {
        guard liters > 0 else { return 0 }
        return totalPrice / liters
    }

    /// Preț pe litru formatat
    var formattedPricePerLiter: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: pricePerLiter)) ?? String(format: "%.2f", pricePerLiter)
        return "\(formatted) lei/\(fuelType.unitLabel)"
    }

    /// Preț total formatat
    var formattedTotalPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: totalPrice)) ?? String(format: "%.2f", totalPrice)
        return "\(formatted) lei"
    }

    /// Cantitate formatată
    var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: liters)) ?? String(format: "%.2f", liters)
        return "\(formatted) \(fuelType.unitLabel)"
    }

    /// Kilometraj formatat
    var formattedOdometer: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: odometer)) ?? "\(odometer)"
        return "\(formatted) km"
    }
}
