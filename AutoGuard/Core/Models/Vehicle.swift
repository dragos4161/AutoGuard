//
//  Vehicle.swift
//  AutoGuard
//
//  Modelul principal SwiftData pentru un vehicul din garajul utilizatorului.
//

import Foundation
import SwiftData

@Model
final class Vehicle {
    var id: UUID = UUID()
    var plateNumber: String = "" // Ex: B 123 ABC
    var make: String = ""        // Ex: Dacia, Volkswagen, BMW
    var model: String = ""       // Ex: Duster, Golf, Seria 3
    var year: Int = 2023
    var vin: String = ""         // Serie șasiu (17 caractere)
    var nickname: String = ""    // Ex: "Mașina familiei"
    var createdAt: Date = Date()

    // Relație one-to-many cu documentele mașinii (opțională pentru compatibilitate CloudKit)
    @Relationship(deleteRule: .cascade, inverse: \VehicleDocument.vehicle)
    var documents: [VehicleDocument]? = []

    init(
        plateNumber: String,
        make: String,
        model: String,
        year: Int = Calendar.current.component(.year, from: Date()),
        vin: String = "",
        nickname: String = ""
    ) {
        self.id = UUID()
        self.plateNumber = plateNumber.uppercased()
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin.uppercased()
        self.nickname = nickname
        self.createdAt = Date()
    }

    /// Găsește un document specific (ex: RCA sau ITP)
    func document(for type: DocumentType) -> VehicleDocument? {
        (documents ?? []).first { $0.type == type }
    }

    /// Cel mai urgent document (cel cu cele mai puține zile rămase)
    var mostUrgentDocument: VehicleDocument? {
        (documents ?? []).min { $0.daysRemaining < $1.daysRemaining }
    }

    /// Titlul complet al mașinii pentru interfață
    var displayName: String {
        let name = "\(make) \(model)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? plateNumber : name
    }
}
