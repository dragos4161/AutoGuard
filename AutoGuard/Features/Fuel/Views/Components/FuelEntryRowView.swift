//
//  FuelEntryRowView.swift
//  AutoGuard
//
//  Rând pentru afișarea unei înregistrări individuale de alimentare în listă.
//

import SwiftUI

struct FuelEntryRowView: View {
    let entry: FuelEntry
    let calculation: (consumption: Double?, distance: Int?)

    var body: some View {
        HStack(spacing: 12) {
            // Iconiță tip carburant
            ZStack {
                Circle()
                    .fill(entry.fuelType.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: entry.fuelType.iconName)
                    .font(.headline)
                    .foregroundStyle(entry.fuelType.color)
            }

            // Detalii alimentare
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if let notes = entry.notes, !notes.isEmpty {
                        Text("• \(notes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Text(entry.formattedQuantity)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(entry.formattedPricePerLiter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let distance = calculation.distance {
                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.system(size: 9))
                        Text("+\(distance) km")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            // Preț total & consum calculat
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.formattedTotalPrice)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                if let consumption = calculation.consumption {
                    Text(String(format: "%.1f L/100km", consumption))
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else if entry.isFullTank {
                    Text(AppLanguage.tr("Plin", "Full"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
