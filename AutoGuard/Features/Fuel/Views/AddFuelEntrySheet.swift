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
                            } else {
                                odometerString = ""
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
                                    Text(AppLanguage.tr("Ultimul km înregistrat", "Last recorded mileage"))
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

        // Înregistrăm automat citirea și în istoricul de kilometraj (indiferent dacă data e azi sau din trecut), dacă nu există deja
        let alreadyRecorded = (vehicle.mileageEntries ?? []).contains(where: { $0.mileage == odo })
        if odo > 0 && !alreadyRecorded {
            let fuelLabel = AppLanguage.tr("Alimentare", "Fuel")
            let mileageNote = notes.isEmpty ? "\(fuelLabel) (\(selectedFuelType.defaultDisplayName))" : "\(fuelLabel) \(notes)"
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

// MARK: - Calculator & Estimator Combustibil Retroactiv (Fără Bonuri, De la RCA / ITP)
struct FuelBackfillEstimatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle

    enum DistanceInputMode: String, CaseIterable, Identifiable {
        case approximateDistance
        case startOdometer

        var id: String { rawValue }

        var title: String {
            switch self {
            case .approximateDistance:
                return AppLanguage.tr("Distanță aproximată (km)", "Approx. distance (km)")
            case .startOdometer:
                return AppLanguage.tr("Km în bord la RCA/ITP", "Odometer at RCA/ITP")
            }
        }
    }

    @State private var inputMode: DistanceInputMode = .approximateDistance
    @State private var distanceString: String = "500"
    @State private var startOdometerString: String = ""
    @State private var consumptionString: String = ""
    @State private var pricePerLiterString: String = ""
    @State private var selectedFuelType: FuelType = .petrol95
    @State private var startDate: Date = Date()

    /// Primul bon înregistrat cronologic (sau kilometrajul curent ca referință)
    private var referenceOdometer: Int {
        if let firstFuel = vehicle.chronologicalFuelEntries.first, firstFuel.odometer > 0 {
            return firstFuel.odometer
        }
        return vehicle.currentMileage ?? 0
    }

    private var referenceDate: Date {
        vehicle.chronologicalFuelEntries.first?.date ?? Date()
    }

    private var parsedConsumption: Double? {
        let clean = consumptionString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(clean)
    }

    private var parsedPricePerLiter: Double? {
        let clean = pricePerLiterString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(clean)
    }

    private var computedDistanceKm: Int? {
        switch inputMode {
        case .approximateDistance:
            let clean = distanceString.filter { $0.isNumber }
            guard let dist = Int(clean), dist > 0 else { return nil }
            return dist
        case .startOdometer:
            let clean = startOdometerString.filter { $0.isNumber }
            guard let startOdo = Int(clean), startOdo > 0, referenceOdometer > startOdo else { return nil }
            return referenceOdometer - startOdo
        }
    }

    private var computedStartOdometer: Int? {
        switch inputMode {
        case .approximateDistance:
            guard let dist = computedDistanceKm, referenceOdometer > dist else {
                return referenceOdometer > 0 ? max(1, referenceOdometer - (computedDistanceKm ?? 0)) : nil
            }
            return referenceOdometer - dist
        case .startOdometer:
            let clean = startOdometerString.filter { $0.isNumber }
            return Int(clean)
        }
    }

    private var computedLiters: Double? {
        guard let km = computedDistanceKm,
              let cons = parsedConsumption, cons > 0 else {
            return nil
        }
        return (Double(km) * cons) / 100.0
    }

    private var computedTotalPrice: Double? {
        guard let liters = computedLiters,
              let price = parsedPricePerLiter, price > 0 else {
            return nil
        }
        return liters * price
    }

    private var isValid: Bool {
        guard let km = computedDistanceKm, km > 0,
              let liters = computedLiters, liters > 0,
              let total = computedTotalPrice, total > 0,
              let startOdo = computedStartOdometer, startOdo > 0 else {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Explicație & Referință RCA / ITP
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "wand.and.stars")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text(AppLanguage.tr(
                                "Estimare Carburant Fără Bonuri",
                                "Fuel Estimator Without Receipts"
                            ))
                            .font(.subheadline.bold())
                        }

                        Text(AppLanguage.tr(
                            "Calculează automat combustibilul și costul pentru perioada dintre plata RCA/ITP și primul bon salvat (\(referenceOdometer.formatted()) km pe \(referenceDate.formatted(date: .abbreviated, time: .omitted))), fără să afecteze media de consum dintre plinurile reale.",
                            "Automatically calculates fuel volume and cost between your RCA/ITP date and your first saved receipt (\(referenceOdometer.formatted()) km on \(referenceDate.formatted(date: .abbreviated, time: .omitted))), without altering your real full-tank consumption average."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    DatePicker(
                        AppLanguage.tr("Data de început (RCA / ITP)", "Start Date (RCA / ITP)"),
                        selection: $startDate,
                        displayedComponents: .date
                    )
                }

                // Secțiunea 2: Kilometri parcurși în acea perioadă
                Section {
                    Picker(AppLanguage.tr("Mod calcul km", "Distance mode"), selection: $inputMode.animation(.easeInOut)) {
                        ForEach(DistanceInputMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if inputMode == .approximateDistance {
                        HStack {
                            Text(AppLanguage.tr("Km parcurși aproximativ", "Approx. km driven"))
                            Spacer()
                            TextField("500", text: $distanceString)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body.monospaced().bold())
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text(AppLanguage.tr("Km în bord la RCA / ITP", "Odometer at RCA / ITP"))
                            Spacer()
                            TextField("208000", text: $startOdometerString)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body.monospaced().bold())
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let startOdo = computedStartOdometer, let dist = computedDistanceKm {
                        HStack {
                            Text(AppLanguage.tr("Interval odometru:", "Odometer interval:"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(startOdo.formatted()) km → \(referenceOdometer.formatted()) km (+\(dist.formatted()) km)")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text(AppLanguage.tr("1. Kilometri în perioada fără bonuri", "1. Distance in period without receipts"))
                } footer: {
                    Text(AppLanguage.tr(
                        "Sfat: Dacă ai făcut ITP-ul în aceeași perioadă cu RCA-ul, kilometrajul exact din acea zi este trecut pe raportul ITP!",
                        "Tip: If you did your ITP inspection around the same time as RCA, the exact odometer reading is printed on your ITP certificate!"
                    ))
                }

                // Secțiunea 3: Consum & Preț Mediu OMV
                Section {
                    Picker("fuel.field.type", selection: $selectedFuelType) {
                        ForEach(FuelType.allCases) { type in
                            Text(type.titleKey).tag(type)
                        }
                    }

                    HStack {
                        Text(AppLanguage.tr("Consum mediu folosit", "Average consumption"))
                        Spacer()
                        TextField("11.44", text: $consumptionString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced().bold())
                        Text("L/100km")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(AppLanguage.tr("Preț mediu / litru", "Avg price / liter"))
                        Spacer()
                        TextField("10.11", text: $pricePerLiterString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced().bold())
                        Text("lei/L")
                            .foregroundStyle(.secondary)
                    }

                    // Butoane rapide pentru prețul mediu OMV
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let avgReceiptPrice = vehicle.averagePricePerLiter {
                                pricePresetChip(
                                    label: AppLanguage.tr(
                                        String(format: "Media bonurilor tale (%.2f lei)", avgReceiptPrice),
                                        String(format: "Your receipts avg (%.2f lei)", avgReceiptPrice)
                                    ),
                                    price: avgReceiptPrice
                                )
                            }
                            pricePresetChip(
                                label: AppLanguage.tr("OMV MaxxMotion 95 (9.93 lei)", "OMV MaxxMotion 95 (9.93 lei)"),
                                price: 9.93
                            )
                            pricePresetChip(
                                label: AppLanguage.tr("OMV Standard 95 (~7.35 lei)", "OMV Standard 95 (~7.35 lei)"),
                                price: 7.35
                            )
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(AppLanguage.tr("2. Consum & Preț Carburant", "2. Consumption & Fuel Price"))
                }

                // Secțiunea 4: Rezultat Calculat
                if let liters = computedLiters, let total = computedTotalPrice, let dist = computedDistanceKm {
                    Section {
                        VStack(spacing: 10) {
                            HStack {
                                Text(AppLanguage.tr("Distanță estimată", "Estimated distance"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(dist.formatted()) km")
                                    .fontWeight(.semibold)
                            }
                            HStack {
                                Text(AppLanguage.tr("Cantitate estimată", "Estimated volume"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f L", liters))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Divider()
                            HStack {
                                Text(AppLanguage.tr("Cost total estimat", "Estimated total cost"))
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(String(format: "%.0f lei", total))
                                    .font(.title3.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text(AppLanguage.tr("Rezumat Estimare", "Estimation Summary"))
                    }
                }
            }
            .navigationTitle(AppLanguage.tr("Estimator Carburant", "Fuel Estimator"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLanguage.tr("Salvează", "Save")) {
                        saveEstimation()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let rcaStart = vehicle.rcaCycleStartDate {
                    startDate = rcaStart
                } else if let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date()) {
                    startDate = twoMonthsAgo
                }
                let avgCons = vehicle.averageConsumption ?? 11.44
                consumptionString = String(format: "%.2f", avgCons)

                let avgPrice = vehicle.averagePricePerLiter ?? 10.11
                pricePerLiterString = String(format: "%.2f", avgPrice)

                if referenceOdometer > 500 {
                    startOdometerString = "\(referenceOdometer - 500)"
                }
            }
        }
    }

    private func pricePresetChip(label: String, price: Double) -> some View {
        Button {
            pricePerLiterString = String(format: "%.2f", price)
        } label: {
            Text(label)
                .font(.caption2.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.14))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func saveEstimation() {
        guard let startOdo = computedStartOdometer,
              let liters = computedLiters,
              let total = computedTotalPrice else {
            return
        }

        // 1. Salvăm intrarea de kilometraj la data RCA/ITP pentru ca distanța și evoluția km să înceapă de atunci
        let mileageNote = AppLanguage.tr("Kilometraj la începutul RCA / ITP", "Odometer at RCA / ITP start")
        let mileageEntry = MileageEntry(mileage: startOdo, date: startDate, note: mileageNote)
        mileageEntry.vehicle = vehicle
        modelContext.insert(mileageEntry)

        // 2. Salvăm alimentarea estimată cu `isFullTank = false` (nu alterează media de consum dintre plinurile reale!)
        let fuelNote = AppLanguage.tr("Estimare carburant (de la RCA • OMV)", "Estimated fuel (since RCA • OMV)")
        let fuelEntry = FuelEntry(
            odometer: startOdo,
            liters: (liters * 100).rounded() / 100,
            totalPrice: (total * 100).rounded() / 100,
            date: startDate,
            isFullTank: false,
            fuelType: selectedFuelType,
            notes: fuelNote
        )
        fuelEntry.vehicle = vehicle
        modelContext.insert(fuelEntry)

        do {
            try modelContext.save()
            WidgetDataManager.shared.updateWidgetData(for: vehicle)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            print("Eroare la salvarea estimării de carburant: \(error)")
        }
    }
}
