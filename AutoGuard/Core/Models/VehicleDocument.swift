//
//  VehicleDocument.swift
//  AutoGuard
//
//  Model SwiftData pentru un document expirobil (RCA, ITP, Rovinietă etc.)
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class VehicleDocument {
    var id: UUID = UUID()
    var typeRawValue: String = DocumentType.rca.rawValue
    var expirationDate: Date = Date()
    var provider: String = ""  // Ex: Omniasig, Groupama, CNAIR
    var policyNumber: String = ""  // Serie/Număr poliță sau bon
    var isArchived: Bool = false  // true dacă documentul a fost reînnoit și mutat în istoric
    var archivedAt: Date? = nil   // Data la care a fost arhivat

    // Stocare externă optimizată pentru fișiere mari (PDF sau Poză), compatibilă cu CloudKit CKAsset
    @Attribute(.externalStorage)
    var attachmentData: Data? = nil
    var attachmentFileName: String? = nil

    // Relația inversă către mașină (se populează automat de SwiftData)
    var vehicle: Vehicle?

    init(
        type: DocumentType,
        expirationDate: Date,
        provider: String = "",
        policyNumber: String = "",
        isArchived: Bool = false,
        attachmentData: Data? = nil,
        attachmentFileName: String? = nil
    ) {
        self.id = UUID()
        self.typeRawValue = type.rawValue
        self.expirationDate = expirationDate
        self.provider = provider
        self.policyNumber = policyNumber
        self.isArchived = isArchived
        self.attachmentData = attachmentData
        self.attachmentFileName = attachmentFileName
    }

    /// Indică dacă documentul are un fișier PDF sau o poză atașată
    var hasAttachment: Bool {
        attachmentData != nil
    }

    /// Tipul convertit în enum-ul sigur de tip `DocumentType`
    var type: DocumentType {
        get { DocumentType(rawValue: typeRawValue) ?? .rca }
        set { typeRawValue = newValue.rawValue }
    }

    /// Numărul de zile rămase până la expirare
    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: expirationDate)
        let components = calendar.dateComponents(
            [.day],
            from: today,
            to: target
        )
        return components.day ?? 0
    }

    /// Este documentul deja expirat?
    var isExpired: Bool {
        daysRemaining < 0
    }

    /// Expiră în curând (în mai puțin de 30 de zile)?
    var isExpiringSoon: Bool {
        daysRemaining >= 0 && daysRemaining <= 30
    }

    /// Culoarea semantică conform Apple HIG
    var statusColor: Color {
        if isExpired {
            return .red
        } else if isExpiringSoon {
            return .orange
        } else {
            return .green
        }
    }
}
