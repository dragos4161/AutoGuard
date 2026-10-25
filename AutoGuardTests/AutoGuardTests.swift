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
        #expect(emptyStatus.title == "Liniște deplină")

        // Garaj cu mașină cu act expirat -> Atenție la termene
        let vehicle = Vehicle(plateNumber: "B 123 ABC", make: "Dacia", model: "Duster")
        let expiredDoc = VehicleDocument(type: .rca, expirationDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
        vehicle.documents = [expiredDoc]

        let warningStatus = viewModel.statusBannerData(for: [vehicle])
        #expect(warningStatus.isWarning == true)
        #expect(warningStatus.title == "Atenție la termene")
    }
}
