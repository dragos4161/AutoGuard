//
//  CloudBackupDTO.swift
//  AutoGuard
//
//  Structuri DTO (Data Transfer Object) Codable pentru export, backup în Cloud (Firebase / iCloud)
//  și restaurare completă fără pierdere de date.
//

import Foundation

// MARK: - Snapshot de Backup Principal

public struct CloudBackupSnapshot: Codable {
    public let schemaVersion: Int
    public let backupId: UUID
    public let createdAt: Date
    public let appName: String
    public let appVersion: String
    public let userIdentifier: String?
    public let vehicles: [VehicleBackupDTO]

    public init(
        schemaVersion: Int = 1,
        backupId: UUID = UUID(),
        createdAt: Date = Date(),
        appName: String = "Torpedou",
        appVersion: String = "1.0",
        userIdentifier: String? = nil,
        vehicles: [VehicleBackupDTO] = []
    ) {
        self.schemaVersion = schemaVersion
        self.backupId = backupId
        self.createdAt = createdAt
        self.appName = appName
        self.appVersion = appVersion
        self.userIdentifier = userIdentifier
        self.vehicles = vehicles
    }

    public var totalDocumentsCount: Int {
        vehicles.reduce(0) { $0 + $1.documents.count }
    }

    public var totalServiceRecordsCount: Int {
        vehicles.reduce(0) { $0 + $1.serviceRecords.count }
    }

    public var totalFuelEntriesCount: Int {
        vehicles.reduce(0) { $0 + $1.fuelEntries.count }
    }
}

// MARK: - Vehicul DTO

public struct VehicleBackupDTO: Codable, Identifiable {
    public let id: UUID
    public let plateNumber: String
    public let make: String
    public let model: String
    public let year: Int
    public let vin: String
    public let nickname: String
    public let createdAt: Date
    public let oilChangeIntervalKm: Int
    public let oilChangeIntervalMonths: Int
    public let documents: [DocumentBackupDTO]
    public let mileageEntries: [MileageBackupDTO]
    public let serviceRecords: [ServiceBackupDTO]
    public let fuelEntries: [FuelBackupDTO]

    public init(
        id: UUID,
        plateNumber: String,
        make: String,
        model: String,
        year: Int,
        vin: String,
        nickname: String,
        createdAt: Date,
        oilChangeIntervalKm: Int,
        oilChangeIntervalMonths: Int,
        documents: [DocumentBackupDTO],
        mileageEntries: [MileageBackupDTO],
        serviceRecords: [ServiceBackupDTO],
        fuelEntries: [FuelBackupDTO]
    ) {
        self.id = id
        self.plateNumber = plateNumber
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.nickname = nickname
        self.createdAt = createdAt
        self.oilChangeIntervalKm = oilChangeIntervalKm
        self.oilChangeIntervalMonths = oilChangeIntervalMonths
        self.documents = documents
        self.mileageEntries = mileageEntries
        self.serviceRecords = serviceRecords
        self.fuelEntries = fuelEntries
    }
}

// MARK: - Document DTO

public struct DocumentBackupDTO: Codable, Identifiable {
    public let id: UUID
    public let typeRawValue: String
    public let expirationDate: Date
    public let provider: String
    public let policyNumber: String
    public let isArchived: Bool
    public let archivedAt: Date?
    public let attachmentFileName: String?

    public init(
        id: UUID,
        typeRawValue: String,
        expirationDate: Date,
        provider: String,
        policyNumber: String,
        isArchived: Bool,
        archivedAt: Date?,
        attachmentFileName: String?
    ) {
        self.id = id
        self.typeRawValue = typeRawValue
        self.expirationDate = expirationDate
        self.provider = provider
        self.policyNumber = policyNumber
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.attachmentFileName = attachmentFileName
    }
}

// MARK: - Kilometraj DTO

public struct MileageBackupDTO: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let mileage: Int
    public let note: String?

    public init(
        id: UUID,
        date: Date,
        mileage: Int,
        note: String?
    ) {
        self.id = id
        self.date = date
        self.mileage = mileage
        self.note = note
    }
}

// MARK: - Service DTO

public struct ServiceBackupDTO: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let mileage: Int
    public let title: String
    public let categoryRawValue: String
    public let notes: String?
    public let price: Double?
    public let invoiceFileName: String?

    public init(
        id: UUID,
        date: Date,
        mileage: Int,
        title: String,
        categoryRawValue: String,
        notes: String?,
        price: Double?,
        invoiceFileName: String?
    ) {
        self.id = id
        self.date = date
        self.mileage = mileage
        self.title = title
        self.categoryRawValue = categoryRawValue
        self.notes = notes
        self.price = price
        self.invoiceFileName = invoiceFileName
    }
}

// MARK: - Alimentare DTO

public struct FuelBackupDTO: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let odometer: Int
    public let liters: Double
    public let totalPrice: Double
    public let isFullTank: Bool
    public let fuelTypeRaw: String
    public let notes: String?
    public let createdAt: Date

    public init(
        id: UUID,
        date: Date,
        odometer: Int,
        liters: Double,
        totalPrice: Double,
        isFullTank: Bool,
        fuelTypeRaw: String,
        notes: String?,
        createdAt: Date
    ) {
        self.id = id
        self.date = date
        self.odometer = odometer
        self.liters = liters
        self.totalPrice = totalPrice
        self.isFullTank = isFullTank
        self.fuelTypeRaw = fuelTypeRaw
        self.notes = notes
        self.createdAt = createdAt
    }
}
