//
//  AddVehicleView.swift
//  AutoGuard
//
//  UI pur pentru adăugarea unui vehicul.
//  Nu conține logică de business; se leagă direct la `AddVehicleViewModel`.
//

import SwiftData
import SwiftUI

struct AddVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // ViewModel-ul gestionează starea și validările (State Management)
    @State private var viewModel = AddVehicleViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Date generale
                Section("add_vehicle.section.details") {
                    TextField(
                        "add_vehicle.plate_placeholder",
                        text: $viewModel.plateNumber
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                    TextField(
                        "add_vehicle.make_placeholder",
                        text: $viewModel.make
                    )
                    TextField(
                        "add_vehicle.model_placeholder",
                        text: $viewModel.model
                    )
                    TextField("add_vehicle.nickname_placeholder", text: $viewModel.nickname)
                }

                // Secțiunea 2: Termene de expirare
                Section("add_vehicle.section.expirations") {
                    DatePicker(
                        "add_vehicle.rca_expiry",
                        selection: $viewModel.rcaDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "add_vehicle.itp_expiry",
                        selection: $viewModel.itpDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "add_vehicle.rovinieta_expiry",
                        selection: $viewModel.rovinietaDate,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("add_vehicle.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        if viewModel.saveVehicle(in: modelContext) {
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
    AddVehicleView()
        .modelContainer(
            for: [Vehicle.self, VehicleDocument.self],
            inMemory: true
        )
}
