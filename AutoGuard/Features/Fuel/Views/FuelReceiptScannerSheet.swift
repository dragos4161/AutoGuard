//
//  FuelReceiptScannerSheet.swift
//  AutoGuard
//
//  Ecran dedicat pentru scanarea bonurilor fiscale de carburant (Cameră / Galerie Foto).
//  Extrage automat litrii, suma totală, benzinăria, data și tipul de carburant.
//

import PhotosUI
import SwiftUI

struct FuelReceiptScannerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onReceiptExtracted: (FuelReceiptScanResult) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessing: Bool = false
    @State private var extractedResult: FuelReceiptScanResult? = nil
    @State private var showingErrorAlert: Bool = false
    @State private var selectedImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let result = extractedResult, result.hasUsableData {
                    // Previzualizare Date Extrase cu Succes
                    extractedSummaryView(result)
                } else {
                    // Ecran de Ghidare și Selecție Bon
                    receiptPickerView
                }
            }
            .padding(20)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("fuel.ocr.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
            .alert("fuel.ocr.error_title", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {
                    selectedPhotoItem = nil
                }
            } message: {
                Text("fuel.ocr.error_message")
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 14) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text("fuel.ocr.processing")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    // MARK: - Vizualizare Ghidare & Buton Galerie
    private var receiptPickerView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 110, height: 110)

                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 10) {
                Text("fuel.ocr.prompt_title")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("fuel.ocr.prompt_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.headline)
                        Text("ocr.pick_from_photos")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isProcessing)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    processPickedItem(newItem)
                }

                Button {
                    dismiss()
                } label: {
                    Text("fuel.ocr.manual_entry")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Vizualizare Rezultat Extras
    private func extractedSummaryView(_ result: FuelReceiptScanResult) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("fuel.ocr.success_title")
                    .font(.headline.bold())
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                if let station = result.stationName {
                    summaryRow(icon: "building.2.fill", label: "fuel.ocr.station", value: station, color: .primary)
                }

                if let liters = result.liters {
                    summaryRow(icon: "fuelpump.fill", label: "fuel.field.liters", value: String(format: "%.2f L", liters), color: .blue)
                }

                if let total = result.totalPrice {
                    summaryRow(icon: "banknote.fill", label: "fuel.field.total_price", value: String(format: "%.2f lei", total), color: .green)
                }

                if let unit = result.unitPrice {
                    summaryRow(icon: "tag.fill", label: "fuel.field.price_per_liter", value: String(format: "%.2f lei / L", unit), color: .secondary)
                }

                if let fuelType = result.fuelType {
                    summaryRow(icon: fuelType.iconName, label: "fuel.field.type", value: fuelType.defaultDisplayName, color: .orange)
                }

                if let date = result.date {
                    summaryRow(icon: "calendar", label: "common.date", value: date.formatted(date: .abbreviated, time: .omitted), color: .primary)
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            Button {
                onReceiptExtracted(result)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("fuel.ocr.apply_button")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func summaryRow(icon: String, label: LocalizedStringKey, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }

    // MARK: - Procesare Imagine cu Apple Vision
    private func processPickedItem(_ item: PhotosPickerItem) {
        isProcessing = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let recognizedText = await TextRecognitionService.shared.recognizeText(from: uiImage)
                let scanResult = TextRecognitionService.shared.extractFuelReceiptData(from: recognizedText)

                await MainActor.run {
                    isProcessing = false
                    if scanResult.hasUsableData {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        self.extractedResult = scanResult
                    } else {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        self.showingErrorAlert = true
                    }
                }
            } else {
                await MainActor.run {
                    isProcessing = false
                    self.showingErrorAlert = true
                }
            }
        }
    }
}
