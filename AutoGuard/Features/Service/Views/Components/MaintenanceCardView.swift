//
//  MaintenanceCardView.swift
//  AutoGuard
//
//  Card vizual pentru starea de mentenanță / schimb de ulei (Timp vs. KM).
//

import SwiftUI

struct MaintenanceCardView: View {
    let vehicle: Vehicle
    var onAddServiceTap: () -> Void
    var onConfigureIntervalsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Titlu + Icon + Buton Setări Interval
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.orange)
                    Text("service.card.maintenance_title")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    onConfigureIntervalsTap()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if let status = vehicle.oilChangeStatus {
                // Stare calculată
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusText(for: status))
                                .font(.title3.bold())
                                .foregroundStyle(status.statusColor)

                            Text(statusSubtitle(for: status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(statusBadge(for: status))
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(status.statusColor.opacity(0.15))
                            .foregroundStyle(status.statusColor)
                            .clipShape(Capsule())
                    }

                    // Bare de progres vizual
                    VStack(spacing: 6) {
                        progressRow(
                            label: String(localized: "service.card.km_progress"),
                            valueText: "\(vehicle.oilChangeIntervalKm - max(0, status.remainingKm)) / \(vehicle.oilChangeIntervalKm) km",
                            progress: status.kmProgress,
                            color: status.statusColor
                        )

                        progressRow(
                            label: String(localized: "service.card.time_progress"),
                            valueText: status.dueDate.formatted(.dateTime.month().year()),
                            progress: status.timeProgress,
                            color: status.statusColor
                        )
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                // Nu există încă înregistrări de ulei
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
                        HStack {
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
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func progressRow(label: String, valueText: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: max(6, proxy.size.width * CGFloat(min(1.0, progress))), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func statusText(for status: MaintenanceStatus) -> String {
        if status.isOverdue {
            return String(localized: "service.card.overdue")
        } else if status.isDueSoon {
            return String(localized: "service.card.due_soon")
        } else {
            return String(localized: "service.card.on_track")
        }
    }

    private func statusSubtitle(for status: MaintenanceStatus) -> String {
        if status.isOverdue {
            if status.remainingKm <= 0 {
                return "Depășit cu \(abs(status.remainingKm)) km"
            } else {
                return "Termen depășit la data de \(status.dueDate.formatted(.dateTime.day().month().year()))"
            }
        } else {
            return "Următorul schimb: peste \(status.remainingKm) km sau \(status.remainingDays) zile"
        }
    }

    private func statusBadge(for status: MaintenanceStatus) -> String {
        if status.isOverdue {
            return String(localized: "service.badge.overdue")
        } else if status.isDueSoon {
            return String(localized: "service.badge.attention")
        } else {
            return String(localized: "service.badge.good")
        }
    }
}
