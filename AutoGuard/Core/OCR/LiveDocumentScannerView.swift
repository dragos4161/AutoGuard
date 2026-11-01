//
//  LiveDocumentScannerView.swift
//  AutoGuard
//
//  Interfață de scanare live OCR folosind DataScannerViewController (pe dispozitive fizice)
//  și fallback cu PhotosPicker + VNRecognizeTextRequest (pe Simulator / dispozitive fără cameră).
//

import PhotosUI
import SwiftUI
import VisionKit

enum ScanTarget: Identifiable, Equatable {
    case vin
    case plateNumber
    case expirationDate

    var id: String {
        switch self {
        case .vin: return "vin"
        case .plateNumber: return "plateNumber"
        case .expirationDate: return "expirationDate"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .vin: return "ocr.scan_vin.title"
        case .plateNumber: return "ocr.scan_plate.title"
        case .expirationDate: return "ocr.scan_date.title"
        }
    }

    var instructionKey: LocalizedStringKey {
        switch self {
        case .vin: return "ocr.scan_vin.instruction"
        case .plateNumber: return "ocr.scan_plate.instruction"
        case .expirationDate: return "ocr.scan_date.instruction"
        }
    }

    var iconName: String {
        switch self {
        case .vin: return "barcode.viewfinder"
        case .plateNumber: return "car.badge.gearshape.fill"
        case .expirationDate: return "calendar.badge.clock"
        }
    }
}

struct LiveDocumentScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let target: ScanTarget
    var onVinDetected: ((String) -> Void)? = nil
    var onPlateDetected: ((String) -> Void)? = nil
    var onDateDetected: ((Date) -> Void)? = nil

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingPhoto: Bool = false
    @State private var detectedResultPreview: String? = nil

    private var isCameraSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isCameraSupported {
                    // 1. Scanner Camera Live pe iPhone real
                    DataScannerRepresentable(
                        target: target,
                        onResultFound: handleDetectedText
                    )
                    .ignoresSafeArea(edges: .bottom)

                    // Overlay cu instrucțiuni
                    VStack {
                        instructionBanner
                            .padding(.top, 16)
                            .padding(.horizontal, 20)

                        Spacer()

                        if let preview = detectedResultPreview {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(preview)
                                    .font(.headline.bold())
                            }
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 30)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                } else {
                    // 2. Fallback inteligent pentru Simulator / dispozitive fără scanner live
                    simulatorFallbackView
                }
            }
            .navigationTitle(target.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Banner instrucțiuni
    private var instructionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: target.iconName)
                .font(.title3)
                .foregroundStyle(.blue)

            Text(target.instructionKey)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    // MARK: - Fallback Simulator
    private var simulatorFallbackView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text(target.titleKey)
                    .font(.title3.bold())

                Text("Scannerul live cu camera este disponibil pe iPhone-uri fizice. În Simulator, poți alege o imagine sau fotografie cu documentul pentru a testa recunoașterea OCR.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 8) {
                    if isProcessingPhoto {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("ocr.pick_from_photos")
                            .font(.headline)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isProcessingPhoto)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                processPhotoPickerItem(newItem)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Procesare text detectat
    private func handleDetectedText(_ rawText: String) {
        let service = TextRecognitionService.shared

        switch target {
        case .vin:
            if let vin = service.extractVin(from: rawText) {
                notifySuccess(preview: vin) {
                    onVinDetected?(vin)
                }
            }
        case .plateNumber:
            if let plate = service.extractPlateNumber(from: rawText) {
                notifySuccess(preview: plate) {
                    onPlateDetected?(plate)
                }
            }
        case .expirationDate:
            if let date = service.extractExpirationDate(from: rawText) {
                let formatted = date.formatted(date: .abbreviated, time: .omitted)
                notifySuccess(preview: formatted) {
                    onDateDetected?(date)
                }
            }
        }
    }

    private func notifySuccess(preview: String, completion: @escaping () -> Void) {
        detectedResultPreview = preview
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            completion()
            dismiss()
        }
    }

    private func processPhotoPickerItem(_ item: PhotosPickerItem) {
        isProcessingPhoto = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let recognizedText = await TextRecognitionService.shared.recognizeText(from: uiImage)
                await MainActor.run {
                    isProcessingPhoto = false
                    handleDetectedText(recognizedText)
                }
            } else {
                await MainActor.run {
                    isProcessingPhoto = false
                }
            }
        }
    }
}

// MARK: - Wrapper UIViewControllerRepresentable pentru DataScannerViewController
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let target: ScanTarget
    let onResultFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(target: target, onResultFound: onResultFound)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let target: ScanTarget
        let onResultFound: (String) -> Void
        private var hasFoundResult = false

        init(target: ScanTarget, onResultFound: @escaping (String) -> Void) {
            self.target = target
            self.onResultFound = onResultFound
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(addedItems + allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(updatedItems + allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                onResultFound(text.transcript)
            }
        }

        private func processItems(_ items: [RecognizedItem]) {
            guard !hasFoundResult else { return }

            for item in items {
                if case .text(let text) = item {
                    let transcript = text.transcript
                    // Verificăm dacă transcriptul conține deja ceea ce căutăm
                    let service = TextRecognitionService.shared
                    let matches: Bool
                    switch target {
                    case .vin:
                        matches = service.extractVin(from: transcript) != nil
                    case .plateNumber:
                        matches = service.extractPlateNumber(from: transcript) != nil
                    case .expirationDate:
                        matches = service.extractExpirationDate(from: transcript) != nil
                    }

                    if matches {
                        hasFoundResult = true
                        DispatchQueue.main.async {
                            self.onResultFound(transcript)
                        }
                        break
                    }
                }
            }
        }
    }
}
