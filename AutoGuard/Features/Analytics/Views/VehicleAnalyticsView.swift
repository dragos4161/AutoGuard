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
    case sinceRCA
    case thisYear
    case lastYear
    case allTime

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .last30Days: return AppLanguage.tr("30 Zile", "30 Days")
        case .sinceRCA: return AppLanguage.tr("De la RCA", "Since RCA")
        case .thisYear: return AppLanguage.tr("1 Ian", "Jan 1")
        case .lastYear: return AppLanguage.tr("12 Luni", "1 Year")
        case .allTime: return AppLanguage.tr("Tot", "All Time")
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .last30Days: return "analytics.period.30d"
        case .sinceRCA: return LocalizedStringKey(AppLanguage.tr("De la RCA", "Since RCA"))
        case .thisYear: return LocalizedStringKey(AppLanguage.tr("1 Ian", "Jan 1"))
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
        case .sinceRCA:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .thisYear:
            let year = calendar.component(.year, from: now)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }

    func startDate(for vehicle: Vehicle) -> Date? {
        if self == .sinceRCA {
            return vehicle.rcaCycleStartDate ?? startDate
        }
        return startDate
    }
}

struct VehicleAnalyticsView: View {
    let vehicle: Vehicle

    @State private var selectedPeriod: AnalyticsTimePeriod = .allTime
    @State private var selectedPoint: ConsumptionPoint? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var currentStartDate: Date? {
        selectedPeriod.startDate(for: vehicle)
    }

    private var hasAnyData: Bool {
        vehicle.totalOverallSpent > 0 || !vehicle.consumptionChartData.isEmpty || vehicle.odometerChartData().count >= 2
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
                            Text(period.displayLabel).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedPeriod == .sinceRCA {
                        RCACycleSummaryBannerView(vehicle: vehicle)
                    }

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

                    // 3. Evoluție Kilometraj & Statistici Rulaj (km/săpt, km/lună, ultimul an)
                    VehicleMileageEvolutionCardView(vehicle: vehicle, startDate: currentStartDate)

                    // 4. Detaliere Costuri Acte, RCA, ITP & Roviniete (România / Străinătate)
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
                    Text(String(format: AppLanguage.tr("Medie: %.1f L/100km", "Avg: %.1f L/100km"), avg))
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            let chartData = vehicle.consumptionChartData
            if !chartData.isEmpty {
                let displayPoints: [ConsumptionPoint] = {
                    if chartData.count == 1,
                       let firstPoint = chartData.first,
                       let firstFullEntry = vehicle.chronologicalFuelEntries.first(where: { $0.isFullTank }),
                       firstFullEntry.date < firstPoint.date {
                        return [
                            ConsumptionPoint(
                                date: firstFullEntry.date,
                                consumption: firstPoint.consumption,
                                odometer: firstFullEntry.odometer
                            ),
                            firstPoint
                        ]
                    }
                    return chartData
                }()
                let maxConsumption = max(displayPoints.map(\.consumption).max() ?? 10.0, vehicle.averageConsumption ?? 10.0)

                Chart {
                    // Suprafață cu gradient
                    ForEach(displayPoints) { point in
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
                    ForEach(displayPoints) { point in
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
                        .symbolSize(42)
                    }

                    // Linie de referință medie
                    if chartData.count >= 2, let avg = vehicle.averageConsumption {
                        RuleMark(y: .value("Medie", avg))
                            .foregroundStyle(Color.secondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                .chartYScale(domain: 0...(maxConsumption * 1.25))
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

// MARK: - Banner Rezumat Cost Anual în Ciclul RCA
struct RCACycleSummaryBannerView: View {
    let vehicle: Vehicle

    var body: some View {
        let rcaStart = vehicle.rcaCycleStartDate
        let rcaDoc = vehicle.activeRCADocument
        let totalInCycle = vehicle.overallSpent(since: rcaStart)
        let daysElapsed = max(1.0, Date().timeIntervalSince(rcaStart ?? Date()) / 86_400.0)
        let monthsElapsed = max(1.0, daysElapsed / 30.4375)
        let monthlyAvg = totalInCycle / monthsElapsed

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "shield.checkered")
                    .font(.headline)
                    .foregroundStyle(.teal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLanguage.tr("Ciclu Anual RCA + ITP + Rovinietă", "Annual RCA + ITP + Vignette Cycle"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                if let rcaStart, let rcaDoc {
                    Text(AppLanguage.tr(
                        "De la \(rcaStart.formatted(date: .abbreviated, time: .omitted)) • Expiră \(rcaDoc.expirationDate.formatted(date: .abbreviated, time: .omitted))",
                        "From \(rcaStart.formatted(date: .abbreviated, time: .omitted)) • Expires \(rcaDoc.expirationDate.formatted(date: .abbreviated, time: .omitted))"
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    Text(AppLanguage.tr(
                        "Adaugă polița RCA pentru a ancora automat începutul anului auto.",
                        "Add your RCA policy to automatically anchor the start of your car year."
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f lei", totalInCycle))
                    .font(.subheadline.bold())
                    .foregroundStyle(.teal)
                Text(String(format: AppLanguage.tr("~%.0f lei/lună", "~%.0f lei/mo"), monthlyAvg))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.teal.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Card Evoluție Kilometraj & Statistici Rulaj (km/săpt, km/lună, ultimul an)
struct VehicleMileageEvolutionCardView: View {
    let vehicle: Vehicle
    let startDate: Date?

    enum MileageScope: String, CaseIterable, Identifiable {
        case sinceRCA
        case thisYear
        case lastYear
        case allTime

        var id: String { rawValue }

        var label: String {
            switch self {
            case .sinceRCA: return AppLanguage.tr("De la RCA", "Since RCA")
            case .thisYear: return AppLanguage.tr("1 Ian", "Jan 1")
            case .lastYear: return AppLanguage.tr("12 Luni", "1 Year")
            case .allTime: return AppLanguage.tr("Tot", "All Time")
            }
        }
    }

    @State private var selectedScope: MileageScope = .sinceRCA
    @State private var hasInitializedScope: Bool = false

    private var effectiveStartDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch selectedScope {
        case .sinceRCA:
            return vehicle.rcaCycleStartDate ?? calendar.date(byAdding: .year, value: -1, to: now)
        case .thisYear:
            let year = calendar.component(.year, from: now)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }

    var body: some View {
        let points = vehicle.odometerChartData(since: effectiveStartDate)
        let stats = vehicle.mileageStats(since: effectiveStartDate)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    AppLanguage.tr("Evoluție Kilometraj", "Mileage Evolution"),
                    systemImage: "gauge.with.dots.needle.67percent"
                )
                .font(.headline)

                Spacer()

                if let stats {
                    Text("+\(stats.totalTrackedKm.formatted()) km")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Selector dedicat pentru perioada kilometrilor (De la RCA / 1 Ian / 12 Luni / Tot)
            Picker(AppLanguage.tr("Perioadă km", "Mileage period"), selection: $selectedScope.animation(.easeInOut)) {
                ForEach(MileageScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if let stats, points.count >= 2 {
                // 3 Statistici cheie: Km / Săpt., Km / Lună, Ultimul An
                HStack(spacing: 10) {
                    mileageMetricPill(
                        title: AppLanguage.tr("Medie / Săpt.", "Weekly Avg"),
                        value: "\(stats.weeklyAverageKm.formatted()) km",
                        subtitle: AppLanguage.tr("pe săptămână", "per week"),
                        color: .blue
                    )

                    mileageMetricPill(
                        title: AppLanguage.tr("Medie / Lună", "Monthly Avg"),
                        value: "\(stats.monthlyAverageKm.formatted()) km",
                        subtitle: AppLanguage.tr("pe lună", "per month"),
                        color: .indigo
                    )

                    mileageMetricPill(
                        title: AppLanguage.tr("Ultimul An", "Last Year"),
                        value: "\(stats.lastYearKm.formatted()) km",
                        subtitle: AppLanguage.tr("~\(stats.projectedYearlyKm.formatted()) km/an", "~\(stats.projectedYearlyKm.formatted()) km/yr"),
                        color: .teal
                    )
                }

                let minKm = points.map(\.mileage).min() ?? 0
                let maxKm = points.map(\.mileage).max() ?? 1000
                let span = max(100, maxKm - minKm)
                let lowerY = max(0, minKm - Int(Double(span) * 0.25))
                let upperY = maxKm + Int(Double(span) * 0.22)

                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Data", point.date),
                            yStart: .value("Min", lowerY),
                            yEnd: .value("Km", point.mileage)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.32), Color.blue.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("Km", point.mileage)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("Km", point.mileage)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(42)
                    }
                }
                .chartYScale(domain: lowerY...upperY)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        if let km = value.as(Int.self) {
                            AxisValueLabel {
                                Text("\(km.formatted())")
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 185)
                .padding(.vertical, 4)

                Text(AppLanguage.tr(
                    "Include automat citirile din Istoric Kilometraj, Alimentări și Intrări de Service (\(stats.daysTracked) zile monitorizate).",
                    "Automatically combines readings from Mileage History, Fuel Fill-ups, and Service Records (\(stats.daysTracked) days tracked)."
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "road.lanes")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(AppLanguage.tr(
                        "Adaugă cel puțin 2 înregistrări de kilometraj (sau alimentări pe zile diferite) pentru a vedea graficul de evoluție și mediile pe săptămână/lună.",
                        "Add at least 2 mileage readings (or fuel entries on different days) to see the evolution chart and weekly/monthly averages."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            guard !hasInitializedScope else { return }
            hasInitializedScope = true
            syncScope(with: startDate)
        }
        .onChange(of: startDate) { _, newStart in
            syncScope(with: newStart)
        }
    }

    private func syncScope(with date: Date?) {
        guard let date else {
            selectedScope = .allTime
            return
        }
        let calendar = Calendar.current
        if let rcaStart = vehicle.rcaCycleStartDate,
           calendar.isDate(date, inSameDayAs: rcaStart) {
            selectedScope = .sinceRCA
        } else {
            let year = calendar.component(.year, from: Date())
            if let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
               calendar.isDate(date, inSameDayAs: jan1) {
                selectedScope = .thisYear
            } else {
                selectedScope = .lastYear
            }
        }
    }

    private func mileageMetricPill(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
