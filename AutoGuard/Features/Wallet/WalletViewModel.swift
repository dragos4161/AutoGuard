//
//  WalletViewModel.swift
//  AutoGuard
//
//  ViewModel pentru Portofelul Digital de Acte (Mod Control Rutier).
//  Gestionează luminozitatea maximă a ecranului, încărcarea pozelor pentru talon/permis,
//  previzualizarea documentelor și verificările oficiale online.
//

import Combine
import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

public enum WalletTab: String, CaseIterable, Identifiable {
    case rca
    case registration
    case inspections
    case driverLicense

    public var id: String { rawValue }

    public var titleKey: LocalizedStringKey {
        switch self {
        case .rca: return "wallet.tab.rca"
        case .registration: return "wallet.tab.talon"
        case .inspections: return "wallet.tab.inspections"
        case .driverLicense: return "wallet.tab.license"
        }
    }

    public var iconName: String {
        switch self {
        case .rca: return "shield.lefthalf.filled"
        case .registration: return "doc.text.image"
        case .inspections: return "checkmark.seal.fill"
        case .driverLicense: return "person.text.rectangle.fill"
        }
    }
}

@MainActor
final class WalletViewModel: ObservableObject {
    @Published var selectedTab: WalletTab = .rca
    @Published var isMaxBrightnessEnabled: Bool = false
    @Published var showingCopiedVinToast: Bool = false
    @Published var previewImage: UIImage? = nil
    @Published var isShowingImagePreview: Bool = false
    @Published var previewURL: URL? = nil

    // Photo pickers
    @Published var registrationFrontItem: PhotosPickerItem? = nil
    @Published var registrationBackItem: PhotosPickerItem? = nil
    @Published var driverLicenseFrontItem: PhotosPickerItem? = nil
    @Published var driverLicenseBackItem: PhotosPickerItem? = nil

    private var previousBrightness: CGFloat? = nil

    // MARK: - Luminozitate Ecran
    func toggleBrightness() {
        if isMaxBrightnessEnabled {
            restoreBrightness()
        } else {
            enableMaxBrightness()
        }
    }

    func enableMaxBrightness() {
        guard !isMaxBrightnessEnabled else { return }
        previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
        isMaxBrightnessEnabled = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func restoreBrightness() {
        if let prev = previousBrightness {
            UIScreen.main.brightness = prev
            previousBrightness = nil
        }
        isMaxBrightnessEnabled = false
    }

    // MARK: - Clipboard VIN
    func copyVinToClipboard(_ vin: String) {
        guard !vin.isEmpty else { return }
        UIPasteboard.general.string = vin
        showingCopiedVinToast = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showingCopiedVinToast = false
        }
    }

    // MARK: - Previzualizare Imagini
    func showImagePreview(data: Data?) {
        guard let data, let image = UIImage(data: data) else { return }
        self.previewImage = image
        self.isShowingImagePreview = true
    }

    // MARK: - Previzualizare Atașament Document (PDF / Poză)
    func openAttachment(for doc: VehicleDocument) {
        guard let data = doc.attachmentData else { return }
        let fileName = doc.attachmentFileName ?? "Document_\(doc.typeRawValue).pdf"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(doc.id.uuidString)_\(fileName)")
        do {
            try data.write(to: tempURL, options: .atomic)
            self.previewURL = tempURL
        } catch {
            print("Eroare la scrierea atașamentului temporar: \(error)")
        }
    }

    // MARK: - Procesare Fotografii Talon & Permis
    func handlePhotoPick(
        item: PhotosPickerItem?,
        for keyPath: ReferenceWritableKeyPath<Vehicle, Data?>,
        in vehicle: Vehicle
    ) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            vehicle[keyPath: keyPath] = data
            try? vehicle.modelContext?.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    func removePhoto(
        for keyPath: ReferenceWritableKeyPath<Vehicle, Data?>,
        in vehicle: Vehicle
    ) {
        vehicle[keyPath: keyPath] = nil
        try? vehicle.modelContext?.save()
    }

    // MARK: - Verificări Oficiale Online
    func openAidaVerification() {
        if let url = URL(string: "https://aida.info.ro/polite-rca") {
            UIApplication.shared.open(url)
        }
    }

    func openCnairVerification() {
        if let url = URL(string: "https://www.erovinieta.ro/vignettes-portal-web/") {
            UIApplication.shared.open(url)
        }
    }

    func openRaromVerification() {
        if let url = URL(string: "https://pro.rarom.ro/istoric_vehicul/dosar_marca.asp") {
            UIApplication.shared.open(url)
        }
    }
}
