//
//  ServiceHubView.swift
//  AutoGuard
//
//  Hub centralizat pentru istoricul de service și mentenanța parcului auto.
//

import SwiftData
import SwiftUI

struct ServiceHubView: View {
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var selectedVehicleForAdd: Vehicle? = nil
    @State private var selectedVehicleForIntervals: Vehicle? = nil

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
                        VStack(spacing: 20) {
                            // Secțiune pentru fiecare mașină: Card de Schimb Ulei & Mentenanță
                            ForEach(vehicles) { vehicle in
                                VStack(alignment: .leading, spacing: 10) {
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

                                    MaintenanceCardView(
                                        vehicle: vehicle,
                                        onAddServiceTap: {
                                            selectedVehicleForAdd = vehicle
                                        },
                                        onConfigureIntervalsTap: {
                                            selectedVehicleForIntervals = vehicle
                                        }
                                    )

                                    if !vehicle.sortedServiceRecords.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("service.hub.recent_records")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.secondary)
                                                .padding(.leading, 4)

                                            ForEach(vehicle.sortedServiceRecords.prefix(2)) { record in
                                                ServiceRecordRowView(record: record)
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle("service.title")
            .sheet(item: $selectedVehicleForAdd) { vehicle in
                AddServiceRecordSheet(vehicle: vehicle)
            }
            .sheet(item: $selectedVehicleForIntervals) { vehicle in
                MaintenanceIntervalSheet(vehicle: vehicle)
            }
        }
    }
}

#Preview {
    ServiceHubView()
        .modelContainer(for: [Vehicle.self, VehicleDocument.self, MileageEntry.self, ServiceRecord.self], inMemory: true)
}
