//
//  EditVehicleViewModel.swift
//  AutoGuard
//
//  ViewModel pentru formularul de editare al unei mașini existente.
//

import Foundation
import SwiftData

@Observable
final class EditVehicleViewModel {
    let vehicle: Vehicle

    // Câmpuri editabile legate bi-direcțional de Form
    var plateNumber: String
    var make: String
    var model: String
    var year: Int
    var vin: String
    var nickname: String
    var documentDates: [UUID: Date] = [:]
    var documentPrices: [UUID: String] = [:]

    private let repository: VehicleRepositoryProtocol

    init(
        vehicle: Vehicle,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.plateNumber = vehicle.plateNumber
        self.make = vehicle.make
        self.model = vehicle.model
        self.year = vehicle.year
        self.vin = vehicle.vin
        self.nickname = vehicle.nickname
        self.repository = repository

        for doc in vehicle.activeDocuments {
            self.documentDates[doc.id] = doc.expirationDate
            if let price = doc.price, price > 0 {
                self.documentPrices[doc.id] = String(format: "%.0f", price)
            } else {
                self.documentPrices[doc.id] = ""
            }
        }
    }

    // MARK: - Validation
    var isVinValid: Bool {
        let clean = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.isEmpty { return true }
        let regex = "^[A-HJ-NPR-Z0-9]{17}$"
        return clean.range(of: regex, options: .regularExpression) != nil
    }

    var isFormValid: Bool {
        let cleanPlate = plateNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMake = make.trimmingCharacters(in: .whitespacesAndNewlines)

        return !cleanPlate.isEmpty && !cleanMake.isEmpty && isVinValid
    }

    // MARK: - Actions
    func saveChanges(in context: ModelContext) -> Bool {
        guard isFormValid else { return false }

        repository.updateVehicle(
            vehicle,
            plateNumber: plateNumber,
            make: make,
            model: model,
            year: year,
            vin: vin,
            nickname: nickname,
            in: context
        )

        // Corectarea eventualelor date de expirare și prețuri ale documentelor active
        for doc in vehicle.activeDocuments {
            let updatedDate = documentDates[doc.id] ?? doc.expirationDate
            let priceStr = (documentPrices[doc.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            let parsedPrice = (Double(priceStr) ?? 0) > 0 ? Double(priceStr) : nil

            if updatedDate != doc.expirationDate || parsedPrice != doc.price {
                repository.correctDocumentDate(
                    doc,
                    correctedDate: updatedDate,
                    price: parsedPrice,
                    provider: doc.provider,
                    in: context
                )
            }
        }
        return true
    }
}
