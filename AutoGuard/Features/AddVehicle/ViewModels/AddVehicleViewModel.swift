//
//  AddVehicleViewModel.swift
//  AutoGuard
//
//  ViewModel pentru formularul de adăugare mașină (Business Logic & State).
//  În Flutter: echivalentul unui `ChangeNotifier` sau `Cubit`.
//

import Foundation
import SwiftData

@Observable
final class AddVehicleViewModel {
    // MARK: - State (Proprietăți legate de formular)
    var plateNumber: String = ""
    var make: String = ""
    var model: String = ""
    var year: Int = Calendar.current.component(.year, from: Date())
    var nickname: String = ""
    var vin: String = ""
    var initialMileageText: String = ""

    // Termene inițiale și costuri (opționale)
    var rcaDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var rcaPriceText: String = ""

    var itpDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var itpPriceText: String = ""

    var rovinietaDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var rovinietaPriceText: String = ""

    // Documente opționale (Vinietă Străinătate, CASCO, Trusă & Stingător)
    var includeForeignVignette: Bool = false
    var foreignVignetteDate: Date =
        Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
    var foreignVignetteCountry: String = ""
    var foreignVignettePriceText: String = ""

    var includeCasco: Bool = false
    var cascoDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var cascoPriceText: String = ""

    var includeExtinguisher: Bool = false
    var extinguisherDate: Date =
        Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    var extinguisherPriceText: String = ""

    // MARK: - Dependencies
    private let repository: VehicleRepositoryProtocol

    init(repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()) {
        self.repository = repository
    }

    // MARK: - Business Logic: Validare
    var isVinValid: Bool {
        let cleanVin = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Dacă e gol, e permis (opțional). Dacă are ceva scris, verificăm regula celor 17 caractere:
        if cleanVin.isEmpty { return true }
        
        let vinRegex = "^[A-HJ-NPR-Z0-9]{17}$"
        return cleanVin.range(of: vinRegex, options: .regularExpression) != nil
    }
    var isFormValid: Bool {
        let cleanPlate = plateNumber.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let cleanMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !cleanPlate.isEmpty && !cleanMake.isEmpty && isVinValid
    }

    // Formatare automată număr înmatriculare (ex: majuscule fără spații duble)
    var formattedPlateNumber: String {
        plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func parsePrice(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    // MARK: - Business Logic: Salvare
    func saveVehicle(in context: ModelContext) -> Bool {
        guard isFormValid else { return false }

        // 1. Instanțiem entitatea Vehicul
        let vehicle = Vehicle(
            plateNumber: formattedPlateNumber,
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            vin: vin.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        // 2. Creăm documentele obligatorii + cele opționale bifate (împreună cu prețurile lor)
        let rca = VehicleDocument(
            type: .rca,
            expirationDate: rcaDate,
            price: parsePrice(rcaPriceText)
        )
        let itp = VehicleDocument(
            type: .itp,
            expirationDate: itpDate,
            price: parsePrice(itpPriceText)
        )
        let rovinieta = VehicleDocument(
            type: .rovinieta,
            expirationDate: rovinietaDate,
            price: parsePrice(rovinietaPriceText),
            provider: AppLanguage.tr("România", "Romania")
        )

        var createdDocs: [VehicleDocument] = [rca, itp, rovinieta]
        if includeForeignVignette {
            createdDocs.append(
                VehicleDocument(
                    type: .foreignVignette,
                    expirationDate: foreignVignetteDate,
                    price: parsePrice(foreignVignettePriceText),
                    provider: foreignVignetteCountry.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        if includeCasco {
            createdDocs.append(
                VehicleDocument(
                    type: .casco,
                    expirationDate: cascoDate,
                    price: parsePrice(cascoPriceText)
                )
            )
        }
        if includeExtinguisher {
            createdDocs.append(
                VehicleDocument(
                    type: .extinguisher,
                    expirationDate: extinguisherDate,
                    price: parsePrice(extinguisherPriceText)
                )
            )
        }

        vehicle.documents = createdDocs

        // 3. Kilometraj inițial (opțional)
        if let initialMileage = Int(initialMileageText.filter { $0.isNumber }) {
            let mileageEntry = MileageEntry(mileage: initialMileage, date: Date())
            mileageEntry.vehicle = vehicle
            vehicle.mileageEntries = [mileageEntry]
        }

        // 4. Salvăm prin Repository
        repository.insertVehicle(vehicle, in: context)

        // 5. Programăm notificările pentru noile documente și revizie
        for doc in createdDocs {
            NotificationManager.shared.scheduleDocumentReminders(for: doc, vehicleName: vehicle.displayName)
        }
        NotificationManager.shared.scheduleMaintenanceReminder(for: vehicle)
        WidgetDataManager.shared.updateWidgetData(for: vehicle)

        return true
    }
}
