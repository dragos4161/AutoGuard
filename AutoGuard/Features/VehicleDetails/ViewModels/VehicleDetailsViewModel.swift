//
//  VehicleDetailsViewModel.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

@Observable
final class VehicleDetailsViewModel {
    // MARK: - State Variables
    var isShowingRenewalSheet: Bool = false
    var isShowingCorrectionSheet: Bool = false
    var selectedDocument: VehicleDocument? = nil
    var isShowingAlert: Bool = false
    var renewalDate: Date = Date()
    var correctionDate: Date = Date()

    // MARK: - Attachment & QuickLook State
    var targetDocumentForAttachment: VehicleDocument? = nil
    var isShowingFileImporter: Bool = false
    var isShowingPhotoPicker: Bool = false
    var selectedPhotoItem: PhotosPickerItem? = nil
    var previewURL: URL? = nil

    // MARK: - Dependencies
    private let repository: VehicleRepositoryProtocol
    init(repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()) {
        self.repository = repository
    }

    // MARK: - Business Logic - Sort active documents
    func sortDocuments(for vehicle: Vehicle) -> [VehicleDocument] {
        vehicle.activeDocuments.sorted { $0.daysRemaining < $1.daysRemaining }
    }

    // MARK: - Business Logic - Corectare Dată Greșită (Edit In-Place)
    func prepareDateCorrection(for document: VehicleDocument) {
        selectedDocument = document
        correctionDate = document.expirationDate
        isShowingCorrectionSheet = true
    }

    func confirmDateCorrection(in context: ModelContext) {
        guard let selectedDocument else { return }
        repository.correctDocumentDate(
            selectedDocument,
            correctedDate: correctionDate,
            in: context
        )
        isShowingCorrectionSheet = false
    }

    // MARK: - Business Logic - Reînnoire (Arhivează vechiul în istoric + Creează unul nou)
    func prepareRenewal(for document: VehicleDocument) {
        let baseDate = document.isExpired ? Date() : document.expirationDate
        renewalDate =
            Calendar.current.date(byAdding: .year, value: 1, to: baseDate)
            ?? Date()
        selectedDocument = document
        isShowingRenewalSheet = true
    }

    func confirmRenewal(in context: ModelContext) {
        guard let selectedDocument else {
            return
        }

        repository.renewVehicleDocument(
            selectedDocument,
            newExpiryDate: renewalDate,
            in: context
        )
        isShowingRenewalSheet = false
    }

    // MARK: - Business Logic - Atașare și Vizualizare Documente (PDF / Poză)
    func triggerFileImport(for document: VehicleDocument) {
        targetDocumentForAttachment = document
        isShowingFileImporter = true
    }

    func triggerPhotoPicker(for document: VehicleDocument) {
        targetDocumentForAttachment = document
        selectedPhotoItem = nil
        isShowingPhotoPicker = true
    }

    func handleImportedFile(result: Result<[URL], Error>, in context: ModelContext) {
        guard let targetDoc = targetDocumentForAttachment else { return }
        guard case .success(let urls) = result, let fileURL = urls.first else { return }

        let canAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        if let data = try? Data(contentsOf: fileURL) {
            repository.updateDocumentAttachment(
                targetDoc,
                data: data,
                fileName: fileURL.lastPathComponent,
                in: context
            )
        }
        targetDocumentForAttachment = nil
    }

    @MainActor
    func handleSelectedPhoto(in context: ModelContext) async {
        guard let targetDoc = targetDocumentForAttachment,
              let item = selectedPhotoItem else { return }

        if let data = try? await item.loadTransferable(type: Data.self) {
            let safeName = "\(targetDoc.type.rawValue)_Foto.jpg"
            repository.updateDocumentAttachment(
                targetDoc,
                data: data,
                fileName: safeName,
                in: context
            )
        }
        selectedPhotoItem = nil
        targetDocumentForAttachment = nil
    }

    func openAttachment(for document: VehicleDocument) {
        guard let data = document.attachmentData else { return }
        let fileName = document.attachmentFileName ?? "\(document.type.rawValue).pdf"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(document.id.uuidString)_\(fileName)")

        do {
            try data.write(to: tempURL, options: .atomic)
            previewURL = tempURL
        } catch {
            print("Eroare la deschiderea fișierului atașat: \(error)")
        }
    }

    func removeAttachment(for document: VehicleDocument, in context: ModelContext) {
        repository.updateDocumentAttachment(
            document,
            data: nil,
            fileName: nil,
            in: context
        )
    }

    // MARK: - Business Logic - Ștergere document din istoric
    func deleteArchivedDocument(_ document: VehicleDocument, in context: ModelContext) {
        repository.deleteDocument(document, in: context)
    }

    // MARK: - Business Logic - Delete Vehicle
    func deleteVehicle(_ vehicle: Vehicle, in context: ModelContext) {
        repository.deleteVehicle(vehicle, in: context)
    }
}
