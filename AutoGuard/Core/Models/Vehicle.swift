//
//  Vehicle.swift
//  AutoGuard
//
//  Modelul principal SwiftData pentru un vehicul din garajul utilizatorului.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Vehicle {
    var id: UUID = UUID()
    var plateNumber: String = ""  // Ex: B 123 ABC
    var make: String = ""  // Ex: Dacia, Volkswagen, BMW
    var model: String = ""  // Ex: Duster, Golf, Seria 3
    var year: Int = 2023
    var vin: String = ""  // Serie șasiu (17 caractere)
    var nickname: String = ""  // Ex: "Mașina familiei"
    var createdAt: Date = Date()

    // Relație one-to-many cu documentele mașinii (opțională pentru compatibilitate CloudKit)
    @Relationship(deleteRule: .cascade, inverse: \VehicleDocument.vehicle)
    var documents: [VehicleDocument]? = []

    // Relație one-to-many cu istoricul de kilometri al mașinii
    @Relationship(deleteRule: .cascade, inverse: \MileageEntry.vehicle)
    var mileageEntries: [MileageEntry]? = []

    // Relație one-to-many cu istoricul de service și revizii
    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.vehicle)
    var serviceRecords: [ServiceRecord]? = []

    // Relație one-to-many cu istoricul de alimentare și consum
    @Relationship(deleteRule: .cascade, inverse: \FuelEntry.vehicle)
    var fuelEntries: [FuelEntry]? = []

    // Setări intervale mentenanță (schimb ulei)
    var oilChangeIntervalKm: Int = 10000
    var oilChangeIntervalMonths: Int = 12

    // Stocare poze talon (față / verso) pentru Mod Control Rutier / Portofel Acte
    @Attribute(.externalStorage)
    var registrationFrontData: Data? = nil

    @Attribute(.externalStorage)
    var registrationBackData: Data? = nil

    // Stocare opțională permis conducere
    @Attribute(.externalStorage)
    var driverLicenseFrontData: Data? = nil

    @Attribute(.externalStorage)
    var driverLicenseBackData: Data? = nil

    init(
        plateNumber: String,
        make: String,
        model: String,
        year: Int = Calendar.current.component(.year, from: Date()),
        vin: String = "",
        nickname: String = ""
    ) {
        self.id = UUID()
        self.plateNumber = plateNumber.uppercased()
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin.uppercased()
        self.nickname = nickname
        self.createdAt = Date()
    }

    /// Doar documentele active (curente) ale mașinii
    var activeDocuments: [VehicleDocument] {
        (documents ?? []).filter { !$0.isArchived }
    }

    /// Istoricul documentelor vechi (arhivate la reînnoire), de la cel mai recent la cel mai vechi
    var archivedDocuments: [VehicleDocument] {
        (documents ?? [])
            .filter { $0.isArchived }
            .sorted { $0.expirationDate > $1.expirationDate }
    }

    /// Găsește un document activ specific (ex: RCA sau ITP)
    func document(for type: DocumentType) -> VehicleDocument? {
        activeDocuments.first { $0.type == type }
    }

    /// Cel mai urgent document activ (cel cu cele mai puține zile rămase)
    var mostUrgentDocument: VehicleDocument? {
        activeDocuments.min { $0.daysRemaining < $1.daysRemaining }
    }

    /// Titlul complet al mașinii pentru interfață
    var displayName: String {
        let name = "\(make) \(model)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? plateNumber : name
    }

    // MARK: - Kilometraj
    /// Toate intrările de kilometraj sortate de la cea mai recentă la cea mai veche
    var sortedMileageEntries: [MileageEntry] {
        (mileageEntries ?? []).sorted { $0.date > $1.date }
    }

    /// Kilometrajul curent (cea mai recentă înregistrare)
    var currentMileage: Int? {
        sortedMileageEntries.first?.mileage
    }

    /// Formatare frumoasă cu separator de mii (ex: "145.200 km")
    var formattedMileage: String? {
        guard let currentMileage else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formattedNumber = formatter.string(from: NSNumber(value: currentMileage)) ?? "\(currentMileage)"
        return "\(formattedNumber) km"
    }

    // MARK: - Jurnal Alimentare & Consum
    /// Intrările de alimentare sortate descrescător după dată (cea mai recentă prima)
    var sortedFuelEntries: [FuelEntry] {
        (fuelEntries ?? []).sorted { $0.date > $1.date }
    }

    /// Intrările de alimentare sortate cronologic (de la cea mai veche la cea mai nouă)
    var chronologicalFuelEntries: [FuelEntry] {
        (fuelEntries ?? []).sorted { $0.date < $1.date }
    }

    /// Total cheltuit pe carburant (lei)
    var totalFuelSpent: Double {
        (fuelEntries ?? []).reduce(0.0) { $0 + $1.totalPrice }
    }

    /// Total litri alimentați
    var totalFuelLiters: Double {
        (fuelEntries ?? []).reduce(0.0) { $0 + $1.liters }
    }

    /// Preț mediu pe litru
    var averagePricePerLiter: Double? {
        guard totalFuelLiters > 0 else { return nil }
        return totalFuelSpent / totalFuelLiters
    }

    /// Calcul consum individual și distanță pentru o alimentare specifică
    func calculation(for entry: FuelEntry) -> (consumption: Double?, distance: Int?) {
        let entries = chronologicalFuelEntries
        guard let currentIndex = entries.firstIndex(where: { $0.id == entry.id }) else {
            return (nil, nil)
        }

        // Căutăm cel mai recent plin anterior
        var previousFullTankIndex: Int? = nil
        for i in stride(from: currentIndex - 1, through: 0, by: -1) {
            if entries[i].isFullTank {
                previousFullTankIndex = i
                break
            }
        }

        guard let prevIndex = previousFullTankIndex else {
            // Nu există un plin anterior de referință
            if currentIndex > 0 {
                let dist = entry.odometer - entries[currentIndex - 1].odometer
                return (nil, dist > 0 ? dist : nil)
            }
            return (nil, nil)
        }

        let distance = entry.odometer - entries[prevIndex].odometer
        guard distance > 0 else { return (nil, nil) }

        // Dacă intrarea curentă este plin, consumul este cantitatea cumulată de la plinul anterior împărțită la distanță
        if entry.isFullTank {
            var accumulatedLiters = 0.0
            for i in (prevIndex + 1)...currentIndex {
                accumulatedLiters += entries[i].liters
            }
            let consumption = (accumulatedLiters / Double(distance)) * 100.0
            return (consumption, distance)
        } else {
            return (nil, distance)
        }
    }

    /// Consum mediu general (l/100km) calculat între primul și ultimul plin complet
    var averageConsumption: Double? {
        let fullTanks = chronologicalFuelEntries.filter { $0.isFullTank }
        guard fullTanks.count >= 2,
              let firstFull = fullTanks.first,
              let lastFull = fullTanks.last else {
            return nil
        }

        let totalDistance = lastFull.odometer - firstFull.odometer
        guard totalDistance > 0 else { return nil }

        let entries = chronologicalFuelEntries
        guard let firstIdx = entries.firstIndex(where: { $0.id == firstFull.id }),
              let lastIdx = entries.firstIndex(where: { $0.id == lastFull.id }),
              lastIdx > firstIdx else {
            return nil
        }

        var totalLiters = 0.0
        for i in (firstIdx + 1)...lastIdx {
            totalLiters += entries[i].liters
        }

        return (totalLiters / Double(totalDistance)) * 100.0
    }

    /// Consum mediu formatat frumos (ex: "6.8 L / 100 km")
    var formattedAverageConsumption: String? {
        guard let avg = averageConsumption else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: avg)) ?? String(format: "%.1f", avg)
        return "\(formatted) L / 100 km"
    }

    // MARK: - Statistici Financiare și Costuri
    /// Total cheltuieli de service înregistrate (lei)
    var totalServiceSpent: Double {
        (serviceRecords ?? []).compactMap { $0.price }.reduce(0.0, +)
    }

    /// Total cheltuieli cu acte, asigurări și taxe de drum (RCA, ITP, Rovinietă RO/Străinătate, CASCO)
    var totalDocumentsSpent: Double {
        (documents ?? []).compactMap { $0.price }.filter { $0 > 0 }.reduce(0.0, +)
    }

    /// Total general cheltuieli (Carburant + Service + Acte & Taxe)
    var totalOverallSpent: Double {
        totalFuelSpent + totalServiceSpent + totalDocumentsSpent
    }

    /// Distanța totală monitorizată (km) calculată din toate citirile de odometru (kilometraj, alimentări, service)
    var trackedDistanceKm: Int? {
        var odometers: [Int] = []
        odometers.append(contentsOf: (mileageEntries ?? []).map(\.mileage))
        odometers.append(contentsOf: (fuelEntries ?? []).map(\.odometer))
        odometers.append(contentsOf: (serviceRecords ?? []).map(\.mileage))
        let valid = odometers.filter { $0 > 0 }
        guard let minKm = valid.min(), let maxKm = valid.max(), maxKm > minKm else {
            return nil
        }
        return maxKm - minKm
    }

    /// Cost mediu real per kilometru (Carburant + Service + RCA/ITP/Roviniete raportat la km parcurși)
    var costPerKm: Double? {
        guard let totalKm = trackedDistanceKm, totalKm > 0 else { return nil }
        return totalOverallSpent / Double(totalKm)
    }

    // MARK: - Filtrare Costuri pe Perioade de Timp

    /// Documentul RCA activ (sau cel mai recent) al mașinii
    var activeRCADocument: VehicleDocument? {
        let rcaDocs = (documents ?? []).filter { $0.type == .rca }
        if let active = rcaDocs.filter({ !$0.isArchived }).max(by: { $0.expirationDate < $1.expirationDate }) {
            return active
        }
        return rcaDocs.max(by: { $0.expirationDate < $1.expirationDate })
    }

    /// Data de început a ciclului anual RCA curent (calculată ca 1 an înainte de expirarea poliței RCA active)
    var rcaCycleStartDate: Date? {
        guard let rca = activeRCADocument else { return nil }
        let calendar = Calendar.current
        if let oneYearBefore = calendar.date(byAdding: .year, value: -1, to: rca.expirationDate) {
            return calendar.startOfDay(for: oneYearBefore)
        }
        return calendar.startOfDay(for: rca.createdAt)
    }

    /// Calculează cheltuielile pe carburant începând de la o anumită dată (sau toate dacă `startDate == nil`)
    func fuelSpent(since startDate: Date?) -> Double {
        let list = (fuelEntries ?? []).filter { startDate == nil || $0.date >= startDate! }
        return list.reduce(0.0) { $0 + $1.totalPrice }
    }

    /// Calculează litrii alimentați începând de la o anumită dată
    func fuelLiters(since startDate: Date?) -> Double {
        let list = (fuelEntries ?? []).filter { startDate == nil || $0.date >= startDate! }
        return list.reduce(0.0) { $0 + $1.liters }
    }

    /// Calculează cheltuielile de service începând de la o anumită dată
    func serviceSpent(since startDate: Date?) -> Double {
        let list = (serviceRecords ?? []).filter { startDate == nil || $0.date >= startDate! }
        return list.compactMap { $0.price }.reduce(0.0, +)
    }

    /// Returnează documentele cu preț înregistrate în perioada selectată
    func pricedDocuments(since startDate: Date?) -> [VehicleDocument] {
        let calendar = Calendar.current
        return (documents ?? [])
            .filter { doc in
                guard (doc.price ?? 0) > 0 else { return false }
                guard let startDate else { return true }
                if doc.createdAt >= startDate {
                    return true
                }
                // Includem și actele a căror dată de început (expirare - 1 an) cade în această fereastră (cu o marjă de 14 zile pt. ITP/Rovinietă făcute lângă RCA)
                if let docStart = calendar.date(byAdding: .year, value: -1, to: doc.expirationDate),
                   let bufferedStart = calendar.date(byAdding: .day, value: -14, to: startDate),
                   docStart >= bufferedStart {
                    return true
                }
                return false
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Calculează cheltuielile cu acte și taxe (RCA, ITP, Rovinietă RO/Străinătate, CASCO) începând de la o anumită dată
    func documentsSpent(since startDate: Date?) -> Double {
        pricedDocuments(since: startDate).compactMap { $0.price }.reduce(0.0, +)
    }

    /// Total cheltuieli (Carburant + Service + Acte/Taxe) începând de la o anumită dată
    func overallSpent(since startDate: Date?) -> Double {
        fuelSpent(since: startDate) + serviceSpent(since: startDate) + documentsSpent(since: startDate)
    }

    /// Distanța parcursă în perioada selectată (cu interpolare la începutul perioadei când există citiri anterioare)
    func trackedDistanceKm(since startDate: Date?) -> Int? {
        guard let startDate else { return trackedDistanceKm }
        let points = odometerChartData(since: startDate)
        let valid = points.map(\.mileage).filter { $0 > 0 }
        if let minKm = valid.min(), let maxKm = valid.max(), maxKm > minKm {
            return maxKm - minKm
        }
        return trackedDistanceKm
    }

    /// Costul real per kilometru în perioada selectată
    func costPerKm(since startDate: Date?) -> Double? {
        guard let km = trackedDistanceKm(since: startDate), km > 0 else { return nil }
        return overallSpent(since: startDate) / Double(km)
    }

    /// Punctele de evoluție a kilometrajului (combinând intrările de odometru, alimentările și service-ul)
    func odometerChartData(since startDate: Date? = nil) -> [OdometerPoint] {
        let calendar = Calendar.current
        var rawPoints: [OdometerPoint] = []

        for entry in (mileageEntries ?? []) where entry.mileage > 0 {
            rawPoints.append(OdometerPoint(
                date: entry.date,
                mileage: entry.mileage,
                sourceLabel: AppLanguage.tr("Odometru", "Odometer")
            ))
        }
        for fuel in (fuelEntries ?? []) where fuel.odometer > 0 {
            rawPoints.append(OdometerPoint(
                date: fuel.date,
                mileage: fuel.odometer,
                sourceLabel: AppLanguage.tr("Alimentare", "Fuel")
            ))
        }
        for service in (serviceRecords ?? []) where service.mileage > 0 {
            rawPoints.append(OdometerPoint(
                date: service.date,
                mileage: service.mileage,
                sourceLabel: AppLanguage.tr("Service", "Service")
            ))
        }

        // Deduplicăm mai întâi tot istoricul pe zi calendaristică (păstrând kilometrajul maxim din acea zi)
        var allByDay: [Date: OdometerPoint] = [:]
        for pt in rawPoints {
            let day = calendar.startOfDay(for: pt.date)
            if let existing = allByDay[day] {
                if pt.mileage >= existing.mileage {
                    allByDay[day] = pt
                }
            } else {
                allByDay[day] = pt
            }
        }
        let allSorted = allByDay.values.sorted { $0.date < $1.date }

        guard let startDate else {
            return allSorted
        }

        let startDay = calendar.startOfDay(for: startDate)
        var inPeriod = allSorted.filter { calendar.startOfDay(for: $0.date) >= startDay }

        // Dacă prima citire din perioadă este la > 14 zile după startDate și avem o citire anterioară,
        // interpolăm liniar kilometrajul la momentul startDate pentru a nu pierde rulajul dintre citiri
        if let firstInPeriod = inPeriod.first,
           firstInPeriod.date.timeIntervalSince(startDay) > 14 * 86_400,
           let lastBefore = allSorted.last(where: { calendar.startOfDay(for: $0.date) < startDay }),
           firstInPeriod.mileage > lastBefore.mileage {
            let totalSpan = firstInPeriod.date.timeIntervalSince(lastBefore.date)
            if totalSpan > 0 {
                let elapsed = startDay.timeIntervalSince(lastBefore.date)
                let fraction = min(1.0, max(0.0, elapsed / totalSpan))
                let interpolatedKm = lastBefore.mileage + Int((Double(firstInPeriod.mileage - lastBefore.mileage) * fraction).rounded())
                let anchorPoint = OdometerPoint(
                    date: startDay,
                    mileage: interpolatedKm,
                    sourceLabel: AppLanguage.tr("Estimare", "Estimate")
                )
                inPeriod.insert(anchorPoint, at: 0)
            }
        }

        return inPeriod.count >= 2 ? inPeriod : allSorted
    }

    /// Statistici complete de rulaj (km / săptămână, km / lună, ultimul an, proiecție anuală)
    func mileageStats(since startDate: Date? = nil) -> VehicleMileageStats? {
        let points = odometerChartData(since: startDate)
        guard points.count >= 2,
              let first = points.first,
              let last = points.last else {
            return nil
        }

        let minKm = points.map(\.mileage).min() ?? first.mileage
        let maxKm = points.map(\.mileage).max() ?? last.mileage
        let distance = maxKm - minKm
        guard distance > 0 else { return nil }

        let rawDays = max(1.0, last.date.timeIntervalSince(first.date) / 86_400.0)
        let daysTracked = max(1, Int(ceil(rawDays)))
        let dailyKm = Double(distance) / rawDays
        let weeklyKm = Int((dailyKm * 7.0).rounded())
        let monthlyKm = Int((dailyKm * 30.4375).rounded())
        let projectedYearlyKm = Int((dailyKm * 365.0).rounded())

        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())
        let lastYearKm = trackedDistanceKm(since: oneYearAgo) ?? distance

        return VehicleMileageStats(
            totalTrackedKm: distance,
            lastYearKm: lastYearKm,
            weeklyAverageKm: weeklyKm,
            monthlyAverageKm: monthlyKm,
            projectedYearlyKm: projectedYearlyKm,
            daysTracked: daysTracked,
            firstDate: first.date,
            lastDate: last.date
        )
    }

    /// Istoricul valorilor de consum înregistrate la fiecare plin (pentru grafic)
    var consumptionChartData: [ConsumptionPoint] {
        var points: [ConsumptionPoint] = []
        for entry in chronologicalFuelEntries {
            let calc = calculation(for: entry)
            if let consumption = calc.consumption {
                points.append(ConsumptionPoint(date: entry.date, consumption: consumption, odometer: entry.odometer))
            }
        }
        return points
    }

    /// Structura cheltuielilor pe categorii (pentru grafic pie / sector), filtrabilă după dată
    func expenseBreakdownData(since startDate: Date? = nil) -> [ExpenseCategorySlice] {
        var slices: [ExpenseCategorySlice] = []

        let fuelTotal = fuelSpent(since: startDate)
        if fuelTotal > 0 {
            slices.append(ExpenseCategorySlice(
                categoryName: AppLanguage.tr("Carburant", "Fuel"),
                amount: fuelTotal,
                color: .orange,
                iconName: "fuelpump.fill"
            ))
        }

        // Grupăm documentele și taxele (RCA, ITP, Rovinietă RO / Străinătate, CASCO)
        let docsTotal = documentsSpent(since: startDate)
        if docsTotal > 0 {
            slices.append(ExpenseCategorySlice(
                categoryName: AppLanguage.tr("RCA, ITP & Taxe Drum", "RCA, ITP & Road Tolls"),
                amount: docsTotal,
                color: .teal,
                iconName: "shield.lefthalf.filled"
            ))
        }

        // Grupăm service-urile pe categorii
        var serviceCategoryTotals: [ServiceCategory: Double] = [:]
        for record in (serviceRecords ?? []) where (startDate == nil || record.date >= startDate!) {
            if let price = record.price, price > 0 {
                serviceCategoryTotals[record.category, default: 0.0] += price
            }
        }

        for (cat, amount) in serviceCategoryTotals.sorted(by: { $0.value > $1.value }) {
            slices.append(ExpenseCategorySlice(
                categoryName: cat.localizedTitle,
                amount: amount,
                color: cat.color,
                iconName: cat.iconName
            ))
        }

        return slices
    }

    var expenseBreakdownData: [ExpenseCategorySlice] {
        expenseBreakdownData(since: nil)
    }

    // MARK: - Istoric Service & Mentenanță
    /// Înregistrările de service sortate descrescător după dată
    var sortedServiceRecords: [ServiceRecord] {
        (serviceRecords ?? []).sorted { $0.date > $1.date }
    }

    /// Ultima intrare de schimb ulei / revizie filtre
    var lastOilChangeRecord: ServiceRecord? {
        sortedServiceRecords.first { $0.category == .oilAndFilters }
    }

    /// Calculul statusului pentru următorul schimb de ulei
    var oilChangeStatus: MaintenanceStatus? {
        guard let lastRecord = lastOilChangeRecord else {
            return nil
        }

        let baseMileage = lastRecord.mileage
        let targetMileage = baseMileage + oilChangeIntervalKm
        let currentKm = currentMileage ?? baseMileage
        let remainingKm = targetMileage - currentKm

        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .month, value: oilChangeIntervalMonths, to: lastRecord.date) ?? Date()
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: dueDate)
        let remainingDays = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0

        let isOverdue = remainingKm <= 0 || remainingDays <= 0
        let isDueSoon = !isOverdue && (remainingKm <= 1000 || remainingDays <= 30)

        let kmUsed = Double(max(0, currentKm - baseMileage))
        let kmProgress = min(1.0, max(0.0, kmUsed / Double(max(1, oilChangeIntervalKm))))

        let daysTotal = Double(max(1, calendar.dateComponents([.day], from: lastRecord.date, to: dueDate).day ?? 365))
        let daysPassed = Double(max(0, calendar.dateComponents([.day], from: lastRecord.date, to: today).day ?? 0))
        let timeProgress = min(1.0, max(0.0, daysPassed / daysTotal))

        return MaintenanceStatus(
            remainingKm: remainingKm,
            remainingDays: remainingDays,
            dueDate: dueDate,
            isOverdue: isOverdue,
            isDueSoon: isDueSoon,
            kmProgress: kmProgress,
            timeProgress: timeProgress,
            kmUsed: Int(kmUsed),
            targetKm: targetMileage,
            lastServiceDate: lastRecord.date
        )
    }
}

/// Structură ajutătoare pentru afișarea statusului de mentenanță
struct MaintenanceStatus {
    let remainingKm: Int
    let remainingDays: Int
    let dueDate: Date
    let isOverdue: Bool
    let isDueSoon: Bool
    let kmProgress: Double
    let timeProgress: Double
    let kmUsed: Int
    let targetKm: Int
    let lastServiceDate: Date

    enum LimitingFactor {
        case mileage
        case time
        case balanced
    }

    var limitingFactor: LimitingFactor {
        let diff = kmProgress - timeProgress
        if abs(diff) < 0.05 { return .balanced }
        return kmProgress > timeProgress ? .mileage : .time
    }

    var kmProgressPercent: Int {
        Int(min(1.0, max(0.0, kmProgress)) * 100)
    }

    var timeProgressPercent: Int {
        Int(min(1.0, max(0.0, timeProgress)) * 100)
    }

    var monthsRemaining: Int {
        max(0, (remainingDays + 15) / 30)
    }

    var statusColor: SwiftUI.Color {
        if isOverdue {
            return .red
        } else if isDueSoon {
            return .orange
        } else {
            return .green
        }
    }
}

/// Punct de date pentru graficul de evoluție a consumului de carburant
struct ConsumptionPoint: Identifiable {
    var id: UUID = UUID()
    let date: Date
    let consumption: Double
    let odometer: Int
}

/// Punct de date pentru graficul de evoluție a kilometrajului (odometru)
struct OdometerPoint: Identifiable {
    var id: UUID = UUID()
    let date: Date
    let mileage: Int
    let sourceLabel: String
}

/// Statistici de rulaj (km / săptămână, km / lună, ultimul an, proiecție anuală)
struct VehicleMileageStats {
    let totalTrackedKm: Int
    let lastYearKm: Int
    let weeklyAverageKm: Int
    let monthlyAverageKm: Int
    let projectedYearlyKm: Int
    let daysTracked: Int
    let firstDate: Date
    let lastDate: Date
}

/// Felie de date pentru distribuția cheltuielilor pe categorii
struct ExpenseCategorySlice: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let amount: Double
    let color: Color
    let iconName: String

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
        return "\(formatted) lei"
    }
}
