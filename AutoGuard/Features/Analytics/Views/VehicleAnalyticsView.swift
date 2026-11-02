//
//  VehicleAnalyticsView.swift
//  AutoGuard
//
//  Ecran complet de analitice financiare și grafice interactive Swift Charts pentru vehicul.
//

import Charts
import SwiftUI

enum AnalyticsTimePeriod: String, CaseIterable, Identifiable {
    case last30Days
    case last6Months
    case lastYear
    case allTime

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .last30Days: return "analytics.period.30d"
        case .last6Months: return "analytics.period.6m"
        case .lastYear: return "analytics.period.1y"
        case .allTime: return "analytics.period.all"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .last6Months:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }
}

struct VehicleAnalyticsView: View {
    let vehicle: Vehicle

    @State private var selectedPeriod: AnalyticsTimePeriod = .allTime
    @State private var selectedPoint: ConsumptionPoint? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var currentStartDate: Date? {
        selectedPeriod.startDate
    }

    private var hasAnyData: Bool {
        vehicle.totalOverallSpent > 0 || !vehicle.consumptionChartData.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !hasAnyData {
                    emptyStateView
                } else {
                    // Selector Perioadă de Timp
                    Picker("analytics.period.label", selection: $selectedPeriod.animation(.easeInOut)) {
                        ForEach(AnalyticsTimePeriod.allCases) { period in
                            Text(period.titleKey).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    // 1. Grid Sumar Financiar (inclusiv Cost Real / km și Acte/Taxe)
                    summaryCardsGrid

                    // 2. Grafice (Paralele pe iPad, una sub alta pe iPhone)
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            consumptionChartSection
                                .frame(maxWidth: .infinity)

                            expenseBreakdownSection
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        expenseBreakdownSection
                        consumptionChartSection
                    }

                    // 3. Detaliere Costuri Acte, RCA, ITP & Roviniete (România / Străinătate)
                    documentsExpensesSection
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("analytics.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sumar Financiar
    private var summaryCardsGrid: some View {
        VStack(spacing: 10) {
            if horizontalSizeClass == .regular {
                HStack(spacing: 12) {
                    costStatTile
                    costPerKmStatTile
                    fuelStatTile
                    serviceStatTile
                    documentsStatTile
                }
            } else {
                HStack(spacing: 10) {
                    costStatTile
                    costPerKmStatTile
                }
                HStack(spacing: 10) {
                    fuelStatTile
                    serviceStatTile
                }
                documentsStatTile
            }
        }
    }

    private var costStatTile: some View {
        statTile(
            title: "analytics.total_cost",
            value: String(format: "%.0f lei", vehicle.overallSpent(since: currentStartDate)),
            subtitle: AppLanguage.tr("Carburant + Service + Acte", "Fuel + Service + Docs"),
            color: .primary,
            icon: "creditcard.fill"
        )
    }

    private var costPerKmStatTile: some View {
        let costKm = vehicle.costPerKm(since: currentStartDate)
        return statTile(
            title: "analytics.cost_per_km",
            value: costKm != nil ? String(format: "%.2f lei/km", costKm!) : "—",
            subtitle: AppLanguage.tr("Cost real per kilometru", "Real cost per kilometer"),
            color: .blue,
            icon: "gauge.with.needle.fill"
        )
    }

    private var fuelStatTile: some View {
        statTile(
            title: "fuel.title",
            value: String(format: "%.0f lei", vehicle.fuelSpent(since: currentStartDate)),
            subtitle: String(format: AppLanguage.tr("%.1f L alimentați", "%.1f L refueled"), vehicle.fuelLiters(since: currentStartDate)),
            color: .orange,
            icon: "fuelpump.fill"
        )
    }

    private var serviceStatTile: some View {
        let count = (vehicle.serviceRecords ?? []).filter { currentStartDate == nil || $0.date >= currentStartDate! }.count
        return statTile(
            title: "service.title",
            value: String(format: "%.0f lei", vehicle.serviceSpent(since: currentStartDate)),
            subtitle: AppLanguage.tr("\(count) intervenții service", "\(count) service records"),
            color: .indigo,
            icon: "wrench.and.screwdriver.fill"
        )
    }

    private var documentsStatTile: some View {
        let pricedDocs = vehicle.pricedDocuments(since: currentStartDate)
        return statTile(
            title: "analytics.documents_cost",
            value: String(format: "%.0f lei", vehicle.documentsSpent(since: currentStartDate)),
            subtitle: AppLanguage.tr("\(pricedDocs.count) acte & viniete (RO / Străinătate)", "\(pricedDocs.count) docs & vignettes (RO / Abroad)"),
            color: .teal,
            icon: "shield.lefthalf.filled"
        )
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
                    Text(String(format: AppLanguage.tr("Medie: %.1f L", "Avg: %.1f L"), avg))
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
                                Text("\(AppLanguage.tr("Medie", "Avg")): \(String(format: "%.1f", avg)) L")
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
                    Text(AppLanguage.tr(
                        "Necesită cel puțin 2 plinuri complete pentru a trasa graficul de consum.",
                        "Requires at least 2 full tank fill-ups to plot the consumption chart."
                    ))
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
        let slices = vehicle.expenseBreakdownData(since: currentStartDate)
        let total = vehicle.overallSpent(since: currentStartDate)

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
                        Text(AppLanguage.tr("lei total", "RON total"))
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
                Text(AppLanguage.tr(
                    "Nu există cheltuieli înregistrate în perioada selectată.",
                    "No expenses recorded in the selected time period."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Detaliere Cheltuieli Acte, RCA, ITP & Roviniete
    @ViewBuilder
    private var documentsExpensesSection: some View {
        let docs = vehicle.pricedDocuments(since: currentStartDate)
        if !docs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("analytics.documents_breakdown_title", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.0f lei", vehicle.documentsSpent(since: currentStartDate)))
                        .font(.subheadline.bold())
                        .foregroundStyle(.teal)
                }

                Divider()

                VStack(spacing: 10) {
                    ForEach(docs) { doc in
                        HStack(spacing: 12) {
                            Image(systemName: doc.type.iconName)
                                .font(.subheadline)
                                .foregroundStyle(.teal)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(doc.type.titleKey)
                                        .font(.subheadline.weight(.semibold))
                                    if !doc.provider.isEmpty {
                                        Text("• \(doc.provider)")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    if doc.isArchived {
                                        Text("doc.status.archived")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .foregroundStyle(.secondary)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text("\(AppLanguage.tr("Expiră", "Expires")): \(doc.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let formattedPrice = doc.formattedPrice {
                                Text(formattedPrice)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
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
