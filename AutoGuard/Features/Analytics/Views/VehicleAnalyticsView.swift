//
//  VehicleAnalyticsView.swift
//  AutoGuard
//
//  Ecran complet de analitice financiare și grafice interactive Swift Charts pentru vehicul.
//

import Charts
import SwiftUI

struct VehicleAnalyticsView: View {
    let vehicle: Vehicle

    @State private var selectedPoint: ConsumptionPoint? = nil

    private var hasAnyData: Bool {
        vehicle.totalOverallSpent > 0 || !vehicle.consumptionChartData.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !hasAnyData {
                    emptyStateView
                } else {
                    // 1. Grid Sumar Financiar
                    summaryCardsGrid

                    // 2. Grafic Evoluție Consum
                    consumptionChartSection

                    // 3. Grafic Distribuție Cheltuieli pe Categorii
                    expenseBreakdownSection
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("analytics.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sumar Financiar (4 Carduri)
    private var summaryCardsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(
                    title: "analytics.total_cost",
                    value: String(format: "%.0f lei", vehicle.totalOverallSpent),
                    subtitle: "Carburant + Service",
                    color: .primary,
                    icon: "creditcard.fill"
                )

                statTile(
                    title: "analytics.cost_per_km",
                    value: vehicle.costPerKm != nil ? String(format: "%.2f lei", vehicle.costPerKm!) : "—",
                    subtitle: "Cost per kilometru",
                    color: .blue,
                    icon: "gauge.with.needle.fill"
                )
            }

            HStack(spacing: 10) {
                statTile(
                    title: "fuel.title",
                    value: String(format: "%.0f lei", vehicle.totalFuelSpent),
                    subtitle: String(format: "%.1f L alimentați", vehicle.totalFuelLiters),
                    color: .orange,
                    icon: "fuelpump.fill"
                )

                statTile(
                    title: "service.title",
                    value: String(format: "%.0f lei", vehicle.totalServiceSpent),
                    subtitle: "\(vehicle.sortedServiceRecords.count) revizii",
                    color: .indigo,
                    icon: "wrench.and.screwdriver.fill"
                )
            }
        }
    }

    private func statTile(title: LocalizedStringKey, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Grafic Evoluție Consum
    @ViewBuilder
    private var consumptionChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("analytics.consumption_trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                if let avg = vehicle.averageConsumption {
                    Text(String(format: "Medie: %.1f L", avg))
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            let chartData = vehicle.consumptionChartData
            if chartData.count >= 2 {
                Chart {
                    // Suprafață cu gradient
                    ForEach(chartData) { point in
                        AreaMark(
                            x: .value("Data", point.date),
                            y: .value("Consum", point.consumption)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.35), Color.green.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // Linie grafic
                    ForEach(chartData) { point in
                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("Consum", point.consumption)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("Consum", point.consumption)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(36)
                    }

                    // Linie de referință medie
                    if let avg = vehicle.averageConsumption {
                        RuleMark(y: .value("Medie", avg))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Medie: \(String(format: "%.1f", avg)) L")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 190)
                .padding(.vertical, 6)

                Text("analytics.consumption_chart_footer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "fuelpump.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Necesită cel puțin 2 plinuri complete pentru a trasa graficul de consum.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Grafic Distribuție Cheltuieli pe Categorii
    @ViewBuilder
    private var expenseBreakdownSection: some View {
        let slices = vehicle.expenseBreakdownData
        let total = vehicle.totalOverallSpent

        VStack(alignment: .leading, spacing: 14) {
            Label("analytics.expenses_by_category", systemImage: "chart.pie.fill")
                .font(.headline)

            if !slices.isEmpty && total > 0 {
                // Donut Chart
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Sumă", slice.amount),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.color)
                }
                .frame(height: 180)
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", total))
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("lei total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Divider()

                // Listă categorii cu procente
                VStack(spacing: 10) {
                    ForEach(slices) { slice in
                        let percentage = total > 0 ? (slice.amount / total) * 100.0 : 0.0

                        HStack(spacing: 10) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)

                            Image(systemName: slice.iconName)
                                .font(.caption)
                                .foregroundStyle(slice.color)
                                .frame(width: 16)

                            Text(slice.categoryName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(slice.formattedAmount)
                                    .font(.subheadline.bold())
                                Text(String(format: "%.1f%%", percentage))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                Text("Adaugă intrări de carburant sau revizii pentru a vedea distribuția costurilor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Stare goală
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("analytics.no_data_title", systemImage: "chart.bar.xaxis")
        } description: {
            Text("analytics.no_data_subtitle")
        }
        .padding(.top, 40)
    }
}
