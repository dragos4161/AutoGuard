//
//  VehicleRepository.swift
//  AutoGuard
//
//  Repository Pattern: Abstracția pentru operațiile pe baza de date.
//  Permite comutarea viitoare de la SwiftData la Firebase fără a schimba codul din ViewModels sau Views!
//

import Foundation
import SwiftData

/// Protocolul pe care îl cunosc ViewModel-urile (în Flutter: interfața abstractă a Repository-ului)
protocol VehicleRepositoryProtocol: Sendable {
    func insertVehicle(_ vehicle: Vehicle, in context: ModelContext)
    func deleteVehicle(_ vehicle: Vehicle, in context: ModelContext)
    func updateVehicleDocument(_ document:VehicleDocument, newExpiryDate: Date)
}

/// Implementarea concretă pentru SwiftData (stocare locală pe telefon)
final class SwiftDataVehicleRepository: VehicleRepositoryProtocol {
    func insertVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        context.insert(vehicle)
    }

    func deleteVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        context.delete(vehicle)
    }
    
    func updateVehicleDocument(_ document:VehicleDocument, newExpiryDate: Date) {
        document.expirationDate = newExpiryDate
    }
}
