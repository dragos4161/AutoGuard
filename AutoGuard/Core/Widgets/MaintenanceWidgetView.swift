//
//  MaintenanceWidgetView.swift
//  AutoGuard
//
//  Interfețe pentru WidgetKit (iOS 16+ Lock Screen Accessories & Home Screen Widgets).
//  Afișează progresul reviziei, alerte de documente expirabile și date cheie pe ecranul blocat sau principal.
//

import SwiftUI
import WidgetKit

// `\.widgetFamily` este read-only în afara extensiei WidgetKit, așa că galeria din aplicație
// folosește această cheie pentru a forța un anumit format la previzualizare.
extension EnvironmentValues {
    @Entry var widgetFamilyOverride: WidgetFamily? = nil
}

public struct MaintenanceWidgetEntryView: View {
    public let data: MaintenanceWidgetData?
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetFamilyOverride) private var familyOverride

    private var family: WidgetFamily { familyOverride ?? systemFamily }

    public init(data: MaintenanceWidgetData?) {
        self.data = data
    }

    public var body: some View {
        Group {
            if let data {
                switch family {
                // Lock Screen Accessories (iOS 16+)
                case .accessoryCircular:
                    lockScreenCircularView(data: data)
                case .accessoryRectangular:
                    lockScreenRectangularView(data: data)
                case .accessoryInline:
                    lockScreenInlineView(data: data)

                // Home Screen Widgets
                case .systemSmall:
                    homeScreenSmallView(data: data)
                case .systemLarge:
                    homeScreenLargeView(data: data)
                default:
                    homeScreenMediumView(data: data)
                }
            } else {
                emptyWidgetView
            }
        }
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }

    // MARK: - Lock Screen: Circular (.accessoryCircular)
    @ViewBuilder
    private func lockScreenCircularView(data: MaintenanceWidgetData) -> some View {
        let percent = Double(data.kmProgressPercent)
        Gauge(value: percent, in: 0...100) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(data.kmProgressPercent)%")
                .font(.system(size: 11, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(URL(string: "torpedou://vehicle/\(data.vehicleId)"))
    }

    // MARK: - Lock Screen: Rectangular (.accessoryRectangular)
    @ViewBuilder
    private func lockScreenRectangularView(data: MaintenanceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "car.fill")
                    .font(.caption2)
                Text(data.plateNumber)
                    .font(.caption.bold())
                Spacer()
                if data.isOverdue {
                    Text("⚠️")
                        .font(.caption2)
                }
            }

            if let docTitle = data.nextDocTitle, let days = data.nextDocDaysLeft, data.nextDocIsUrgent {
                Text("\(docTitle) expiră în \(days)z")
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Text("Revizie: \(data.remainingKm) km rămași")
                    .font(.caption2)
                    .lineLimit(1)
            }

            // Bară de progres mini
            ProgressView(value: min(1.0, max(0.0, data.kmProgress)))
                .tint(data.isOverdue ? .red : .primary)
        }
        .widgetURL(URL(string: "torpedou://vehicle/\(data.vehicleId)"))
    }

    // MARK: - Lock Screen: Inline (.accessoryInline)
    @ViewBuilder
    private func lockScreenInlineView(data: MaintenanceWidgetData) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "car.fill")
            if data.isOverdue {
                Text("\(data.plateNumber): ⚠️ Revizie depășită")
            } else if let doc = data.nextDocTitle, let days = data.nextDocDaysLeft, data.nextDocIsUrgent {
                Text("\(data.plateNumber): \(doc) în \(days)z")
            } else {
                Text("\(data.plateNumber): \(data.remainingKm) km până la service")
            }
        }
    }

    // MARK: - Home Screen: Medium (.systemMedium - Cel mai popular)
    @ViewBuilder
    private func homeScreenMediumView(data: MaintenanceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
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

            // Factor limită & alertă document
            HStack(spacing: 6) {
                if data.isOverdue {
                    Text("⚠️ REVIZIE DEPĂȘITĂ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.red)
                } else {
                    let isKm = data.limitingFactor == "mileage"
                    Text(isKm ? "⚡️ Factor limită: Kilometraj" : "⚡️ Factor limită: Timp")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let doc = data.nextDocTitle, let days = data.nextDocDaysLeft, data.nextDocIsUrgent {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 9))
                        Text("\(doc): \(days)z")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                } else if let consumption = data.lastConsumptionFormatted {
                    Text(consumption)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Bara 1: Kilometri
            miniProgressBar(
                title: "KM",
                progress: data.kmProgress,
                percent: data.kmProgressPercent,
                subtitle: "\(data.kmUsed.formatted()) / \(data.intervalKm.formatted()) km (\(data.remainingKm) km rămași)",
                color: data.isOverdue ? .red : (data.limitingFactor == "mileage" ? .orange : .blue)
            )

            // Bara 2: Timp
            miniProgressBar(
                title: "Timp",
                progress: data.timeProgress,
                percent: data.timeProgressPercent,
                subtitle: "\(data.dueDateFormatted) (\(max(0, data.remainingDays / 30)) luni rămase)",
                color: data.isOverdue ? .red : (data.limitingFactor == "time" ? .orange : .purple)
            )
        }
        .padding(12)
        .widgetURL(URL(string: "torpedou://vehicle/\(data.vehicleId)"))
    }

    // MARK: - Home Screen: Small (.systemSmall)
    @ViewBuilder
    private func homeScreenSmallView(data: MaintenanceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(data.plateNumber)
                    .font(.caption2.bold())
                Spacer()
                if data.isOverdue {
                    Text("⚠️")
                        .font(.caption2)
                }
            }

            Text(data.vehicleName)
                .font(.caption.bold())
                .lineLimit(1)

            Spacer()

            let isKm = data.limitingFactor == "mileage"
            let accentColor: Color = data.isOverdue ? .red : (isKm ? .orange : .purple)

            HStack {
                Text(isKm ? "⚡️ Kilometri" : "⚡️ Timp")
                    .font(.caption2.bold())
                    .foregroundStyle(accentColor)
                Spacer()
                Text("\(isKm ? data.kmProgressPercent : data.timeProgressPercent)%")
                    .font(.caption2.bold())
                    .foregroundStyle(accentColor)
            }

            // Bară de progres
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    Capsule()
                        .fill(accentColor)
                        .frame(
                            width: max(6, proxy.size.width * CGFloat(min(1.0, isKm ? data.kmProgress : data.timeProgress))),
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text(isKm ? "\(data.remainingKm) km rămași" : "\(max(0, data.remainingDays / 30)) luni rămase")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            if let doc = data.nextDocTitle, let days = data.nextDocDaysLeft, data.nextDocIsUrgent {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                    Text("\(doc) în \(days) zile")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.red)
            }
        }
        .padding(10)
        .widgetURL(URL(string: "torpedou://vehicle/\(data.vehicleId)"))
    }

    // MARK: - Home Screen: Large (.systemLarge)
    @ViewBuilder
    private func homeScreenLargeView(data: MaintenanceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header complet
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.vehicleName)
                        .font(.headline)
                    Text("\(data.odometer.formatted()) km bord")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(data.plateNumber)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            // Secțiune Revizie Ulei & Filtre
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Revizie & Schimb Ulei", systemImage: "drop.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    if data.isOverdue {
                        Text("DEPĂȘIT")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                miniProgressBar(
                    title: "Kilometraj",
                    progress: data.kmProgress,
                    percent: data.kmProgressPercent,
                    subtitle: "\(data.kmUsed.formatted()) / \(data.intervalKm.formatted()) km (\(data.remainingKm) km rămași)",
                    color: data.isOverdue ? .red : .orange
                )

                miniProgressBar(
                    title: "Timp calendaristic",
                    progress: data.timeProgress,
                    percent: data.timeProgressPercent,
                    subtitle: "\(data.dueDateFormatted) (\(max(0, data.remainingDays / 30)) luni rămase)",
                    color: data.isOverdue ? .red : .purple
                )
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Card Documente & Consum
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Următorul Document")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if let doc = data.nextDocTitle, let days = data.nextDocDaysLeft {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(data.nextDocIsUrgent ? Color.red : Color.green)
                                .frame(width: 8, height: 8)
                            Text("\(doc) (\(days)z)")
                                .font(.caption.bold())
                        }
                    } else {
                        Text("Toate la zi ✓")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Consum Mediu")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(data.lastConsumptionFormatted ?? "N/A")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // Buton Acțiune rapidă
            HStack {
                Spacer()
                Label("Deschide Garaj", systemImage: "arrow.right.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
        }
        .padding(14)
        .widgetURL(URL(string: "torpedou://vehicle/\(data.vehicleId)"))
    }

    // MARK: - Mini Bară de Progres Reutilizabilă
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
                        .frame(
                            width: max(5, proxy.size.width * CGFloat(min(1.0, max(0.0, progress)))),
                            height: 5
                        )
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
        VStack(spacing: 8) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Torpedou")
                .font(.caption.bold())
            Text("Deschide aplicația pentru a configura vehiculul.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
