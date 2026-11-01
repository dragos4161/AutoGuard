//
//  AddFuelEntrySheet.swift
//  AutoGuard
//
//  Formular nativ pentru înregistrarea unei noi alimentări cu carburant.
//  Suportă scanarea inteligentă a bonului fiscal cu OCR și selecția vehiculului pentru garaje multi-auto.
//

import SwiftData
import SwiftUI

struct AddFuelEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Vehicle.createdAt, order: .reverse) private var allVehicles: [Vehicle]

    let initialVehicle: Vehicle?
    let initialScanResult: FuelReceiptScanResult?

    @State private var selectedVehicle: Vehicle?
    @State private var odometerString: String = ""
    @State private var litersString: String = ""
    @State private var totalPriceString: String = ""
    @State private var selectedFuelType: FuelType = .petrol95
    @State private var isFullTank: Bool = true
    @State private var date: Date = Date()
    @State private var notes: String = ""

    @State private var isShowingReceiptScanner: Bool = false
    @State private var receiptScanSuccessBanner: Bool = false

    // Inițializare flexibilă (pentru mașină specifică sau deschidere rapidă din garaj)
    init(vehicle: Vehicle? = nil, initialScanResult: FuelReceiptScanResult? = nil) {
        self.initialVehicle = vehicle
        self.initialScanResult = initialScanResult
        self._selectedVehicle = State(initialValue: vehicle)

        if let vehicle, let current = vehicle.currentMileage {
            _odometerString = State(initialValue: "\(current)")
        }

        if let scan = initialScanResult {
            if let lit = scan.liters {
                _litersString = State(initialValue: String(format: "%.2f", lit))
            }
            if let tot = scan.totalPrice {
                _totalPriceString = State(initialValue: String(format: "%.2f", tot))
            }
            if let d = scan.date {
                _date = State(initialValue: d)
            }
            if let t = scan.fuelType {
                _selectedFuelType = State(initialValue: t)
            }
            if let st = scan.stationName {
                _notes = State(initialValue: st)
            }
            _receiptScanSuccessBanner = State(initialValue: true)
        }
    }

    private var activeVehicle: Vehicle? {
        selectedVehicle ?? initialVehicle ?? allVehicles.first
    }

    private var parsedOdometer: Int? {
        let clean = odometerString.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
        return Int(clean)
    }

    private var parsedLiters: Double? {
        let clean = litersString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(clean)
    }

    private var parsedTotalPrice: Double? {
        let clean = totalPriceString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(clean)
    }

    private var computedPricePerLiter: Double? {
        guard let liters = parsedLiters, liters > 0,
              let total = parsedTotalPrice, total > 0 else {
            return nil
        }
        return total / liters
    }

    private var isFormValid: Bool {
        guard activeVehicle != nil,
              let odo = parsedOdometer, odo > 0,
              let lit = parsedLiters, lit > 0,
              let price = parsedTotalPrice, price > 0 else {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Banner Notificare Succes Scanare Bon
                if receiptScanSuccessBanner {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("fuel.scan.success_banner_title")
                                    .font(.subheadline.bold())
                                Text("fuel.scan.success_banner_subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                receiptScanSuccessBanner = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Secțiunea 1: Mașină & Kilometraj
                Section {
                    // Selector Mașină pentru garaje cu mai multe vehicule
                    if allVehicles.count > 1 {
                        Picker("common.car", selection: $selectedVehicle) {
                            ForEach(allVehicles) { v in
                                HStack {
                                    Text(v.displayName)
                                    Text("(\(v.plateNumber))")
                                        .foregroundStyle(.secondary)
                                }
                                .tag(v as Vehicle?)
                            }
                        }
                        .onChange(of: selectedVehicle) { _, newVehicle in
                            if let newVehicle, let current = newVehicle.currentMileage {
                                odometerString = "\(current)"
                            }
                        }
                    }

                    if let vehicle = activeVehicle {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.displayName)
                                    .font(.headline)
                                Text(vehicle.plateNumber)
                                    .font(.caption.monospaced().bold())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let current = vehicle.currentMileage {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Ultimul km înregistrat")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(current) km")
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Kilometraj bord
                    HStack {
                        HStack(spacing: 4) {
                            Text("fuel.field.odometer")
                            Text("*")
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        TextField("0", text: $odometerString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced().bold())
                        Text("km")
                            .foregroundStyle(.secondary)
                    }

                    DatePicker("common.date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("common.car")
                }

                // Secțiunea 2: Combustibil & Cost
                Section {
                    Picker("fuel.field.type", selection: $selectedFuelType) {
                        ForEach(FuelType.allCases) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.titleKey)
                            }
                            .tag(type)
                        }
                    }

                    HStack {
                        Text("fuel.field.liters")
                        Spacer()
                        TextField("0.0", text: $litersString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced())
                        Text(selectedFuelType.unitLabel)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("fuel.field.total_price")
                        Spacer()
                        TextField("0.00", text: $totalPriceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced())
                        Text("lei")
                            .foregroundStyle(.secondary)
                    }

                    if let unitPrice = computedPricePerLiter {
                        HStack {
                            Text("fuel.field.price_per_liter")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f lei / %@", unitPrice, selectedFuelType.unitLabel))
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    HStack {
                        Text("fuel.section.title")
                        Spacer()
                        Button {
                            isShowingReceiptScanner = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.viewfinder.fill")
                                Text("fuel.scan_receipt_button")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        }
                    }
                }

                // Secțiunea 3: Detalii suplimentare
                Section {
                    Toggle("fuel.field.full_tank", isOn: $isFullTank)

                    TextField("fuel.field.notes_placeholder", text: $notes)
                } header: {
                    Text("common.details")
                } footer: {
                    Text("fuel.field.full_tank_footer")
                }
            }
            .navigationTitle("fuel.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingReceiptScanner = true
                    } label: {
                        Image(systemName: "doc.viewfinder.fill")
                            .foregroundStyle(.orange)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        saveFuelEntry()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if selectedVehicle == nil {
                    selectedVehicle = initialVehicle ?? allVehicles.first
                    if let v = selectedVehicle, let current = v.currentMileage, odometerString.isEmpty {
                        odometerString = "\(current)"
                    }
                }
            }
            .sheet(isPresented: $isShowingReceiptScanner) {
                FuelReceiptScannerSheet { result in
                    applyReceiptResult(result)
                }
            }
        }
    }

    private func applyReceiptResult(_ result: FuelReceiptScanResult) {
        if let liters = result.liters {
            litersString = String(format: "%.2f", liters)
        }
        if let total = result.totalPrice {
            totalPriceString = String(format: "%.2f", total)
        }
        if let date = result.date {
            self.date = date
        }
        if let type = result.fuelType {
            selectedFuelType = type
        }
        if let station = result.stationName, !station.isEmpty {
            notes = station
        }
        receiptScanSuccessBanner = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func saveFuelEntry() {
        guard let vehicle = activeVehicle,
              let odo = parsedOdometer,
              let liters = parsedLiters,
              let price = parsedTotalPrice else {
            return
        }

        let newEntry = FuelEntry(
            odometer: odo,
            liters: liters,
            totalPrice: price,
            date: date,
            isFullTank: isFullTank,
            fuelType: selectedFuelType,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        newEntry.vehicle = vehicle
        modelContext.insert(newEntry)

        // Actualizăm automat kilometrajul general al mașinii dacă această alimentare are un km mai mare
        let previousMax = vehicle.currentMileage ?? 0
        if odo > previousMax {
            let mileageNote = notes.isEmpty ? "Alimentare (\(selectedFuelType.defaultDisplayName))" : "Alimentare \(notes)"
            let mileageEntry = MileageEntry(mileage: odo, date: date, note: mileageNote)
            mileageEntry.vehicle = vehicle
            modelContext.insert(mileageEntry)
        }

        do {
            try modelContext.save()
            WidgetDataManager.shared.updateWidgetData(for: vehicle)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            print("Eroare la salvarea alimentării: \(error)")
        }
    }
}
