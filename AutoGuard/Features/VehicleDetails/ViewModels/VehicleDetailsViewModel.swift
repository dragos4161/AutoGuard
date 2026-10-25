//
//  VehicleDetailsViewModel.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import Foundation
import SwiftData

@Observable
final class VehicleDetailsViewModel{
    // MARK: - Variables
    var isShowingRenewalSheet: Bool = false
    var selectedDocument: VehicleDocument? = nil
    var isShowingAlert: Bool = false
    var renewalDate: Date = Date()
    
    // MARK: - Dependencies
    private let repository:VehicleRepositoryProtocol
    init(repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()) {
        self.repository = repository
    }
    
    //MARK: - Business Logic - Sort documents
    func sortDocuments(for vehicle:Vehicle) -> [VehicleDocument] {
        (vehicle.documents ?? []).sorted{$0.daysRemaining<$1.daysRemaining }
    }
    
    //MARK: - Business Logic - Preapare renewal
    func prepareRenewal(for document: VehicleDocument) {
        renewalDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        selectedDocument = document
        isShowingRenewalSheet = true
    }
    
    //MARK: - Business Logic - Confirm Renewal
    func confirmRenewal() {
        guard let selectedDocument else {
            return
        }
        
        repository.updateVehicleDocument(selectedDocument, newExpiryDate: renewalDate)
        isShowingRenewalSheet = false
    }
    
    //MARK: - Business Logic = Delete Vehicle
    func deleteVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        repository.deleteVehicle(vehicle, in: context)
    }
}
