//
//  QuickOilChangeSheet.swift
//  AutoGuard
//
//  Sheet compact pentru marcarea rapidă a schimbului de ulei.
//  Obligă utilizatorul să introducă kilometrajul curent din bord pentru o acuratețe maximă.
//

import SwiftData
import SwiftUI

struct QuickOilChangeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vehicle: Vehicle

    @State private var mileageInput: String = ""
    @FocusState private var isFieldFocused: Bool

    private let repository: VehicleRepositoryProtocol

    init(
        vehicle: Vehicle,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.repository = repository
        let initialKm = vehicle.currentMileage ?? (vehicle.lastOilChangeRecord?.mileage ?? 0)
        _mileageInput = State(initialValue: initialKm > 0 ? "\(initialKm)" : "")
    }

    private var parsedMileage: Int? {
        let clean = mileageInput.filter { $0.isNumber }
        return Int(clean)
    }

    private var lastRecordedMileage: Int? {
        vehicle.lastOilChangeRecord?.mileage
    }

    private var isMileageLowerThanLastService: Bool {
        guard let entered = parsedMileage, let last = lastRecordedMileage else { return false }
        return entered < last
    }

    private var isFormValid: Bool {
        guard let km = parsedMileage, km > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                // Header cu icon și descriere
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.orange)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("service.quick.title")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(vehicle.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Text("service.quick.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Câmpul de introducere a kilometrajului
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("service.quick.current_km_label")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let last = lastRecordedMileage {
                            Text(String(format: String(localized: "service.quick.last_oil_info"), last.formatted()))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        TextField("service.quick.mileage_placeholder", text: $mileageInput)
                            .keyboardType(.numberPad)
                            .font(.title2.bold())
                            .focused($isFieldFocused)

                        Text("km")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isMileageLowerThanLastService {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("service.quick.mileage_lower_warning")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Butonul de confirmare și resetare
                Button {
                    saveQuickOilChange()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                        Text("service.quick.confirm_button")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(14)
                    .background(isFormValid ? Color.orange : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isFormValid)
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFieldFocused = true
                }
            }
        }
        .presentationDetents([.height(340), .medium])
        .presentationDragIndicator(.visible)
    }

    private func saveQuickOilChange() {
        guard let km = parsedMileage else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 1. Dacă kilometrajul introdus este mai mare decât cel curent, actualizăm și jurnalul de kilometri
        if km > (vehicle.currentMileage ?? 0) {
            _ = repository.addMileageEntry(
                km,
                date: Date(),
                note: String(localized: "service.category.oil_and_filters"),
                for: vehicle,
                in: modelContext
            )
        }

        // 2. Înregistrăm schimbul de ulei
        _ = repository.addServiceRecord(
            title: String(localized: "service.category.oil_and_filters"),
            category: .oilAndFilters,
            date: Date(),
            mileage: km,
            notes: nil,
            price: nil,
            invoiceData: nil,
            invoiceFileName: nil,
            for: vehicle,
            in: modelContext
        )

        // 3. Actualizăm alertele de notificare și widget-ul
        NotificationManager.shared.scheduleMaintenanceReminder(for: vehicle)
        WidgetDataManager.shared.updateWidgetData(for: vehicle)

        dismiss()
    }
}
