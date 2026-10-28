//
//  EditVehicleView.swift
//  AutoGuard
//
//  Fereastra modală (Sheet) pentru editarea datelor unui vehicul existent.
//

import SwiftData
import SwiftUI

struct EditVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: EditVehicleViewModel
    @FocusState private var isVinFocused: Bool

    init(vehicle: Vehicle) {
        _viewModel = State(initialValue: EditVehicleViewModel(vehicle: vehicle))
    }

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Date Principale
                Section("edit_vehicle.section.main") {
                    TextField("add_vehicle.plate_placeholder", text: $viewModel.plateNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("add_vehicle.make_placeholder", text: $viewModel.make)
                    TextField("add_vehicle.model_placeholder", text: $viewModel.model)
                    TextField("add_vehicle.nickname_placeholder", text: $viewModel.nickname)
                }

                // Secțiunea 2: Detalii Tehnice
                Section("edit_vehicle.section.technical") {
                    Picker("edit_vehicle.year", selection: $viewModel.year) {
                        ForEach((1980...currentYear + 1).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }

                    TextField("add_vehicle.vin_placeholder", text: $viewModel.vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isVinFocused)
                        .onChange(of: viewModel.vin) { _, newValue in
                            if newValue.count >= 17 {
                                if newValue.count > 17 {
                                    viewModel.vin = String(newValue.prefix(17))
                                }
                                isVinFocused = false
                            }
                        }

                    if !viewModel.vin.isEmpty && !viewModel.isVinValid {
                        Text("edit_vehicle.vin_invalid_hint")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Secțiunea 3: Corectare Termene de Expirare Curente
                if !viewModel.vehicle.activeDocuments.isEmpty {
                    Section {
                        ForEach(viewModel.vehicle.activeDocuments) { doc in
                            DatePicker(
                                doc.type.titleKey,
                                selection: Binding(
                                    get: { viewModel.documentDates[doc.id] ?? doc.expirationDate },
                                    set: { viewModel.documentDates[doc.id] = $0 }
                                ),
                                displayedComponents: .date
                            )
                        }
                    } header: {
                        Text("edit_vehicle.section.expirations")
                    } footer: {
                        Text("edit_vehicle.section.expirations_footer")
                    }
                }
            }
            .navigationTitle("edit_vehicle.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        if viewModel.saveChanges(in: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isFormValid)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

#Preview {
    let sampleVehicle = Vehicle(
        plateNumber: "B 123 ABC",
        make: "Dacia",
        model: "Duster",
        year: 2023,
        vin: "VF1HJD20668912345",
        nickname: "Mașina familiei"
    )
    EditVehicleView(vehicle: sampleVehicle)
}
