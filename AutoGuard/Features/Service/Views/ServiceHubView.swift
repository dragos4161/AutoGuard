//
//  ServiceHubView.swift
//  AutoGuard
//
//  Hub centralizat pentru istoricul de service și mentenanța parcului auto.
//  Permite adăugarea facilă de revizii/intrări de service (inclusiv suport 1-tap pentru o singură mașină),
//  previzualizarea facturilor/devizelor prin QuickLook și acces la istoricul complet.
//

import QuickLook
import SwiftData
import SwiftUI

struct ServiceHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var selectedVehicleForAdd: Vehicle? = nil
    @State private var selectedVehicleForIntervals: Vehicle? = nil
    @State private var invoicePreviewURL: URL? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    ContentUnavailableView {
                        Label("service.empty.title", systemImage: "wrench.and.screwdriver")
                    } description: {
                        Text("service.empty.subtitle")
                    }
                } else {
                    ScrollView {
                        Group {
                            if horizontalSizeClass == .regular {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 440, maximum: 620), spacing: 20)],
                                    spacing: 20
                                ) {
                                    ForEach(vehicles) { vehicle in
                                        vehicleServiceSection(vehicle)
                                    }
                                }
                            } else {
                                VStack(spacing: 20) {
                                    ForEach(vehicles) { vehicle in
                                        vehicleServiceSection(vehicle)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle("service.title")
            .toolbar {
                if !vehicles.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        addServiceToolbarButton
                    }
                }
            }
            .sheet(item: $selectedVehicleForAdd) { vehicle in
                AddServiceRecordSheet(vehicle: vehicle)
            }
            .sheet(item: $selectedVehicleForIntervals) { vehicle in
                MaintenanceIntervalSheet(vehicle: vehicle)
            }
            .quickLookPreview($invoicePreviewURL)
        }
    }

    // MARK: - Buton Adăugare Service în Toolbar
    @ViewBuilder
    private var addServiceToolbarButton: some View {
        if vehicles.count == 1, let singleVehicle = vehicles.first {
            Button {
                selectedVehicleForAdd = singleVehicle
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("service.hub.add_record_button")
                }
                .font(.subheadline.bold())
            }
        } else if vehicles.count > 1 {
            Menu {
                ForEach(vehicles) { vehicle in
                    Button {
                        selectedVehicleForAdd = vehicle
                    } label: {
                        Label("\(vehicle.displayName) (\(vehicle.plateNumber))", systemImage: "car.fill")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("service.hub.add_record_button")
                }
                .font(.subheadline.bold())
            }
        }
    }

    // MARK: - Secțiune Service per Vehicul
    @ViewBuilder
    private func vehicleServiceSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Vehicul + Link Detalii
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(vehicle.plateNumber)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink(destination: VehicleDetailsView(vehicle: vehicle)) {
                    HStack(spacing: 4) {
                        Text("service.hub.view_car_details")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 4)

            // Card Mentenanță Ulei & Revizie
            MaintenanceCardView(
                vehicle: vehicle,
                onAddServiceTap: {
                    selectedVehicleForAdd = vehicle
                },
                onConfigureIntervalsTap: {
                    selectedVehicleForIntervals = vehicle
                }
            )

            // Înregistrări Recente de Service
            if !vehicle.sortedServiceRecords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("service.hub.recent_records")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            selectedVehicleForAdd = vehicle
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                Text("service.hub.add_entry_quick")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 4)

                    ForEach(vehicle.sortedServiceRecords.prefix(3)) { record in
                        ServiceRecordRowView(
                            record: record,
                            onViewInvoice: {
                                openInvoice(for: record)
                            },
                            onDelete: {
                                deleteServiceRecord(record)
                            }
                        )
                    }

                    if vehicle.sortedServiceRecords.count > 3 {
                        NavigationLink(destination: VehicleDetailsView(vehicle: vehicle)) {
                            HStack(spacing: 4) {
                                Text("service.hub.view_all_history")
                                Image(systemName: "arrow.right")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Helperi Factură & Ștergere
    private func openInvoice(for record: ServiceRecord) {
        guard let data = record.invoiceData else { return }
        let fileName = record.invoiceFileName ?? "Factura_\(record.title).pdf"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(record.id.uuidString)_\(fileName)")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try? data.write(to: tempURL, options: .atomic)
        }
        invoicePreviewURL = tempURL
    }

    private func deleteServiceRecord(_ record: ServiceRecord) {
        let repository = SwiftDataVehicleRepository()
        repository.deleteServiceRecord(record, in: modelContext)
    }
}

#Preview {
    ServiceHubView()
        .modelContainer(for: [Vehicle.self, VehicleDocument.self, MileageEntry.self, ServiceRecord.self], inMemory: true)
}
