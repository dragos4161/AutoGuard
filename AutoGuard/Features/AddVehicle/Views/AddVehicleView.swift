//
//  AddVehicleView.swift
//  AutoGuard
//
//  UI pur pentru adăugarea unui vehicul.
//  Nu conține logică de business; se leagă direct la `AddVehicleViewModel`.
//

import SwiftUI
import SwiftData

struct AddVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // ViewModel-ul gestionează starea și validările (State Management)
    @State private var viewModel = AddVehicleViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Date generale
                Section("Date Vehicul") {
                    TextField("Număr înmatriculare (ex: B 123 ABC)", text: $viewModel.plateNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("Marcă (ex: Dacia, Volkswagen)", text: $viewModel.make)
                    TextField("Model (ex: Duster, Golf)", text: $viewModel.model)
                    TextField("Poreclă opțională", text: $viewModel.nickname)
                }

                // Secțiunea 2: Termene de expirare
                Section("Termene Inițiale de Expirare") {
                    DatePicker("Expirare RCA", selection: $viewModel.rcaDate, displayedComponents: .date)
                    DatePicker("Expirare ITP", selection: $viewModel.itpDate, displayedComponents: .date)
                    DatePicker("Expirare Rovinietă", selection: $viewModel.rovinietaDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Adaugă Mașină")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anulează") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvează") {
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
        .modelContainer(for: [Vehicle.self, VehicleDocument.self], inMemory: true)
}
