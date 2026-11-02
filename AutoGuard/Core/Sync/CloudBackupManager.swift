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
import UIKit

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

    /// Creează un snapshot complet al tuturor vehiculelor și înregistrărilor din baza de date.
    /// Când `compressImagesForCloud` este `true`, pozele atașate sunt comprimate automat pentru a respecta limita de 1 MB din Cloud Firestore.
    public func createSnapshot(context: ModelContext, compressImagesForCloud: Bool = false) throws -> CloudBackupSnapshot {
        let descriptor = FetchDescriptor<Vehicle>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let vehicles = try context.fetch(descriptor)

        let vehicleDTOs: [VehicleBackupDTO] = vehicles.map { vehicle in
            let documentDTOs: [DocumentBackupDTO] = (vehicle.documents ?? []).map { doc in
                let attachmentBytes = compressImagesForCloud
                    ? compressDataForCloud(doc.attachmentData, fileName: doc.attachmentFileName)
                    : doc.attachmentData
                return DocumentBackupDTO(
                    id: doc.id,
                    typeRawValue: doc.typeRawValue,
                    expirationDate: doc.expirationDate,
                    createdAt: doc.createdAt,
                    price: doc.price,
                    provider: doc.provider,
                    policyNumber: doc.policyNumber,
                    isArchived: doc.isArchived,
                    archivedAt: doc.archivedAt,
                    attachmentFileName: doc.attachmentFileName,
                    attachmentBase64: attachmentBytes?.base64EncodedString()
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
                let invoiceBytes = compressImagesForCloud
                    ? compressDataForCloud(record.invoiceData, fileName: record.invoiceFileName)
                    : record.invoiceData
                return ServiceBackupDTO(
                    id: record.id,
                    date: record.date,
                    mileage: record.mileage,
                    title: record.title,
                    categoryRawValue: record.categoryRawValue,
                    notes: record.notes,
                    price: record.price,
                    invoiceFileName: record.invoiceFileName,
                    invoiceBase64: invoiceBytes?.base64EncodedString()
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

            let regFront = compressImagesForCloud ? compressImageData(vehicle.registrationFrontData, maxDimension: 800, quality: 0.4) : vehicle.registrationFrontData
            let regBack = compressImagesForCloud ? compressImageData(vehicle.registrationBackData, maxDimension: 800, quality: 0.4) : vehicle.registrationBackData
            let licFront = compressImagesForCloud ? compressImageData(vehicle.driverLicenseFrontData, maxDimension: 800, quality: 0.4) : vehicle.driverLicenseFrontData
            let licBack = compressImagesForCloud ? compressImageData(vehicle.driverLicenseBackData, maxDimension: 800, quality: 0.4) : vehicle.driverLicenseBackData

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
                fuelEntries: fuelDTOs,
                registrationFrontBase64: regFront?.base64EncodedString(),
                registrationBackBase64: regBack?.base64EncodedString(),
                driverLicenseFrontBase64: licFront?.base64EncodedString(),
                driverLicenseBackBase64: licBack?.base64EncodedString()
            )
        }

        let userIdentifier = AppleAuthService.shared.currentUser?.id
        return CloudBackupSnapshot(
            userIdentifier: userIdentifier,
            vehicles: vehicleDTOs
        )
    }

    // MARK: - Helperi Compresie & Serializare Cloud Firestore

    /// Comprimă o imagine pentru sincronizarea în Firestore (astfel încât întregul document să rămână sub 1 MB)
    private func compressImageData(_ data: Data?, maxDimension: CGFloat = 1000, quality: CGFloat = 0.5) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let size = image.size
        let maxSide = max(size.width, size.height)
        let targetImage: UIImage
        if maxSide > maxDimension && maxSide > 0 {
            let scale = maxDimension / maxSide
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            targetImage = image
        }
        return targetImage.jpegData(compressionQuality: quality)
    }

    /// Comprimă atașamentele pentru Cloud (imaginile sunt optimizate; PDF-urile până la 15 MB sunt păstrate integral pentru Firebase Storage)
    private func compressDataForCloud(_ data: Data?, fileName: String?) -> Data? {
        guard let data else { return nil }
        let isPDF = fileName?.lowercased().hasSuffix(".pdf") == true
        if isPDF {
            return data.count <= 15 * 1024 * 1024 ? data : nil
        }
        return compressImageData(data, maxDimension: 1600, quality: 0.7)
    }

    /// Encodează un `VehicleBackupDTO` într-un dicționar compatibil Cloud Firestore.
    /// IMPORTANT: Cloud Firestore nu permite string-uri > 1.500 bytes în interiorul elementelor unui Array (`Property array contains an invalid entity`).
    /// Fișierele (PDF-uri și poze) sunt urcate în Firebase Storage, iar în Firestore salvăm doar căile (`attachmentStoragePath`, `invoiceStoragePath` etc.).
    public func encodeVehicleDictionary(_ vehicleDTO: VehicleBackupDTO) throws -> [String: Any] {
        let lightDocuments = vehicleDTO.documents.map { doc in
            DocumentBackupDTO(
                id: doc.id,
                typeRawValue: doc.typeRawValue,
                expirationDate: doc.expirationDate,
                createdAt: doc.createdAt,
                price: doc.price,
                provider: String(doc.provider.prefix(200)),
                policyNumber: String(doc.policyNumber.prefix(200)),
                isArchived: doc.isArchived,
                archivedAt: doc.archivedAt,
                attachmentFileName: doc.attachmentFileName,
                attachmentBase64: nil,
                attachmentStoragePath: doc.attachmentStoragePath
            )
        }
        let lightServices = vehicleDTO.serviceRecords.map { rec in
            ServiceBackupDTO(
                id: rec.id,
                date: rec.date,
                mileage: rec.mileage,
                title: String(rec.title.prefix(200)),
                categoryRawValue: rec.categoryRawValue,
                notes: rec.notes.map { String($0.prefix(500)) },
                price: rec.price,
                invoiceFileName: rec.invoiceFileName,
                invoiceBase64: nil,
                invoiceStoragePath: rec.invoiceStoragePath
            )
        }
        let lightMileages = vehicleDTO.mileageEntries.map { entry in
            MileageBackupDTO(
                id: entry.id,
                date: entry.date,
                mileage: entry.mileage,
                note: entry.note.map { String($0.prefix(500)) }
            )
        }
        let lightFuels = vehicleDTO.fuelEntries.map { fuel in
            FuelBackupDTO(
                id: fuel.id,
                date: fuel.date,
                odometer: fuel.odometer,
                liters: fuel.liters,
                totalPrice: fuel.totalPrice,
                isFullTank: fuel.isFullTank,
                fuelTypeRaw: fuel.fuelTypeRaw,
                notes: fuel.notes.map { String($0.prefix(500)) },
                createdAt: fuel.createdAt
            )
        }

        let sanitizedVehicle = VehicleBackupDTO(
            id: vehicleDTO.id,
            plateNumber: vehicleDTO.plateNumber,
            make: vehicleDTO.make,
            model: vehicleDTO.model,
            year: vehicleDTO.year,
            vin: vehicleDTO.vin,
            nickname: vehicleDTO.nickname,
            createdAt: vehicleDTO.createdAt,
            oilChangeIntervalKm: vehicleDTO.oilChangeIntervalKm,
            oilChangeIntervalMonths: vehicleDTO.oilChangeIntervalMonths,
            documents: lightDocuments,
            mileageEntries: lightMileages,
            serviceRecords: lightServices,
            fuelEntries: lightFuels,
            registrationFrontBase64: vehicleDTO.registrationFrontStoragePath == nil ? vehicleDTO.registrationFrontBase64 : nil,
            registrationBackBase64: vehicleDTO.registrationBackStoragePath == nil ? vehicleDTO.registrationBackBase64 : nil,
            driverLicenseFrontBase64: vehicleDTO.driverLicenseFrontStoragePath == nil ? vehicleDTO.driverLicenseFrontBase64 : nil,
            driverLicenseBackBase64: vehicleDTO.driverLicenseBackStoragePath == nil ? vehicleDTO.driverLicenseBackBase64 : nil,
            registrationFrontStoragePath: vehicleDTO.registrationFrontStoragePath,
            registrationBackStoragePath: vehicleDTO.registrationBackStoragePath,
            driverLicenseFrontStoragePath: vehicleDTO.driverLicenseFrontStoragePath,
            driverLicenseBackStoragePath: vehicleDTO.driverLicenseBackStoragePath
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sanitizedVehicle)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "CloudBackup", code: 500, userInfo: [NSLocalizedDescriptionKey: "Eroare la serializarea vehiculului."])
        }
        return dict
    }

    /// Decodează un dicționar din Cloud Firestore înapoi în `VehicleBackupDTO`
    public func decodeVehicleDictionary(_ dict: [String: Any]) throws -> VehicleBackupDTO {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VehicleBackupDTO.self, from: data)
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

            // Restaurare acte portofel (talon & permis)
            if let f = vDTO.registrationFrontBase64, !f.isEmpty {
                targetVehicle.registrationFrontData = Data(base64Encoded: f)
            }
            if let b = vDTO.registrationBackBase64, !b.isEmpty {
                targetVehicle.registrationBackData = Data(base64Encoded: b)
            }
            if let lf = vDTO.driverLicenseFrontBase64, !lf.isEmpty {
                targetVehicle.driverLicenseFrontData = Data(base64Encoded: lf)
            }
            if let lb = vDTO.driverLicenseBackBase64, !lb.isEmpty {
                targetVehicle.driverLicenseBackData = Data(base64Encoded: lb)
            }

            // Restaurare documente
            let existingDocIds = Set((targetVehicle.documents ?? []).map { $0.id })
            for docDTO in vDTO.documents {
                if !existingDocIds.contains(docDTO.id) {
                    let docType = DocumentType(rawValue: docDTO.typeRawValue) ?? .rca
                    let newDoc = VehicleDocument(
                        type: docType,
                        expirationDate: docDTO.expirationDate,
                        price: docDTO.price,
                        provider: docDTO.provider,
                        policyNumber: docDTO.policyNumber,
                        createdAt: docDTO.createdAt ?? Date(),
                        isArchived: docDTO.isArchived,
                        attachmentFileName: docDTO.attachmentFileName
                    )
                    if let base64 = docDTO.attachmentBase64, !base64.isEmpty {
                        newDoc.attachmentData = Data(base64Encoded: base64)
                    }
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
                    if let base64 = sDTO.invoiceBase64, !base64.isEmpty {
                        newService.invoiceData = Data(base64Encoded: base64)
                    }
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

        // Reîmprospătăm notificările și datele widget-urilor după restaurare
        if let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) {
            NotificationManager.shared.rescheduleAllReminders(for: vehicles)
            if let first = vehicles.first {
                WidgetDataManager.shared.updateWidgetData(for: first)
            }
        }

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
