//
//  VehicleReportPdfTemplate.swift
//  AutoGuard
//
//  Șablon vizual SwiftUI formatat pentru generarea documentului PDF "Carte de Service".
//

import SwiftUI

struct VehicleReportPdfTemplate: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: - Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.side.fill")
                            .font(.title2)
                            .foregroundStyle(Color.blue)

                        Text("TORPEDOU / GLOVEBOX")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color.blue)
                    }

                    Text(AppLanguage.tr("RAPORT DE SERVICE & STARE TEHNICĂ", "SERVICE & TECHNICAL CONDITION REPORT"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(white: 0.3))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppLanguage.tr("DATA EMITERII", "ISSUE DATE"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondary)

                    Text(Date().formatted(date: .long, time: .omitted))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(.bottom, 6)

            Divider()

            // MARK: - Date Identificare Vehicul
            VStack(alignment: .leading, spacing: 10) {
                Text(AppLanguage.tr("DATE IDENTIFICARE VEHICUL", "VEHICLE IDENTIFICATION"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.blue)

                HStack(spacing: 16) {
                    // Număr înmatriculare stil plăcuță
                    VStack(alignment: .center, spacing: 2) {
                        Text("RO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.blue)
                        Text(vehicle.plateNumber)
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: 1.5)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            Text("\(AppLanguage.tr("An", "Year")): \(String(vehicle.year))")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(white: 0.3))

                            if let km = vehicle.formattedMileage {
                                Text("•")
                                Text("\(AppLanguage.tr("Kilometraj", "Mileage")): \(km)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                            }
                        }

                        if !vehicle.vin.isEmpty {
                            Text("VIN: \(vehicle.vin)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.4))
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // MARK: - Situația Documentelor Obligatorii
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLanguage.tr("SITUAȚIA ACTELOR & ASIGURĂRILOR", "DOCUMENTS & INSURANCE STATUS"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.blue)

                VStack(spacing: 4) {
                    ForEach(vehicle.activeDocuments) { doc in
                        HStack {
                            Text(doc.type.title)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 130, alignment: .leading)

                            if !doc.provider.isEmpty {
                                Text(doc.provider)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(white: 0.4))
                                    .frame(width: 120, alignment: .leading)
                            } else {
                                Spacer()
                            }

                            Text("\(AppLanguage.tr("Expirare", "Expires")): \(doc.expirationDate.formatted(date: .numeric, time: .omitted))")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(white: 0.3))

                            if let formattedPrice = doc.formattedPrice {
                                Text("• \(formattedPrice)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.primary)
                            }

                            Spacer()

                            let statusBadgeText = doc.isExpired
                                ? AppLanguage.tr("Expirat", "Expired")
                                : (doc.isExpiringSoon ? "\(doc.daysRemaining) \(AppLanguage.tr("zile", "days"))" : AppLanguage.tr("Valabil", "Valid"))

                            Text(statusBadgeText)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(doc.isExpired ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                                .foregroundStyle(doc.isExpired ? Color.red : Color.green)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 3)
                        Divider()
                    }
                }
                .padding(10)
                .background(Color(white: 0.98))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // MARK: - Istoric Mentenanță & Service
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppLanguage.tr("ISTORIC INTERVENȚII SERVICE", "SERVICE & MAINTENANCE HISTORY"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.blue)

                    Spacer()

                    Text("\(AppLanguage.tr("Total service", "Service total")): \(String(format: "%.0f lei", vehicle.totalServiceSpent))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary)
                }

                if vehicle.sortedServiceRecords.isEmpty {
                    Text(AppLanguage.tr("Nicio intervenție de service înregistrată.", "No service records logged yet."))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(vehicle.sortedServiceRecords.prefix(8)) { record in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.date.formatted(date: .numeric, time: .omitted))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.3))

                                    Text(record.formattedMileage)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.blue)
                                }
                                .frame(width: 75, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.title)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.primary)

                                    if let notes = record.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color(white: 0.4))
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if let priceStr = record.formattedPrice {
                                    Text(priceStr)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.vertical, 3)
                            Divider()
                        }
                    }
                    .padding(10)
                    .background(Color(white: 0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // MARK: - Sumar Carburant & Consum
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLanguage.tr("SUMAR CONSUM & CHELTUIELI TOTALE", "CONSUMPTION & TOTAL EXPENSES SUMMARY"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.blue)

                HStack(spacing: 12) {
                    summaryItem(title: AppLanguage.tr("Consum Mediu", "Avg. Consumption"), value: vehicle.formattedAverageConsumption ?? "—")
                    summaryItem(title: AppLanguage.tr("Total Carburant", "Total Fuel"), value: String(format: "%.0f lei", vehicle.totalFuelSpent))
                    summaryItem(title: AppLanguage.tr("Acte & Taxe", "Docs & Tolls"), value: String(format: "%.0f lei", vehicle.totalDocumentsSpent))
                    summaryItem(title: AppLanguage.tr("Investiție Totală", "Total Investment"), value: String(format: "%.0f lei", vehicle.totalOverallSpent))
                }
            }

            Spacer(minLength: 20)

            // MARK: - Footer de Certificare
            HStack {
                Text(AppLanguage.tr(
                    "Generat cu aplicația Torpedou • Document de evidență digitală a vehiculului",
                    "Generated with Glovebox (Torpedou) • Digital Vehicle Record"
                ))
                    .font(.system(size: 8))
                    .foregroundStyle(Color(white: 0.5))

                Spacer()

                Text(AppLanguage.tr("Pagină 1 / 1", "Page 1 / 1"))
                    .font(.system(size: 8))
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .padding(32)
        .frame(width: 595.2, height: 841.8, alignment: .top)
        .background(Color.white)
        .colorScheme(.light) // Asigură randarea în culori de document fizic alb
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.4))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
