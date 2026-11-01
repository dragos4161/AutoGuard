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
    @FocusState private var isVinFocused: Bool

    // OCR Scanner
    @State private var activeScanTarget: ScanTarget? = nil
    @State private var activeDateScanField: DateScanField? = nil

    private enum DateScanField {
        case rca, itp, rovinieta
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Date generale
                Section("add_vehicle.section.details") {
                    HStack {
                        TextField(
                            "add_vehicle.vin_placeholder",
                            text: $viewModel.vin
                        )
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

                        Button {
                            activeScanTarget = .vin
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        TextField(
                            "add_vehicle.plate_placeholder",
                            text: $viewModel.plateNumber
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                        Button {
                            activeScanTarget = .plateNumber
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField(
                        "add_vehicle.make_placeholder",
                        text: $viewModel.make
                    )
                    TextField(
                        "add_vehicle.model_placeholder",
                        text: $viewModel.model
                    )
                    TextField("add_vehicle.nickname_placeholder", text: $viewModel.nickname)

                    TextField("add_vehicle.mileage_placeholder", text: $viewModel.initialMileageText)
                        .keyboardType(.numberPad)
                }

                // Secțiunea 2: Termene de expirare
                Section("add_vehicle.section.expirations") {
                    HStack {
                        DatePicker(
                            "add_vehicle.rca_expiry",
                            selection: $viewModel.rcaDate,
                            displayedComponents: .date
                        )

                        Button {
                            activeDateScanField = .rca
                            activeScanTarget = .expirationDate
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        DatePicker(
                            "add_vehicle.itp_expiry",
                            selection: $viewModel.itpDate,
                            displayedComponents: .date
                        )

                        Button {
                            activeDateScanField = .itp
                            activeScanTarget = .expirationDate
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        DatePicker(
                            "add_vehicle.rovinieta_expiry",
                            selection: $viewModel.rovinietaDate,
                            displayedComponents: .date
                        )

                        Button {
                            activeDateScanField = .rovinieta
                            activeScanTarget = .expirationDate
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
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
            .sheet(item: $activeScanTarget) { target in
                LiveDocumentScannerView(
                    target: target,
                    onVinDetected: { vin in
                        viewModel.vin = vin
                    },
                    onPlateDetected: { plate in
                        viewModel.plateNumber = plate
                    },
                    onDateDetected: { date in
                        switch activeDateScanField {
                        case .rca:
                            viewModel.rcaDate = date
                        case .itp:
                            viewModel.itpDate = date
                        case .rovinieta:
                            viewModel.rovinietaDate = date
                        case .none:
                            break
                        }
                    }
                )
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
