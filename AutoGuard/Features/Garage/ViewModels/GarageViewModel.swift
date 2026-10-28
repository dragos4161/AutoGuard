//
//  GarageViewModel.swift
//  AutoGuard
//
//  ViewModel pentru ecranul principal (Garajul Meu).
//  Gestionează starea ecranului, calculează starea de liniște/urgență și apelează repository-ul.
//

import Foundation
import SwiftData

@Observable
final class GarageViewModel {
    // MARK: - State
    var isShowingAddVehicleSheet: Bool = false

    // MARK: - Dependencies
    private let repository: VehicleRepositoryProtocol

    init(repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()) {
        self.repository = repository
    }

    // MARK: - Business Logic: Calcul Status Emoțional (Liniște vs Atenție)
    func hasUrgentDocuments(in vehicles: [Vehicle]) -> Bool {
        vehicles.contains { vehicle in
            vehicle.activeDocuments.contains {
                $0.isExpired || $0.isExpiringSoon
            }
        }
    }

    /// Datele necesare pentru afișarea bannerului de liniște sufletească
    func statusBannerData(for vehicles: [Vehicle]) -> (
        titleKey: LocalizedStringResource, subtitleKey: LocalizedStringResource, isWarning: Bool
    ) {
        if hasUrgentDocuments(in: vehicles) {
            return (
                titleKey: "banner.warning.title",
                subtitleKey: "banner.warning.subtitle",
                isWarning: true
            )
        } else {
            return (
                titleKey: "banner.all_clear.title",
                subtitleKey: "banner.all_clear.subtitle",
                isWarning: false
            )
        }
    }

    // MARK: - Business Logic: Acțiuni pe date
    func deleteVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        repository.deleteVehicle(vehicle, in: context)
    }
}
