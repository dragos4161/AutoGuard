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

    private struct MonthPreset: Identifiable {
        let months: Int
        let titleKey: LocalizedStringKey

        var id: Int { months }
    }

    private let monthPresets: [MonthPreset] = [
        MonthPreset(months: 6, titleKey: "service.interval.6_months"),
        MonthPreset(months: 12, titleKey: "service.interval.12_months"),
        MonthPreset(months: 18, titleKey: "service.interval.18_months"),
        MonthPreset(months: 24, titleKey: "service.interval.24_months")
    ]

    private let kmPresets: [Int] = [8000, 10000, 12000, 15000, 20000, 30000]

    @State private var selectedKmPreset: Int
    @State private var customKmText: String

    @State private var selectedMonthsPreset: Int
    @State private var customMonthsText: String

    private let repository: VehicleRepositoryProtocol

    init(
        vehicle: Vehicle,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.repository = repository

        let kmPresets = [8000, 10000, 12000, 15000, 20000, 30000]
        let isPresetKm = kmPresets.contains(vehicle.oilChangeIntervalKm)
        _selectedKmPreset = State(initialValue: isPresetKm ? vehicle.oilChangeIntervalKm : -1)
        _customKmText = State(initialValue: "\(vehicle.oilChangeIntervalKm)")

        let monthPresets = [6, 12, 18, 24]
        let isPresetMonths = monthPresets.contains(vehicle.oilChangeIntervalMonths)
        _selectedMonthsPreset = State(initialValue: isPresetMonths ? vehicle.oilChangeIntervalMonths : -1)
        _customMonthsText = State(initialValue: "\(vehicle.oilChangeIntervalMonths)")
    }

    private var parsedCustomKm: Int? {
        let clean = customKmText.filter { $0.isNumber }
        return Int(clean)
    }

    private var parsedCustomMonths: Int? {
        let clean = customMonthsText.filter { $0.isNumber }
        return Int(clean)
    }

    private var effectiveKm: Int? {
        if selectedKmPreset == -1 {
            return parsedCustomKm
        }
        return selectedKmPreset
    }

    private var effectiveMonths: Int? {
        if selectedMonthsPreset == -1 {
            return parsedCustomMonths
        }
        return selectedMonthsPreset
    }

    private var isFormValid: Bool {
        guard let km = effectiveKm, km > 0 else { return false }
        guard let months = effectiveMonths, months > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Interval Kilometri
                    Picker("service.interval.km_label", selection: $selectedKmPreset) {
                        ForEach(kmPresets, id: \.self) { km in
                            Text("\(km.formatted()) km").tag(km)
                        }
                        Text("service.interval.custom").tag(-1)
                    }
                    .onChange(of: selectedKmPreset) { _, newPreset in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if newPreset == -1 && customKmText.isEmpty {
                                customKmText = "\(vehicle.oilChangeIntervalKm)"
                            }
                        }
                    }

                    if selectedKmPreset == -1 {
                        HStack {
                            Text("service.interval.custom_km_title")
                            Spacer()
                            TextField("service.interval.custom_km_placeholder", text: $customKmText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Interval Timp
                    Picker("service.interval.months_label", selection: $selectedMonthsPreset) {
                        ForEach(monthPresets) { preset in
                            Text(preset.titleKey).tag(preset.months)
                        }
                        Text("service.interval.custom").tag(-1)
                    }
                    .onChange(of: selectedMonthsPreset) { _, newPreset in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if newPreset == -1 && customMonthsText.isEmpty {
                                customMonthsText = "\(vehicle.oilChangeIntervalMonths)"
                            }
                        }
                    }

                    if selectedMonthsPreset == -1 {
                        HStack {
                            Text("service.interval.custom_months_title")
                            Spacer()
                            TextField("service.interval.custom_months_placeholder", text: $customMonthsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("service.interval.months_unit")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
                        saveIntervals()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveIntervals() {
        guard let km = effectiveKm, let months = effectiveMonths else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        repository.updateMaintenanceIntervals(
            oilIntervalKm: km,
            oilIntervalMonths: months,
            for: vehicle,
            in: modelContext
        )
        NotificationManager.shared.scheduleMaintenanceReminder(for: vehicle)
        dismiss()
    }
}
