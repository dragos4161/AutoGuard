//
//  MaintenanceCardView.swift
//  AutoGuard
//
//  Card vizual interactiv pentru starea de mentenanță / schimb de ulei (Timp vs. KM).
//  Afișează bare de completitudine paralele, semnalează factorul limită și oferă
//  acțiuni rapide pentru înregistrarea reviziei sau marcarea rapidă ca efectuat.
//

import SwiftData
import SwiftUI

struct MaintenanceCardView: View {
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle
    var onAddServiceTap: () -> Void
    var onConfigureIntervalsTap: () -> Void

    private let repository: VehicleRepositoryProtocol
    @State private var showingQuickOilChangeSheet: Bool = false

    init(
        vehicle: Vehicle,
        onAddServiceTap: @escaping () -> Void,
        onConfigureIntervalsTap: @escaping () -> Void,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.onAddServiceTap = onAddServiceTap
        self.onConfigureIntervalsTap = onConfigureIntervalsTap
        self.repository = repository
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Titlu + Icon + Buton Configurare Interval
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Circle())

                    Text("service.card.maintenance_title")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    onConfigureIntervalsTap()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if let status = vehicle.oilChangeStatus {
                // Secțiunea 1: Banner Indicator "Care se va atinge prima?"
                limitingFactorBanner(for: status)

                // Secțiunea 2: Bare de completitudine paralele
                VStack(spacing: 12) {
                    // Bara 1: Kilometraj
                    completenessBar(
                        icon: "road.lanes",
                        title: "service.card.progress.km_label",
                        percentage: status.kmProgressPercent,
                        progress: status.kmProgress,
                        valueText: "\(status.kmUsed.formatted()) / \(vehicle.oilChangeIntervalKm.formatted()) km",
                        remainingText: status.isOverdue && status.remainingKm <= 0
                            ? "-\(abs(status.remainingKm).formatted()) km"
                            : "\(status.remainingKm.formatted()) km",
                        isLeadingFactor: status.limitingFactor == .mileage,
                        accentColor: status.limitingFactor == .mileage ? status.statusColor : .blue
                    )

                    // Bara 2: Timp
                    completenessBar(
                        icon: "calendar",
                        title: "service.card.progress.time_label",
                        percentage: status.timeProgressPercent,
                        progress: status.timeProgress,
                        valueText: status.dueDate.formatted(.dateTime.month().year()),
                        remainingText: status.isOverdue && status.remainingDays <= 0
                            ? "-\(abs(status.remainingDays)) zile"
                            : "\(status.monthsRemaining) luni",
                        isLeadingFactor: status.limitingFactor == .time,
                        accentColor: status.limitingFactor == .time ? status.statusColor : .purple
                    )
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemFill).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Secțiunea 3: Butoane Acțiuni Rapide (când este depășit sau în curând)
                if status.isOverdue || status.isDueSoon {
                    actionButtonsSection(for: status)
                } else {
                    // Buton când revizia este în parametri optimi
                    Button {
                        onAddServiceTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("service.card.log_service_button")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(uiColor: .tertiarySystemFill).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // Secțiunea 4: Footer cu Status Badge
                HStack {
                    statusBadgeView(for: status)
                    Spacer()
                    Text(summarySubtitle(for: status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Stare goală: fără înregistrări încă
                emptyStateView
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingQuickOilChangeSheet) {
            QuickOilChangeSheet(vehicle: vehicle)
        }
    }

    // MARK: - Secțiune Acțiuni Rapide (Înregistrează sau Marchează ca Efectuat)
    @ViewBuilder
    private func actionButtonsSection(for status: MaintenanceStatus) -> some View {
        VStack(spacing: 8) {
            // Butonul Principal: Deschide formularul complet (factură, preț, bon)
            Button {
                onAddServiceTap()
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("service.card.log_service_button")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: status.isOverdue
                            ? [Color.red, Color.red.opacity(0.85)]
                            : [Color.orange, Color.orange.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Butonul Secundar: Introducere rapidă kilometraj bord & resetare
            Button {
                showingQuickOilChangeSheet = true
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                    Text("service.card.quick_complete_button")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemFill).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Banner Factor Limită ("Care se va atinge prima?")
    @ViewBuilder
    private func limitingFactorBanner(for status: MaintenanceStatus) -> some View {
        if status.isOverdue {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                    .font(.caption)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(overdueTitle(for: status))
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)

                    Text(overdueSubtitle(for: status))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)

                    Text("service.card.first_to_expire")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(factorTitle(for: status.limitingFactor))
                        .font(.caption2.bold())
                        .foregroundStyle(factorColor(for: status.limitingFactor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(factorColor(for: status.limitingFactor).opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()
                }

                Text(factorHint(for: status.limitingFactor))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemFill).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Bară de completitudine modernă
    @ViewBuilder
    private func completenessBar(
        icon: String,
        title: LocalizedStringKey,
        percentage: Int,
        progress: Double,
        valueText: String,
        remainingText: String,
        isLeadingFactor: Bool,
        accentColor: Color
    ) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)

                if isLeadingFactor {
                    Text("⚡️")
                        .font(.caption2)
                }

                Spacer()

                Text("\(percentage)%")
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
            }

            // Bara grafică de progres
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.8), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(8, proxy.size.width * CGFloat(min(1.0, max(0.0, progress)))),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            // Valori și rest
            HStack {
                Text(valueText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(remainingText)
                    .font(.caption2.bold())
                    .foregroundStyle(isLeadingFactor ? accentColor : .secondary)
            }
        }
    }

    // MARK: - Status Badge
    @ViewBuilder
    private func statusBadgeView(for status: MaintenanceStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.statusColor)
                .frame(width: 8, height: 8)

            Text(statusBadgeText(for: status))
                .font(.caption2.bold())
                .foregroundStyle(status.statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Stare goală
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("service.card.no_records_title")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text("service.card.no_records_subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onAddServiceTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("service.card.add_first_oil_change")
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Helperi Traduceri & Logică
    private func factorTitle(for factor: MaintenanceStatus.LimitingFactor) -> LocalizedStringKey {
        switch factor {
        case .mileage: return "service.card.factor.mileage"
        case .time: return "service.card.factor.time"
        case .balanced: return "service.card.factor.balanced"
        }
    }

    private func factorColor(for factor: MaintenanceStatus.LimitingFactor) -> Color {
        switch factor {
        case .mileage: return .blue
        case .time: return .purple
        case .balanced: return .green
        }
    }

    private func factorHint(for factor: MaintenanceStatus.LimitingFactor) -> LocalizedStringKey {
        switch factor {
        case .mileage: return "service.card.factor.mileage_hint"
        case .time: return "service.card.factor.time_hint"
        case .balanced: return "service.card.factor.balanced_hint"
        }
    }

    private func statusBadgeText(for status: MaintenanceStatus) -> LocalizedStringKey {
        if status.isOverdue {
            return "service.badge.overdue"
        } else if status.isDueSoon {
            return "service.badge.attention"
        } else {
            return "service.badge.good"
        }
    }

    private func summarySubtitle(for status: MaintenanceStatus) -> String {
        if status.isOverdue {
            return "Fă o programare în service"
        } else if status.limitingFactor == .mileage {
            return "Limita: în \(status.remainingKm.formatted()) km"
        } else {
            return "Limita: în \(status.monthsRemaining) luni"
        }
    }

    private func overdueTitle(for status: MaintenanceStatus) -> String {
        if status.remainingKm <= 0 && status.remainingDays <= 0 {
            return "Termen depășit la kilometri și la timp!"
        } else if status.remainingKm <= 0 {
            return "Kilometraj depășit cu \(abs(status.remainingKm).formatted()) km!"
        } else {
            return "Termen calendaristic depășit!"
        }
    }

    private func overdueSubtitle(for status: MaintenanceStatus) -> String {
        "Fă o programare în service pentru a proteja motorul mașinii."
    }
}
