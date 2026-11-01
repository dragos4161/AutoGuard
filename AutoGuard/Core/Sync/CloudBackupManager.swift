//
//  CloudBackupManager.swift
//  AutoGuard
//
//  Manager pentru generarea, salvarea, exportul și restaurarea copiilor de siguranță (Backup).
//  Asigură persistența datelor, migrarea între dispozitive și sincronizarea cu serviciile cloud.
//

import Foundation
import SwiftData
import SwiftUI

public enum RestoreStrategy {
    case merge      // Îmbină datele (actualizează mașinile existente, adaugă cele noi)
    case replace    // Înlocuiește complet datele locale cu cele din backup
}

@MainActor
@Observable
public final class CloudBackupManager {
    public static let shared = CloudBackupManager()

    public private(set) var isBackingUp: Bool = false
    public private(set) var isRestoring: Bool = false
    public private(set) var lastStatusMessage: String?
    public private(set) var lastBackupURL: URL?

    private init() {}

    // MARK: - Generare Snapshot din SwiftData

    /// Creează un snapshot complet al tuturor vehiculelor și înregistrărilor din baza de date
    public func createSnapshot(context: ModelContext) throws -> CloudBackupSnapshot {
        let descriptor = FetchDescriptor<Vehicle>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let vehicles = try context.fetch(descriptor)

        let vehicleDTOs: [VehicleBackupDTO] = vehicles.map { vehicle in
            let documentDTOs: [DocumentBackupDTO] = (vehicle.documents ?? []).map { doc in
                DocumentBackupDTO(
                    id: doc.id,
                    typeRawValue: doc.typeRawValue,
                    expirationDate: doc.expirationDate,
                    provider: doc.provider,
                    policyNumber: doc.policyNumber,
                    isArchived: doc.isArchived,
                    archivedAt: doc.archivedAt,
                    attachmentFileName: doc.attachmentFileName
                )
            }

            let mileageDTOs: [MileageBackupDTO] = (vehicle.mileageEntries ?? []).map { entry in
                MileageBackupDTO(
                    id: entry.id,
                    date: entry.date,
                    mileage: entry.mileage,
                    note: entry.note
                )
            }

            let serviceDTOs: [ServiceBackupDTO] = (vehicle.serviceRecords ?? []).map { record in
                ServiceBackupDTO(
                    id: record.id,
                    date: record.date,
                    mileage: record.mileage,
                    title: record.title,
                    categoryRawValue: record.categoryRawValue,
                    notes: record.notes,
                    price: record.price,
                    invoiceFileName: record.invoiceFileName
                )
            }

            let fuelDTOs: [FuelBackupDTO] = (vehicle.fuelEntries ?? []).map { fuel in
                FuelBackupDTO(
                    id: fuel.id,
                    date: fuel.date,
                    odometer: fuel.odometer,
                    liters: fuel.liters,
                    totalPrice: fuel.totalPrice,
                    isFullTank: fuel.isFullTank,
                    fuelTypeRaw: fuel.fuelTypeRaw,
                    notes: fuel.notes,
                    createdAt: fuel.createdAt
                )
            }

            return VehicleBackupDTO(
                id: vehicle.id,
                plateNumber: vehicle.plateNumber,
                make: vehicle.make,
                model: vehicle.model,
                year: vehicle.year,
                vin: vehicle.vin,
                nickname: vehicle.nickname,
                createdAt: vehicle.createdAt,
                oilChangeIntervalKm: vehicle.oilChangeIntervalKm,
                oilChangeIntervalMonths: vehicle.oilChangeIntervalMonths,
                documents: documentDTOs,
                mileageEntries: mileageDTOs,
                serviceRecords: serviceDTOs,
                fuelEntries: fuelDTOs
            )
        }

        let userIdentifier = AppleAuthService.shared.currentUser?.id
        return CloudBackupSnapshot(
            userIdentifier: userIdentifier,
            vehicles: vehicleDTOs
        )
    }

    // MARK: - Export Fișier de Backup

    /// Salvează snapshot-ul într-un fișier JSON portabil (.torpedou sau .json)
    public func exportBackupFile(context: ModelContext) throws -> URL {
        isBackingUp = true
        defer { isBackingUp = false }

        let snapshot = try createSnapshot(context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(snapshot)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "Torpedou_Backup_\(timestamp).json"

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)
        self.lastBackupURL = fileURL

        AppleAuthService.shared.recordBackupCompleted()
        lastStatusMessage = "Backup generat cu succes (\(snapshot.vehicles.count) vehicule)."

        return fileURL
    }

    // MARK: - Restaurare Snapshot în SwiftData

    /// Restaurează datele dintr-un snapshot în ModelContext-ul aplicației
    public func restore(
        from snapshot: CloudBackupSnapshot,
        context: ModelContext,
        strategy: RestoreStrategy = .merge
    ) throws {
        isRestoring = true
        defer { isRestoring = false }

        if strategy == .replace {
            let existingVehicles = try context.fetch(FetchDescriptor<Vehicle>())
            for vehicle in existingVehicles {
                context.delete(vehicle)
            }
            try context.save()
        }

        // Fetch mașini existente pentru verificare la merge
        let currentVehicles = try context.fetch(FetchDescriptor<Vehicle>())

        for vDTO in snapshot.vehicles {
            let existing = currentVehicles.first(where: {
                (!$0.vin.isEmpty && $0.vin == vDTO.vin) ||
                $0.plateNumber.uppercased() == vDTO.plateNumber.uppercased()
            })

            let targetVehicle: Vehicle
            if let existing {
                // Actualizăm vehiculul existent
                existing.make = vDTO.make
                existing.model = vDTO.model
                existing.year = vDTO.year
                existing.vin = vDTO.vin
                existing.nickname = vDTO.nickname
                existing.oilChangeIntervalKm = vDTO.oilChangeIntervalKm
                existing.oilChangeIntervalMonths = vDTO.oilChangeIntervalMonths
                targetVehicle = existing
            } else {
                // Creăm vehicul nou
                let newVehicle = Vehicle(
                    plateNumber: vDTO.plateNumber,
                    make: vDTO.make,
                    model: vDTO.model,
                    year: vDTO.year,
                    vin: vDTO.vin,
                    nickname: vDTO.nickname
                )
                newVehicle.id = vDTO.id
                newVehicle.createdAt = vDTO.createdAt
                newVehicle.oilChangeIntervalKm = vDTO.oilChangeIntervalKm
                newVehicle.oilChangeIntervalMonths = vDTO.oilChangeIntervalMonths
                context.insert(newVehicle)
                targetVehicle = newVehicle
            }

            // Restaurare documente
            let existingDocIds = Set((targetVehicle.documents ?? []).map { $0.id })
            for docDTO in vDTO.documents {
                if !existingDocIds.contains(docDTO.id) {
                    let docType = DocumentType(rawValue: docDTO.typeRawValue) ?? .rca
                    let newDoc = VehicleDocument(
                        type: docType,
                        expirationDate: docDTO.expirationDate,
                        provider: docDTO.provider,
                        policyNumber: docDTO.policyNumber,
                        isArchived: docDTO.isArchived,
                        attachmentFileName: docDTO.attachmentFileName
                    )
                    newDoc.id = docDTO.id
                    newDoc.archivedAt = docDTO.archivedAt
                    newDoc.vehicle = targetVehicle
                    context.insert(newDoc)
                }
            }

            // Restaurare intrări kilometraj
            let existingMileageIds = Set((targetVehicle.mileageEntries ?? []).map { $0.id })
            for mDTO in vDTO.mileageEntries {
                if !existingMileageIds.contains(mDTO.id) {
                    let newMileage = MileageEntry(
                        mileage: mDTO.mileage,
                        date: mDTO.date,
                        note: mDTO.note
                    )
                    newMileage.id = mDTO.id
                    newMileage.vehicle = targetVehicle
                    context.insert(newMileage)
                }
            }

            // Restaurare înregistrări service
            let existingServiceIds = Set((targetVehicle.serviceRecords ?? []).map { $0.id })
            for sDTO in vDTO.serviceRecords {
                if !existingServiceIds.contains(sDTO.id) {
                    let category = ServiceCategory(rawValue: sDTO.categoryRawValue) ?? .general
                    let newService = ServiceRecord(
                        title: sDTO.title,
                        category: category,
                        date: sDTO.date,
                        mileage: sDTO.mileage,
                        notes: sDTO.notes,
                        price: sDTO.price,
                        invoiceFileName: sDTO.invoiceFileName
                    )
                    newService.id = sDTO.id
                    newService.vehicle = targetVehicle
                    context.insert(newService)
                }
            }

            // Restaurare alimentări combustibil
            let existingFuelIds = Set((targetVehicle.fuelEntries ?? []).map { $0.id })
            for fDTO in vDTO.fuelEntries {
                if !existingFuelIds.contains(fDTO.id) {
                    let fuelType = FuelType(rawValue: fDTO.fuelTypeRaw) ?? .petrol95
                    let newFuel = FuelEntry(
                        odometer: fDTO.odometer,
                        liters: fDTO.liters,
                        totalPrice: fDTO.totalPrice,
                        date: fDTO.date,
                        isFullTank: fDTO.isFullTank,
                        fuelType: fuelType,
                        notes: fDTO.notes
                    )
                    newFuel.id = fDTO.id
                    newFuel.createdAt = fDTO.createdAt
                    newFuel.vehicle = targetVehicle
                    context.insert(newFuel)
                }
            }
        }

        try context.save()
        lastStatusMessage = "Restaurare finalizată cu succes (\(snapshot.vehicles.count) vehicule restaurate)."
    }

    // MARK: - Import dintr-un fișier extern

    /// Încarcă și decodează un fișier de backup
    public func importBackupFile(
        from url: URL,
        context: ModelContext,
        strategy: RestoreStrategy = .merge
    ) throws -> CloudBackupSnapshot {
        let isAccessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(CloudBackupSnapshot.self, from: data)
        try restore(from: snapshot, context: context, strategy: strategy)
        return snapshot
    }
}
