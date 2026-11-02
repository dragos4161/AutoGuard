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
        case rca, itp, rovinieta, foreignVignette, casco, extinguisher
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

                    if !viewModel.vin.isEmpty && !viewModel.isVinValid {
                        Text("edit_vehicle.vin_invalid_hint")
                            .font(.caption)
                            .foregroundStyle(.red)
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

                    let currentYear = Calendar.current.component(.year, from: Date())
                    Picker("edit_vehicle.year", selection: $viewModel.year) {
                        ForEach((1980...(currentYear + 1)).reversed(), id: \.self) { yr in
                            Text(String(yr)).tag(yr)
                        }
                    }

                    TextField("add_vehicle.nickname_placeholder", text: $viewModel.nickname)

                    TextField("add_vehicle.mileage_placeholder", text: $viewModel.initialMileageText)
                        .keyboardType(.numberPad)
                }

                // Secțiunea 2: Termene de expirare & Costuri Acte
                Section("add_vehicle.section.expirations") {
                    // 1. RCA
                    VStack(spacing: 8) {
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
                        priceInputRow(text: $viewModel.rcaPriceText)
                    }

                    // 2. ITP
                    VStack(spacing: 8) {
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
                        priceInputRow(text: $viewModel.itpPriceText)
                    }

                    // 3. Rovinietă România
                    VStack(spacing: 8) {
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
                        priceInputRow(text: $viewModel.rovinietaPriceText)
                    }

                    // 4. Vinietă / Taxă Drum Străinătate (Opțional)
                    Toggle(DocumentType.foreignVignette.titleKey, isOn: $viewModel.includeForeignVignette.animation())
                    if viewModel.includeForeignVignette {
                        VStack(spacing: 8) {
                            HStack {
                                DatePicker(
                                    DocumentType.foreignVignette.titleKey,
                                    selection: $viewModel.foreignVignetteDate,
                                    displayedComponents: .date
                                )

                                Button {
                                    activeDateScanField = .foreignVignette
                                    activeScanTarget = .expirationDate
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "globe.europe.africa.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("doc.foreign_vignette.country_placeholder", text: $viewModel.foreignVignetteCountry)
                                    .font(.subheadline)
                            }

                            priceInputRow(text: $viewModel.foreignVignettePriceText)
                        }
                    }

                    // 5. CASCO (Opțional)
                    Toggle(DocumentType.casco.titleKey, isOn: $viewModel.includeCasco.animation())
                    if viewModel.includeCasco {
                        VStack(spacing: 8) {
                            HStack {
                                DatePicker(
                                    DocumentType.casco.titleKey,
                                    selection: $viewModel.cascoDate,
                                    displayedComponents: .date
                                )

                                Button {
                                    activeDateScanField = .casco
                                    activeScanTarget = .expirationDate
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            priceInputRow(text: $viewModel.cascoPriceText)
                        }
                    }

                    // 6. Trusă & Stingător (Opțional)
                    Toggle(DocumentType.extinguisher.titleKey, isOn: $viewModel.includeExtinguisher.animation())
                    if viewModel.includeExtinguisher {
                        VStack(spacing: 8) {
                            HStack {
                                DatePicker(
                                    DocumentType.extinguisher.titleKey,
                                    selection: $viewModel.extinguisherDate,
                                    displayedComponents: .date
                                )

                                Button {
                                    activeDateScanField = .extinguisher
                                    activeScanTarget = .expirationDate
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            priceInputRow(text: $viewModel.extinguisherPriceText)
                        }
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
                        case .foreignVignette:
                            viewModel.foreignVignetteDate = date
                        case .casco:
                            viewModel.cascoDate = date
                        case .extinguisher:
                            viewModel.extinguisherDate = date
                        case .none:
                            break
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func priceInputRow(text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("doc.price.placeholder", text: text)
                .keyboardType(.decimalPad)
                .font(.subheadline)
            Spacer()
            if !text.wrappedValue.isEmpty {
                Text("lei")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
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
