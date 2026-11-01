//
//  MaintenanceWidgetView.swift
//  AutoGuard
//
//  Componenta de vizualizare pentru WidgetKit (iOS Home Screen Widget).
//  Afișează barele de completitudine și semnalizează factorul limită pe ecranul principal.
//

import SwiftUI
import WidgetKit

struct MaintenanceWidgetEntryView: View {
    let data: MaintenanceWidgetData?
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let data {
            switch family {
            case .systemSmall:
                smallWidgetView(data: data)
            default:
                mediumWidgetView(data: data)
            }
        } else {
            emptyWidgetView
        }
    }

    // MARK: - Medium Widget (Dimensiune recomandată pentru cele 2 bare)
    @ViewBuilder
    private func mediumWidgetView(data: MaintenanceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Mașină + Număr Înmatriculare
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(data.vehicleName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }

                Spacer()

                Text(data.plateNumber)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Factor limită
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 9))

                Text(data.isOverdue
                     ? "⚠️ REVIZIE DEPĂȘITĂ"
                     : (data.limitingFactor == "mileage" ? "⚡️ Factor limită: Kilometrajul" : "⚡️ Factor limită: Timpul"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(data.isOverdue ? .red : .primary)

                Spacer()

                Text(data.limitingFactor == "mileage"
                     ? "\(data.remainingKm) km rămași"
                     : "\(max(0, data.remainingDays / 30)) luni rămase")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            // Bara 1: Kilometri
            miniProgressBar(
                title: "KM",
                progress: data.kmProgress,
                percent: data.kmProgressPercent,
                subtitle: "\(data.kmUsed.formatted()) / \(data.intervalKm.formatted()) km",
                color: data.isOverdue ? .red : (data.limitingFactor == "mileage" ? .orange : .blue)
            )

            // Bara 2: Timp
            miniProgressBar(
                title: "Timp",
                progress: data.timeProgress,
                percent: data.timeProgressPercent,
                subtitle: data.dueDateFormatted,
                color: data.isOverdue ? .red : (data.limitingFactor == "time" ? .orange : .purple)
            )
        }
        .padding(12)
    }

    // MARK: - Small Widget (Dimensiune compactă)
    @ViewBuilder
    private func smallWidgetView(data: MaintenanceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.orange)
                Text(data.plateNumber)
                    .font(.caption2.bold())
                Spacer()
            }

            Text(data.vehicleName)
                .font(.caption.bold())
                .lineLimit(1)

            Spacer()

            let isKm = data.limitingFactor == "mileage"
            let accentColor: Color = data.isOverdue ? .red : (isKm ? .orange : .purple)

            Text(isKm ? "⚡️ Kilometri" : "⚡️ Timp")
                .font(.caption2.bold())
                .foregroundStyle(accentColor)

            // Bară de progres
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(6, proxy.size.width * CGFloat(min(1.0, isKm ? data.kmProgress : data.timeProgress))), height: 6)
                }
            }
            .frame(height: 6)

            Text(isKm ? "\(data.remainingKm) km rămași" : "\(max(0, data.remainingDays / 30)) luni rămase")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(10)
    }

    // MARK: - Mini Bară de Progres
    @ViewBuilder
    private func miniProgressBar(
        title: String,
        progress: Double,
        percent: Int,
        subtitle: String,
        color: Color
    ) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: max(5, proxy.size.width * CGFloat(min(1.0, max(0.0, progress)))), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Empty Widget View
    @ViewBuilder
    private var emptyWidgetView: some View {
        VStack(spacing: 6) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Torpedou")
                .font(.caption.bold())
            Text("Deschide aplicația pentru a configura revizia.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
