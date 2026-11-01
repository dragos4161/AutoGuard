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

    // MARK: - Kilometraj
    func addMileageEntry(
        _ mileage: Int,
        date: Date,
        note: String?,
        for vehicle: Vehicle,
        in context: ModelContext
    ) -> MileageEntry
    func deleteMileageEntry(_ entry: MileageEntry, in context: ModelContext)

    // MARK: - Service & Mentenanță
    func addServiceRecord(
        title: String,
        category: ServiceCategory,
        date: Date,
        mileage: Int,
        notes: String?,
        price: Double?,
        invoiceData: Data?,
        invoiceFileName: String?,
        for vehicle: Vehicle,
        in context: ModelContext
    ) -> ServiceRecord
    func deleteServiceRecord(_ record: ServiceRecord, in context: ModelContext)
    func updateMaintenanceIntervals(
        oilIntervalKm: Int,
        oilIntervalMonths: Int,
        for vehicle: Vehicle,
        in context: ModelContext
    )
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

    // MARK: - Kilometraj
    @discardableResult
    func addMileageEntry(
        _ mileage: Int,
        date: Date,
        note: String?,
        for vehicle: Vehicle,
        in context: ModelContext
    ) -> MileageEntry {
        let entry = MileageEntry(mileage: mileage, date: date, note: note)
        entry.vehicle = vehicle

        if vehicle.mileageEntries == nil {
            vehicle.mileageEntries = []
        }
        vehicle.mileageEntries?.append(entry)

        context.insert(entry)
        try? context.save()
        return entry
    }

    func deleteMileageEntry(_ entry: MileageEntry, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    // MARK: - Service & Mentenanță
    @discardableResult
    func addServiceRecord(
        title: String,
        category: ServiceCategory,
        date: Date,
        mileage: Int,
        notes: String?,
        price: Double?,
        invoiceData: Data?,
        invoiceFileName: String?,
        for vehicle: Vehicle,
        in context: ModelContext
    ) -> ServiceRecord {
        let record = ServiceRecord(
            title: title,
            category: category,
            date: date,
            mileage: mileage,
            notes: notes,
            price: price,
            invoiceData: invoiceData,
            invoiceFileName: invoiceFileName
        )
        record.vehicle = vehicle

        if vehicle.serviceRecords == nil {
            vehicle.serviceRecords = []
        }
        vehicle.serviceRecords?.append(record)
        context.insert(record)

        // Dacă km introduși la service sunt mai mari decât kilometrajul curent, actualizăm și odometrul
        if mileage > (vehicle.currentMileage ?? 0) {
            _ = addMileageEntry(
                mileage,
                date: date,
                note: "Service: \(title)",
                for: vehicle,
                in: context
            )
        }

        try? context.save()
        return record
    }

    func deleteServiceRecord(_ record: ServiceRecord, in context: ModelContext) {
        context.delete(record)
        try? context.save()
    }

    func updateMaintenanceIntervals(
        oilIntervalKm: Int,
        oilIntervalMonths: Int,
        for vehicle: Vehicle,
        in context: ModelContext
    ) {
        vehicle.oilChangeIntervalKm = oilIntervalKm
        vehicle.oilChangeIntervalMonths = oilIntervalMonths
        try? context.save()
    }
}
