//
//  VehicleExportService.swift
//  AutoGuard
//
//  Serviciu pentru exportul istoricului complet de cheltuieli, service și carburant
//  în fișier tabelar CSV (compatibil Excel, Numbers, Google Sheets) cu suport complet UTF-8 BOM.
//

import Foundation

@MainActor
final class VehicleExportService {
    static let shared = VehicleExportService()

    private init() {}

    // MARK: - Export Cheltuieli în Format CSV
    /// Generează un fișier CSV complet cu toate operațiunile financiare (Service + Carburant) ale vehiculului
    func generateExpensesCsv(for vehicle: Vehicle) -> URL? {
        let sanitizedPlate = vehicle.plateNumber
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let prefix = AppLanguage.tr("Cheltuieli", "Expenses")
        let fallbackPlate = AppLanguage.tr("Vehicul", "Vehicle")
        let fileName = "\(prefix)_\(sanitizedPlate.isEmpty ? fallbackPlate : sanitizedPlate).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Adăugăm BOM (Byte Order Mark) UTF-8 pentru ca Microsoft Excel să deschidă corect diacriticele românești
        var csvContent = "\u{FEFF}"

        // Antetul tabelului
        csvContent += AppLanguage.tr(
            "Tip Înregistrare;Data;Kilometraj (km);Categorie;Denumire / Titlu;Detalii / Cantitate;Cost (RON);Notițe\n",
            "Entry Type;Date;Odometer (km);Category;Title;Details / Quantity;Cost (RON);Notes\n"
        )

        // Colectăm toate intrările într-o listă unificată pentru sortare cronologică
        var entries: [ExportEntry] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"

        // 1. Intrări de Service
        for record in (vehicle.serviceRecords ?? []) {
            let catName = record.category.localizedTitle
            entries.append(
                ExportEntry(
                    date: record.date,
                    type: AppLanguage.tr("Service / Revizie", "Service / Maintenance"),
                    dateString: dateFormatter.string(from: record.date),
                    odometer: "\(record.mileage)",
                    category: catName,
                    title: record.title,
                    details: record.invoiceFileName ?? "",
                    amount: record.price ?? 0.0,
                    notes: record.notes ?? ""
                )
            )
        }

        // 2. Intrări de Carburant
        for fuel in (vehicle.fuelEntries ?? []) {
            let details = String(format: "%.2f L (%.2f lei/L)", fuel.liters, fuel.pricePerLiter)
            entries.append(
                ExportEntry(
                    date: fuel.date,
                    type: AppLanguage.tr("Carburant", "Fuel"),
                    dateString: dateFormatter.string(from: fuel.date),
                    odometer: "\(fuel.odometer)",
                    category: fuel.fuelType.defaultDisplayName,
                    title: "\(AppLanguage.tr("Alimentare", "Fuel")) \(fuel.fuelType.defaultDisplayName)",
                    details: details,
                    amount: fuel.totalPrice,
                    notes: fuel.notes ?? ""
                )
            )
        }

        // 3. Intrări de Acte, Asigurări și Taxe de Drum (RCA, ITP, Rovinietă RO / Străinătate, CASCO)
        for doc in (vehicle.documents ?? []) {
            guard let price = doc.price, price > 0 else { continue }
            let expString = "\(AppLanguage.tr("Expiră", "Expires")): \(dateFormatter.string(from: doc.expirationDate))"
            entries.append(
                ExportEntry(
                    date: doc.createdAt,
                    type: AppLanguage.tr("Acte & Taxe", "Documents & Tolls"),
                    dateString: dateFormatter.string(from: doc.createdAt),
                    odometer: "",
                    category: doc.type.title,
                    title: doc.provider.isEmpty ? doc.type.title : "\(doc.type.title) (\(doc.provider))",
                    details: expString,
                    amount: price,
                    notes: doc.isArchived ? AppLanguage.tr("Arhivat (Istoric)", "Archived (History)") : AppLanguage.tr("Activ", "Active")
                )
            )
        }

        // Sortăm descrescător după dată (cele mai recente primele)
        entries.sort { $0.date > $1.date }

        for entry in entries {
            let row = [
                escapeCsv(entry.type),
                escapeCsv(entry.dateString),
                escapeCsv(entry.odometer),
                escapeCsv(entry.category),
                escapeCsv(entry.title),
                escapeCsv(entry.details),
                escapeCsv(String(format: "%.2f", entry.amount)),
                escapeCsv(entry.notes)
            ].joined(separator: ";")
            csvContent += row + "\n"
        }

        // Rânduri finale de sumar
        csvContent += "\n"
        csvContent += AppLanguage.tr("SUMAR CHELTUIELI;;;;;;;\n", "EXPENSE SUMMARY;;;;;;;\n")
        csvContent += "\(AppLanguage.tr("Total Service (RON)", "Total Service (RON)"));;;;;;\(String(format: "%.2f", vehicle.totalServiceSpent));\n"
        csvContent += "\(AppLanguage.tr("Total Carburant (RON)", "Total Fuel (RON)"));;;;;;\(String(format: "%.2f", vehicle.totalFuelSpent));\n"
        csvContent += "\(AppLanguage.tr("Total Acte, RCA, ITP & Taxe Drum (RON)", "Total Documents, RCA, ITP & Tolls (RON)"));;;;;;\(String(format: "%.2f", vehicle.totalDocumentsSpent));\n"
        csvContent += "\(AppLanguage.tr("TOTAL GENERAL INVESTIȚIE (RON)", "GRAND TOTAL INVESTMENT (RON)"));;;;;;\(String(format: "%.2f", vehicle.totalOverallSpent));\n"

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Eroare la scrierea fișierului CSV: \(error)")
            return nil
        }
    }

    private func escapeCsv(_ text: String) -> String {
        var clean = text.replacingOccurrences(of: "\"", with: "\"\"")
        clean = clean.replacingOccurrences(of: "\n", with: " ")
        if clean.contains(";") || clean.contains("\"") || clean.contains(",") {
            return "\"\(clean)\""
        }
        return clean
    }

    private struct ExportEntry {
        let date: Date
        let type: String
        let dateString: String
        let odometer: String
        let category: String
        let title: String
        let details: String
        let amount: Double
        let notes: String
    }
}
