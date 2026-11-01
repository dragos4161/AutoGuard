//
//  ServiceRecord.swift
//  AutoGuard
//
//  Model SwiftData pentru o intrare de service / revizie a mașinii.
//

import Foundation
import SwiftData

@Model
final class ServiceRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var mileage: Int = 0
    var title: String = ""
    var categoryRawValue: String = ServiceCategory.oilAndFilters.rawValue
    var notes: String? = nil
    var price: Double? = nil

    // Atașament opțional pentru factură / bon / deviz
    @Attribute(.externalStorage)
    var invoiceData: Data? = nil
    var invoiceFileName: String? = nil

    // Relația inversă către mașină
    var vehicle: Vehicle?

    init(
        title: String,
        category: ServiceCategory = .oilAndFilters,
        date: Date = Date(),
        mileage: Int = 0,
        notes: String? = nil,
        price: Double? = nil,
        invoiceData: Data? = nil,
        invoiceFileName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRawValue = category.rawValue
        self.date = date
        self.mileage = mileage
        self.notes = notes
        self.price = price
        self.invoiceData = invoiceData
        self.invoiceFileName = invoiceFileName
    }

    /// Categoria convertită în enum tipizat
    var category: ServiceCategory {
        get { ServiceCategory(rawValue: categoryRawValue) ?? .general }
        set { categoryRawValue = newValue.rawValue }
    }

    /// Are factură sau deviz atașat?
    var hasInvoice: Bool {
        invoiceData != nil
    }

    /// Preț formatat (ex: "750,00 lei")
    var formattedPrice: String? {
        guard let price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RON"
        formatter.locale = Locale(identifier: "ro_RO")
        return formatter.string(from: NSNumber(value: price))
    }

    /// Formatare kilometraj
    var formattedMileage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)"
        return "\(formatted) km"
    }
}
