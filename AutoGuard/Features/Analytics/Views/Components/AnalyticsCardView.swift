//
//  AnalyticsCardView.swift
//  AutoGuard
//
//  Card compact de prezentare pentru costurile totale și consum în ecranul mașinii.
//

import SwiftUI

struct AnalyticsCardView: View {
    let vehicle: Vehicle
    var onViewDetailsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header card
            HStack {
                Label("analytics.title", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onViewDetailsTap()
                } label: {
                    HStack(spacing: 4) {
                        Text("analytics.button.view")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            // Metric Cards
            HStack(spacing: 12) {
                // Card 1: Total Cheltuieli
                VStack(alignment: .leading, spacing: 4) {
                    Text("analytics.total_cost")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    let total = vehicle.totalOverallSpent
                    Text(String(format: "%.0f lei", total))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text("Carb: \(String(format: "%.0f", vehicle.totalFuelSpent))")
                        Text("•")
                        Text("Serv: \(String(format: "%.0f", vehicle.totalServiceSpent))")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Card 2: Cost per km sau Consum
                VStack(alignment: .leading, spacing: 4) {
                    if let costKm = vehicle.costPerKm {
                        Text("analytics.cost_per_km")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.2f lei/km", costKm))
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)

                        Text("carburant & service")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("analytics.cost_per_km")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Text("—")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        Text("adaugă kilometraj")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
