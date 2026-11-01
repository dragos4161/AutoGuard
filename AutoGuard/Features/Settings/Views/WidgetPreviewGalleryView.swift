//
//  WidgetPreviewGalleryView.swift
//  AutoGuard
//
//  Galerie interactivă în aplicație pentru previzualizarea tuturor formatelor de Widget-uri
//  (Lock Screen & Home Screen) și instrucțiuni pas cu pas pentru utilizator.
//

import SwiftUI
import SwiftData
import WidgetKit

struct WidgetPreviewGalleryView: View {
    @Query private var vehicles: [Vehicle]
    @State private var selectedVehicleId: UUID?

    private var activeData: MaintenanceWidgetData {
        if let selectedId = selectedVehicleId,
           let vehicle = vehicles.first(where: { $0.id == selectedId }) {
            let status = vehicle.oilChangeStatus
            let activeDocs = (vehicle.documents ?? []).filter { !$0.isArchived }
            let earliestDoc = activeDocs.min(by: { $0.expirationDate < $1.expirationDate })
            var nextDocTitle: String? = nil
            var nextDocDaysLeft: Int? = nil
            var nextDocIsUrgent = false

            if let doc = earliestDoc {
                nextDocTitle = doc.type.title
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: Date()),
                    to: Calendar.current.startOfDay(for: doc.expirationDate)
                ).day ?? 0
                nextDocDaysLeft = days
                nextDocIsUrgent = days >= 0 && days <= 15
            }

            return MaintenanceWidgetData(
                vehicleId: vehicle.id.uuidString,
                vehicleName: vehicle.displayName,
                plateNumber: vehicle.plateNumber,
                odometer: vehicle.currentMileage ?? 0,
                kmProgress: status?.kmProgress ?? 0.5,
                timeProgress: status?.timeProgress ?? 0.3,
                kmUsed: status?.kmUsed ?? 5000,
                intervalKm: vehicle.oilChangeIntervalKm,
                remainingKm: status?.remainingKm ?? 5000,
                remainingDays: status?.remainingDays ?? 180,
                dueDateFormatted: status?.dueDate.formatted(.dateTime.month().year()) ?? "2027",
                limitingFactor: status?.limitingFactor == .mileage ? "mileage" : "time",
                isOverdue: status?.isOverdue ?? false,
                isDueSoon: status?.isDueSoon ?? false,
                nextDocTitle: nextDocTitle,
                nextDocDaysLeft: nextDocDaysLeft,
                nextDocIsUrgent: nextDocIsUrgent,
                lastConsumptionFormatted: vehicle.averageConsumption.map { String(format: "%.1f L/100km", $0) }
            )
        }
        return WidgetDataManager.shared.loadWidgetData() ?? MaintenanceWidgetData.sample
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Selector mașină dacă există mai multe
                if vehicles.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("widgets.preview.select_vehicle")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        Picker("widgets.preview.vehicle", selection: $selectedVehicleId) {
                            Text("widgets.preview.default_vehicle").tag(nil as UUID?)
                            ForEach(vehicles) { v in
                                Text("\(v.displayName) (\(v.plateNumber))").tag(v.id as UUID?)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                }

                // MARK: - 1. Home Screen: Medium (Formatul principal)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Home Screen: Dimensiune Medie", systemImage: "rectangle.split.2x1.fill")
                        .font(.headline)
                        .padding(.horizontal)

                    widgetContainer(width: 345, height: 160) {
                        MaintenanceWidgetEntryView(data: activeData)
                            .environment(\.widgetFamilyOverride, .systemMedium)
                    }
                    .padding(.horizontal)
                }

                // MARK: - 2. Home Screen: Small & Large
                VStack(alignment: .leading, spacing: 10) {
                    Label("Home Screen: Mică & Mare", systemImage: "square.fill")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(alignment: .top, spacing: 16) {
                        widgetContainer(width: 160, height: 160) {
                            MaintenanceWidgetEntryView(data: activeData)
                                .environment(\.widgetFamilyOverride, .systemSmall)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dimensiune Compactă")
                                .font(.subheadline.bold())
                            Text("Afișează factorul limită (kilometri sau timp), procentul de uzură și alerta urgentă de expirare.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                // MARK: - 3. Lock Screen Accessories (Ecran Blocat)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Lock Screen (Ecran Blocat)", systemImage: "lock.iphone")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        // Rectangular
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Format Dreptunghiular")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                ZStack {
                                    Color.black
                                    MaintenanceWidgetEntryView(data: activeData)
                                        .environment(\.widgetFamilyOverride, .accessoryRectangular)
                                        .foregroundStyle(.white)
                                        .padding(8)
                                }
                                .frame(width: 170, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Spacer()

                            // Circular
                            VStack(alignment: .center, spacing: 4) {
                                Text("Circular Gauge")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                ZStack {
                                    Color.black
                                    MaintenanceWidgetEntryView(data: activeData)
                                        .environment(\.widgetFamilyOverride, .accessoryCircular)
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Inline text
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Format Orizontal (deasupra orei)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            HStack {
                                MaintenanceWidgetEntryView(data: activeData)
                                    .environment(\.widgetFamilyOverride, .accessoryInline)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)
                }

                // MARK: - Ghid instalare widget pe telefon
                VStack(alignment: .leading, spacing: 12) {
                    Label("Cum adaugi widget-ul pe ecran", systemImage: "hand.tap.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        guideRow(step: "1", text: "Apasă lung pe un spațiu liber de pe ecranul principal sau ecranul blocat.")
                        guideRow(step: "2", text: "Apasă pe butonul '+' din colțul de sus.")
                        guideRow(step: "3", text: "Caută 'Torpedou' și alege formatul preferat (Mic, Mediu, Mare sau Lock Screen).")
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding(.vertical)
        }
        .navigationTitle("widgets.gallery.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func widgetContainer<Content: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color(uiColor: .systemBackground)
            content()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func guideRow(step: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 24, height: 24)
                Text(step)
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
