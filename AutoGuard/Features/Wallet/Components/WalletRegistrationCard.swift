//
//  WalletRegistrationCard.swift
//  AutoGuard
//
//  Afișare a Certificatului de Înmatriculare (Talon Auto) în Portofelul Digital.
//  Permite salvarea și vizualizarea securizată a pozelor față/verso ale talonului
//  și copierea rapidă a seriei de șasiu (VIN).
//

import PhotosUI
import SwiftUI

struct WalletRegistrationCard: View {
    @Bindable var vehicle: Vehicle
    @ObservedObject var viewModel: WalletViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Card Specificații Tehnice Talon
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.image")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text("wallet.talon.card_title")
                            .font(.headline.bold())
                    }
                    Spacer()
                }

                Divider()

                // Serie Șasiu (VIN) cu buton de copiere
                VStack(alignment: .leading, spacing: 6) {
                    Text("wallet.talon.vin_label")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(vehicle.vin.isEmpty ? "—" : vehicle.vin)
                            .font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        if !vehicle.vin.isEmpty {
                            Button {
                                viewModel.copyVinToClipboard(vehicle.vin)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: viewModel.showingCopiedVinToast ? "checkmark" : "doc.on.doc")
                                        .font(.caption.bold())
                                    Text(viewModel.showingCopiedVinToast ? "wallet.vin.copied" : "wallet.vin.copy_button")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(viewModel.showingCopiedVinToast ? Color.green.opacity(0.15) : Color.blue.opacity(0.1))
                                .foregroundStyle(viewModel.showingCopiedVinToast ? .green : .blue)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Date de identificare vehicul
                VStack(spacing: 10) {
                    infoRow(label: "wallet.talon.plate_number", value: vehicle.plateNumber, isMonospaced: true)
                    infoRow(label: "wallet.talon.make_model", value: "\(vehicle.make) \(vehicle.model)")
                    infoRow(label: "wallet.talon.year", value: "\(vehicle.year)")
                    if let mileage = vehicle.formattedMileage {
                        infoRow(label: "wallet.talon.odometer", value: mileage)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)

            // Secțiune Fotografii Talon (Față / Verso)
            VStack(alignment: .leading, spacing: 12) {
                Text("wallet.talon.photos_section")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .padding(.leading, 4)

                HStack(spacing: 12) {
                    // Față Talon
                    talonPhotoSlot(
                        title: "wallet.talon.front_title",
                        data: vehicle.registrationFrontData,
                        selection: $viewModel.registrationFrontItem,
                        onDelete: {
                            viewModel.removePhoto(for: \.registrationFrontData, in: vehicle)
                        }
                    )
                    .onChange(of: viewModel.registrationFrontItem) { _, newItem in
                        Task {
                            await viewModel.handlePhotoPick(
                                item: newItem,
                                for: \.registrationFrontData,
                                in: vehicle
                            )
                        }
                    }

                    // Verso Talon
                    talonPhotoSlot(
                        title: "wallet.talon.back_title",
                        data: vehicle.registrationBackData,
                        selection: $viewModel.registrationBackItem,
                        onDelete: {
                            viewModel.removePhoto(for: \.registrationBackData, in: vehicle)
                        }
                    )
                    .onChange(of: viewModel.registrationBackItem) { _, newItem in
                        Task {
                            await viewModel.handlePhotoPick(
                                item: newItem,
                                for: \.registrationBackData,
                                in: vehicle
                            )
                        }
                    }
                }
            }
        }
    }

    private func talonPhotoSlot(
        title: LocalizedStringKey,
        data: Data?,
        selection: Binding<PhotosPickerItem?>,
        onDelete: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            if let data, let uiImage = UIImage(data: data) {
                // Poză Salvată
                ZStack(alignment: .topTrailing) {
                    Button {
                        viewModel.showImagePreview(data: data)
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Menu {
                        PhotosPicker(selection: selection, matching: .images) {
                            Label("wallet.photo.replace", systemImage: "photo.badge.arrow.forward")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .padding(6)
                    }
                }
            } else {
                // Slot Gol cu PhotosPicker
                PhotosPicker(selection: selection, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.title2)
                            .foregroundStyle(.blue)

                        Text("wallet.photo.add")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundStyle(Color.blue.opacity(0.35))
                    )
                }
                .buttonStyle(.plain)
            }

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(label: LocalizedStringKey, value: String, isMonospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(.subheadline, design: .monospaced, weight: .bold) : .subheadline.bold())
                .foregroundStyle(.primary)
        }
    }
}
