//
//  FuelSummaryCardView.swift
//  AutoGuard
//
//  Card de sumar pentru consumul de carburant afișat în ecranul de detalii al mașinii.
//

import SwiftUI

struct FuelSummaryCardView: View {
    let vehicle: Vehicle
    var onAddFuelTap: () -> Void
    var onViewHistoryTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header card
            HStack {
                Label("fuel.section.title", systemImage: "fuelpump.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onAddFuelTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("fuel.add.button")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            // Metric Cards
            HStack(spacing: 12) {
                // Card 1: Consum Mediu
                VStack(alignment: .leading, spacing: 4) {
                    Text("fuel.stats.avg_consumption")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    if let avg = vehicle.formattedAverageConsumption {
                        Text(avg)
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("fuel.stats.calculated_after_two")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Card 2: Total Carburant
                VStack(alignment: .leading, spacing: 4) {
                    Text("fuel.stats.total_spent")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    let totalSpent = vehicle.totalFuelSpent
                    Text(String(format: "%.0f lei", totalSpent))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(String(format: "%.1f L volum", vehicle.totalFuelLiters))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Ultimele înregistrări sau link istoric
            if !vehicle.sortedFuelEntries.isEmpty {
                let recentEntries = vehicle.sortedFuelEntries.prefix(2)
                Divider()

                VStack(spacing: 8) {
                    ForEach(recentEntries) { entry in
                        FuelEntryRowView(entry: entry, calculation: vehicle.calculation(for: entry))
                    }
                }

                Button {
                    onViewHistoryTap()
                } label: {
                    HStack {
                        Text("fuel.history.view_all")
                            .font(.caption.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.blue)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            } else {
                Text("fuel.empty.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
