//
//  CostsAndFuelHubView.swift
//  AutoGuard
//
//  Hub centralizat în bara de navigare pentru Costuri, Analitice pe Perioade și Jurnalul de Alimentare & Consum.
//

import Charts
import SwiftData
import SwiftUI

struct CostsAndFuelHubView: View {
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var selectedVehicleId: UUID? = nil
    @State private var selectedPeriod: AnalyticsTimePeriod = .allTime
    @State private var isShowingAddFuelSheet: Bool = false
    @State private var isShowingFuelHistory: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var activeVehicle: Vehicle? {
        if let selectedVehicleId,
           let match = vehicles.first(where: { $0.id == selectedVehicleId }) {
            return match
        }
        return vehicles.first
    }

    private var currentStartDate: Date? {
        selectedPeriod.startDate
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vehicle = activeVehicle {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 1. Selector Vehicul (sau Header Vehicul Unic)
                            vehicleHeaderSection(for: vehicle)

                            // 2. Jurnal Alimentare & Consum (acces rapid la plinuri și istoric)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("fuel.section.title")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                FuelSummaryCardView(
                                    vehicle: vehicle,
                                    onAddFuelTap: {
                                        isShowingAddFuelSheet = true
                                    },
                                    onViewHistoryTap: {
                                        isShowingFuelHistory = true
                                    }
                                )
                            }

                            // 3. Analitice & Costuri pe Perioade de Timp
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("analytics.title")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)

                                    Spacer()
                                }

                                // Selector Perioadă (30 zile / 6 luni / 1 an / Tot)
                                Picker("analytics.period.label", selection: $selectedPeriod.animation(.easeInOut)) {
                                    ForEach(AnalyticsTimePeriod.allCases) { period in
                                        Text(period.titleKey).tag(period)
                                    }
                                }
                                .pickerStyle(.segmented)

                                // Grid Sumar Financiar (Cost Total, Cost Real / km, Carburant, Service, Acte & Viniete)
                                summaryCardsGrid(for: vehicle)

                                // Grafice Interactive (Cheltuieli pe Categorii & Evoluție Consum)
                                if horizontalSizeClass == .regular {
                                    HStack(alignment: .top, spacing: 20) {
                                        expenseBreakdownSection(for: vehicle)
                                            .frame(maxWidth: .infinity)

                                        consumptionChartSection(for: vehicle)
                                            .frame(maxWidth: .infinity)
                                    }
                                } else {
                                    expenseBreakdownSection(for: vehicle)
                                    consumptionChartSection(for: vehicle)
                                }

                                // Detaliere Cheltuieli Acte, RCA, ITP & Roviniete (RO / Străinătate)
                                documentsExpensesSection(for: vehicle)
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .navigationDestination(isPresented: $isShowingFuelHistory) {
                        FuelHistoryView(vehicle: vehicle)
                    }
                    .sheet(isPresented: $isShowingAddFuelSheet) {
                        AddFuelEntrySheet(vehicle: vehicle)
                    }
                    .sheet(isPresented: $isShowingExportSheet) {
                        VehicleExportSheet(vehicle: vehicle)
                    }
                } else {
                    ContentUnavailableView {
                        Label("analytics.no_data_title", systemImage: "chart.pie.fill")
                    } description: {
                        Text("service.empty.subtitle")
                    }
                }
            }
            .navigationTitle(AppLanguage.tr("Costuri & Consum", "Costs & Fuel"))
            .toolbar {
                if activeVehicle != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                isShowingExportSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Button {
                                isShowingAddFuelSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("fuel.add.button")
                                }
                                .font(.subheadline.bold())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header / Selector Mașină
    @ViewBuilder
    private func vehicleHeaderSection(for active: Vehicle) -> some View {
        if vehicles.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vehicles) { v in
                        let isSelected = v.id == active.id
                        Button {
                            withAnimation(.snappy) {
                                selectedVehicleId = v.id
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "car.fill")
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(v.displayName)
                                        .font(.caption.bold())
                                    Text(v.plateNumber)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .opacity(0.85)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        } else {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "car.fill")
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(active.displayName)
                        .font(.subheadline.bold())
                    Text(active.plateNumber)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let km = active.formattedMileage {
                    Text(km)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Grid Sumar Financiar
    @ViewBuilder
    private func summaryCardsGrid(for vehicle: Vehicle) -> some View {
        VStack(spacing: 10) {
            if horizontalSizeClass == .regular {
                HStack(spacing: 12) {
                    costStatTile(for: vehicle)
                    costPerKmStatTile(for: vehicle)
                    fuelStatTile(for: vehicle)
                    serviceStatTile(for: vehicle)
                    documentsStatTile(for: vehicle)
                }
            } else {
                HStack(spacing: 10) {
                    costStatTile(for: vehicle)
                    costPerKmStatTile(for: vehicle)
                }
                HStack(spacing: 10) {
                    fuelStatTile(for: vehicle)
                    serviceStatTile(for: vehicle)
                }
                documentsStatTile(for: vehicle)
            }
        }
    }

    private func costStatTile(for vehicle: Vehicle) -> some View {
        statTile(
            title: "analytics.total_cost",
            value: String(format: "%.0f lei", vehicle.overallSpent(since: currentStartDate)),
            subtitle: AppLanguage.tr("Carburant + Service + Acte", "Fuel + Service + Docs"),
            color: .primary,
            icon: "creditcard.fill"
        )
    }

    private func costPerKmStatTile(for vehicle: Vehicle) -> some View {
        let costKm = vehicle.costPerKm(since: currentStartDate)
        return statTile(
            title: "analytics.cost_per_km",
            value: costKm != nil ? String(format: "%.2f lei/km", costKm!) : "—",
            subtitle: AppLanguage.tr("Cost real per kilometru", "Real cost per kilometer"),
            color: .blue,
            icon: "gauge.with.needle.fill"
        )
    }

    private func fuelStatTile(for vehicle: Vehicle) -> some View {
        statTile(
            title: "fuel.title",
            value: String(format: "%.0f lei", vehicle.fuelSpent(since: currentStartDate)),
            subtitle: String(format: AppLanguage.tr("%.1f L alimentați", "%.1f L refueled"), vehicle.fuelLiters(since: currentStartDate)),
            color: .orange,
            icon: "fuelpump.fill"
        )
    }

    private func serviceStatTile(for vehicle: Vehicle) -> some View {
        let count = (vehicle.serviceRecords ?? []).filter { currentStartDate == nil || $0.date >= currentStartDate! }.count
        return statTile(
            title: "service.title",
            value: String(format: "%.0f lei", vehicle.serviceSpent(since: currentStartDate)),
            subtitle: AppLanguage.tr("\(count) intervenții service", "\(count) service records"),
            color: .indigo,
            icon: "wrench.and.screwdriver.fill"
        )
    }

    private func documentsStatTile(for vehicle: Vehicle) -> some View {
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

    // MARK: - Grafic Distribuție Cheltuieli pe Categorii
    @ViewBuilder
    private func expenseBreakdownSection(for vehicle: Vehicle) -> some View {
        let slices = vehicle.expenseBreakdownData(since: currentStartDate)
        let total = vehicle.overallSpent(since: currentStartDate)

        VStack(alignment: .leading, spacing: 14) {
            Label("analytics.expenses_by_category", systemImage: "chart.pie.fill")
                .font(.headline)

            if !slices.isEmpty && total > 0 {
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

    // MARK: - Grafic Evoluție Consum
    @ViewBuilder
    private func consumptionChartSection(for vehicle: Vehicle) -> some View {
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

    // MARK: - Detaliere Cheltuieli Acte, RCA, ITP & Roviniete
    @ViewBuilder
    private func documentsExpensesSection(for vehicle: Vehicle) -> some View {
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
}
