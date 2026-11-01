//
//  MaintenanceIntervalSheet.swift
//  AutoGuard
//
//  Sheet pentru configurarea intervalului de schimb de ulei (km și luni).
//

import SwiftData
import SwiftUI

struct MaintenanceIntervalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vehicle: Vehicle

    @State private var selectedKm: Int
    @State private var selectedMonths: Int

    private let repository: VehicleRepositoryProtocol

    init(
        vehicle: Vehicle,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.repository = repository
        _selectedKm = State(initialValue: vehicle.oilChangeIntervalKm)
        _selectedMonths = State(initialValue: vehicle.oilChangeIntervalMonths)
    }

    private let kmOptions = [8000, 10000, 12000, 15000, 20000, 30000]
    private let monthOptions = [6, 12, 18, 24]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("service.interval.km_label", selection: $selectedKm) {
                        ForEach(kmOptions, id: \.self) { km in
                            Text("\(km) km").tag(km)
                        }
                    }

                    Picker("service.interval.months_label", selection: $selectedMonths) {
                        ForEach(monthOptions, id: \.self) { months in
                            Text(months == 12 ? "1 an (12 luni)" : "\(months) luni").tag(months)
                        }
                    }
                } header: {
                    Text("service.interval.section_header")
                } footer: {
                    Text("service.interval.section_footer")
                }
            }
            .navigationTitle("service.interval.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        repository.updateMaintenanceIntervals(
                            oilIntervalKm: selectedKm,
                            oilIntervalMonths: selectedMonths,
                            for: vehicle,
                            in: modelContext
                        )
                        NotificationManager.shared.scheduleMaintenanceReminder(for: vehicle)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
