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

    // Termene inițiale
    var rcaDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var itpDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var rovinietaDate: Date =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    // MARK: - Dependencies
    private let repository: VehicleRepositoryProtocol

    init(repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()) {
        self.repository = repository
    }

    // MARK: - Business Logic: Validare
    var isFormValid: Bool {
        let cleanPlate = plateNumber.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let cleanMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanPlate.isEmpty && !cleanMake.isEmpty
    }

    // Formatare automată număr înmatriculare (ex: majuscule fără spații duble)
    var formattedPlateNumber: String {
        plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        // 2. Creăm documentele obligatorii
        let rca = VehicleDocument(type: .rca, expirationDate: rcaDate)
        let itp = VehicleDocument(type: .itp, expirationDate: itpDate)
        let rovinieta = VehicleDocument(
            type: .rovinieta,
            expirationDate: rovinietaDate
        )

        vehicle.documents = [rca, itp, rovinieta]

        // 3. Salvăm prin Repository
        repository.insertVehicle(vehicle, in: context)
        return true
    }
}
