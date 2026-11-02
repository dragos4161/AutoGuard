//
//  WalletDriverLicenseCard.swift
//  AutoGuard
//
//  Afișare și gestionare a copiei digitale de siguranță a Permisului de Conducere.
//

import PhotosUI
import SwiftUI

struct WalletDriverLicenseCard: View {
    @Bindable var vehicle: Vehicle
    @ObservedObject var viewModel: WalletViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Card Principal Permis
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text("wallet.license.card_title")
                            .font(.headline.bold())
                    }
                    Spacer()
                }

                Text("wallet.license.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                // Sloturi Foto Față / Verso
                HStack(spacing: 12) {
                    licensePhotoSlot(
                        title: "wallet.license.front_title",
                        data: vehicle.driverLicenseFrontData,
                        selection: $viewModel.driverLicenseFrontItem,
                        onDelete: {
                            viewModel.removePhoto(for: \.driverLicenseFrontData, in: vehicle)
                        }
                    )
                    .onChange(of: viewModel.driverLicenseFrontItem) { _, newItem in
                        Task {
                            await viewModel.handlePhotoPick(
                                item: newItem,
                                for: \.driverLicenseFrontData,
                                in: vehicle
                            )
                        }
                    }

                    licensePhotoSlot(
                        title: "wallet.license.back_title",
                        data: vehicle.driverLicenseBackData,
                        selection: $viewModel.driverLicenseBackItem,
                        onDelete: {
                            viewModel.removePhoto(for: \.driverLicenseBackData, in: vehicle)
                        }
                    )
                    .onChange(of: viewModel.driverLicenseBackItem) { _, newItem in
                        Task {
                            await viewModel.handlePhotoPick(
                                item: newItem,
                                for: \.driverLicenseBackData,
                                in: vehicle
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)

            // Notă informativă
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("wallet.license.security_note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
    }

    private func licensePhotoSlot(
        title: LocalizedStringKey,
        data: Data?,
        selection: Binding<PhotosPickerItem?>,
        onDelete: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            if let data, let uiImage = UIImage(data: data) {
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
                PhotosPicker(selection: selection, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
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
}
