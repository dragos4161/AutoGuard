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
    func updateVehicle(
        _ vehicle: Vehicle,
        plateNumber: String,
        make: String,
        model: String,
        year: Int,
        vin: String,
        nickname: String,
        in context: ModelContext
    )
    func updateVehicleDocument(_ document: VehicleDocument, newExpiryDate: Date)
    func correctDocumentDate(
        _ document: VehicleDocument,
        correctedDate: Date,
        in context: ModelContext
    )
    func renewVehicleDocument(
        _ oldDocument: VehicleDocument,
        newExpiryDate: Date,
        in context: ModelContext
    )
    func updateDocumentAttachment(
        _ document: VehicleDocument,
        data: Data?,
        fileName: String?,
        in context: ModelContext
    )
    func deleteDocument(_ document: VehicleDocument, in context: ModelContext)
}

/// Implementarea concretă pentru SwiftData (stocare locală pe telefon)
final class SwiftDataVehicleRepository: VehicleRepositoryProtocol {
    func insertVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        context.insert(vehicle)
    }

    func deleteVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        context.delete(vehicle)
    }

    func updateVehicle(
        _ vehicle: Vehicle,
        plateNumber: String,
        make: String,
        model: String,
        year: Int,
        vin: String,
        nickname: String,
        in context: ModelContext
    ) {
        vehicle.plateNumber = plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vehicle.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.year = year
        vehicle.vin = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vehicle.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }

    func updateVehicleDocument(_ document: VehicleDocument, newExpiryDate: Date)
    {
        document.expirationDate = newExpiryDate
    }

    /// Corectează data de expirare a unui document existent (fără a crea istoric)
    func correctDocumentDate(
        _ document: VehicleDocument,
        correctedDate: Date,
        in context: ModelContext
    ) {
        document.expirationDate = correctedDate
        try? context.save()
    }

    /// Reînnoiește un document: îl mută pe cel vechi în istoric și creează unul nou activ
    func renewVehicleDocument(
        _ oldDocument: VehicleDocument,
        newExpiryDate: Date,
        in context: ModelContext
    ) {
        oldDocument.isArchived = true
        oldDocument.archivedAt = Date()

        let newDocument = VehicleDocument(
            type: oldDocument.type,
            expirationDate: newExpiryDate,
            provider: oldDocument.provider,
            isArchived: false
        )

        if let vehicle = oldDocument.vehicle {
            if vehicle.documents == nil {
                vehicle.documents = []
            }
            vehicle.documents?.append(newDocument)
        }
        context.insert(newDocument)
        try? context.save()
    }

    /// Atașează sau șterge un fișier PDF / Poză asociat unui document
    func updateDocumentAttachment(
        _ document: VehicleDocument,
        data: Data?,
        fileName: String?,
        in context: ModelContext
    ) {
        document.attachmentData = data
        document.attachmentFileName = fileName
        try? context.save()
    }

    func deleteDocument(_ document: VehicleDocument, in context: ModelContext) {
        context.delete(document)
        try? context.save()
    }
}
