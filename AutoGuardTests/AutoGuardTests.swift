//
//  AutoGuardTests.swift
//  AutoGuardTests
//
//  Teste unitare folosind noul framework Apple Swift Testing (@Test).
//  Dovedește că putem testa logica de business din ViewModels fără să pornim simulatorul!
//

import Foundation
import Testing
@testable import AutoGuard

struct AutoGuardTests {

    // MARK: - Teste Model
    @Test func testDocumentDaysRemaining() async throws {
        let tenDaysLater = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let doc = VehicleDocument(type: .rca, expirationDate: tenDaysLater)

        #expect(doc.daysRemaining == 10)
        #expect(doc.isExpired == false)
        #expect(doc.isExpiringSoon == true)
    }

    @Test func testExpiredDocument() async throws {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let doc = VehicleDocument(type: .itp, expirationDate: twoDaysAgo)

        #expect(doc.isExpired == true)
        #expect(doc.daysRemaining < 0)
    }

    // MARK: - Teste ViewModel (Validare Formular AddVehicle)
    @Test func testAddVehicleFormValidation() async throws {
        let viewModel = AddVehicleViewModel()

        // 1. Inițial formularul este invalid (câmpurile sunt goale)
        #expect(viewModel.isFormValid == false)

        // 2. Doar numărul de înmatriculare nu este suficient
        viewModel.plateNumber = "B 123 ABC"
        #expect(viewModel.isFormValid == false)

        // 3. Când adăugăm și marca, devine valid
        viewModel.make = "Dacia"
        #expect(viewModel.isFormValid == true)

        // 4. Test formatare număr (eliminare spații și transformare în majuscule)
        viewModel.plateNumber = "  cj 01 xyz  "
        #expect(viewModel.formattedPlateNumber == "CJ 01 XYZ")
    }

    // MARK: - Teste ViewModel (Garage Peace of Mind Banner)
    @Test func testGarageBannerStatus() async throws {
        let viewModel = GarageViewModel()

        // Garaj fără mașini -> Liniște deplină
        let emptyStatus = viewModel.statusBannerData(for: [])
        #expect(emptyStatus.isWarning == false)

        // Garaj cu mașină cu act expirat -> Atenție la termene
        let vehicle = Vehicle(plateNumber: "B 123 ABC", make: "Dacia", model: "Duster")
        let expiredDoc = VehicleDocument(type: .rca, expirationDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
        vehicle.documents = [expiredDoc]

        let warningStatus = viewModel.statusBannerData(for: [vehicle])
        #expect(warningStatus.isWarning == true)

        // Dacă documentul expirat este arhivat în istoric, nu mai dă alertă!
        expiredDoc.isArchived = true
        let archivedStatus = viewModel.statusBannerData(for: [vehicle])
        #expect(archivedStatus.isWarning == false)
    }

    // MARK: - Teste Model (Kilometraj)
    @Test func testVehicleMileageTracking() async throws {
        let vehicle = Vehicle(plateNumber: "B 123 ABC", make: "Dacia", model: "Duster")
        #expect(vehicle.currentMileage == nil)
        #expect(vehicle.formattedMileage == nil)

        let olderEntry = MileageEntry(mileage: 140000, date: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        let recentEntry = MileageEntry(mileage: 145200, date: Date())

        vehicle.mileageEntries = [olderEntry, recentEntry]

        #expect(vehicle.currentMileage == 145200)
        #expect(vehicle.formattedMileage == "145.200 km")
        #expect(vehicle.sortedMileageEntries.first?.mileage == 145200)
    }

    // MARK: - Teste Model (Service & Schimb Ulei)
    @Test func testServiceRecordAndOilChangeCalculation() async throws {
        let vehicle = Vehicle(plateNumber: "B 123 ABC", make: "Dacia", model: "Duster")
        vehicle.oilChangeIntervalKm = 10000
        vehicle.oilChangeIntervalMonths = 12

        // Fără istoric de service -> statusul este nil
        #expect(vehicle.oilChangeStatus == nil)

        // Adăugăm revizie făcută acum 2 luni la 140.000 km
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let service = ServiceRecord(
            title: "Revizie Ulei & Filtre",
            category: .oilAndFilters,
            date: twoMonthsAgo,
            mileage: 140000,
            price: 650.0
        )
        vehicle.serviceRecords = [service]

        // Setăm kilometrajul actual la 147.000 km
        let currentMileage = MileageEntry(mileage: 147000, date: Date())
        vehicle.mileageEntries = [currentMileage]

        // Verificăm calculul: 140.000 + 10.000 = 150.000 -> mai sunt 3.000 km
        let status = vehicle.oilChangeStatus
        #expect(status != nil)
        #expect(status?.remainingKm == 3000)
        #expect(status?.isOverdue == false)
        #expect(status?.limitingFactor == .mileage)
        #expect(status?.kmProgressPercent == 70)

        // Dacă parcurgem încă 4.000 km (total 151.000 km) -> revizia devine depășită!
        let highMileage = MileageEntry(mileage: 151000, date: Date())
        vehicle.mileageEntries?.append(highMileage)

        let overdueStatus = vehicle.oilChangeStatus
        #expect(overdueStatus?.isOverdue == true)
        #expect((overdueStatus?.remainingKm ?? 0) < 0)
    }
}
