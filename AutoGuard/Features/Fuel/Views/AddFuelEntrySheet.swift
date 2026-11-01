//
//  AddFuelEntrySheet.swift
//  AutoGuard
//
//  Formular nativ pentru înregistrarea unei noi alimentări cu carburant.
//

import SwiftData
import SwiftUI

struct AddFuelEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle

    @State private var odometerString: String = ""
    @State private var litersString: String = ""
    @State private var totalPriceString: String = ""
    @State private var selectedFuelType: FuelType = .petrol95
    @State private var isFullTank: Bool = true
    @State private var date: Date = Date()
    @State private var notes: String = ""

    // Inițializare kilometraj recomandat din bordul actual al mașinii
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        if let current = vehicle.currentMileage {
            _odometerString = State(initialValue: "\(current)")
        }
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
        guard let odo = parsedOdometer, odo > 0,
              let lit = parsedLiters, lit > 0,
              let price = parsedTotalPrice, price > 0 else {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Mașină & Kilometraj
                Section {
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

                    HStack {
                        Text("fuel.field.odometer")
                        Spacer()
                        TextField("0", text: $odometerString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced())
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
                    Text("fuel.section.title")
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

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        saveFuelEntry()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveFuelEntry() {
        guard let odo = parsedOdometer,
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
