//
//  DigitalWalletView.swift
//  AutoGuard
//
//  Ecran principal pentru Portofelul Digital de Acte („Digital GloveBox Wallet” / „Mod Control Rutier”).
//  Oferă acces rapid la polița RCA, talonul auto, ITP, rovinietă și permisul de conducere.
//  Include modul de luminozitate maximă pentru citirea facilă a ecranului în trafic.
//

import QuickLook
import SwiftUI

struct DigitalWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vehicle: Vehicle
    @StateObject private var viewModel = WalletViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Plăcuța și Detalii Mașină
                    vehicleHeaderCard

                    // 2. Banner de Status General (Scut Valabilitate)
                    statusSummaryShield

                    // 3. Tab Selector pentru Categorii de Acte
                    tabSelector

                    // 4. Conținutul Tab-ului Selectat
                    Group {
                        switch viewModel.selectedTab {
                        case .rca:
                            WalletRcaCard(
                                vehicle: vehicle,
                                rcaDoc: vehicle.document(for: .rca),
                                viewModel: viewModel
                            )
                        case .registration:
                            WalletRegistrationCard(
                                vehicle: vehicle,
                                viewModel: viewModel
                            )
                        case .inspections:
                            WalletInspectionsCard(
                                vehicle: vehicle,
                                viewModel: viewModel
                            )
                        case .driverLicense:
                            WalletDriverLicenseCard(
                                vehicle: vehicle,
                                viewModel: viewModel
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("wallet.navigation_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.restoreBrightness()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                // Buton Luminozitate Maximă
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.toggleBrightness()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.isMaxBrightnessEnabled ? "sun.max.fill" : "sun.max")
                                .font(.subheadline.bold())
                                .foregroundStyle(viewModel.isMaxBrightnessEnabled ? .yellow : .primary)

                            if viewModel.isMaxBrightnessEnabled {
                                Text("wallet.brightness.active")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.isMaxBrightnessEnabled
                                ? Color.yellow.opacity(0.18)
                                : Color(uiColor: .secondarySystemFill)
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .onDisappear {
                viewModel.restoreBrightness()
            }
            .quickLookPreview($viewModel.previewURL)
            .sheet(isPresented: $viewModel.isShowingImagePreview) {
                if let image = viewModel.previewImage {
                    ImageDetailSheet(image: image)
                }
            }
        }
    }

    // MARK: - Header Plăcuță și Date Vehicul
    private var vehicleHeaderCard: some View {
        HStack(alignment: .center, spacing: 14) {
            // Plăcuță format românesc standard
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text("★")
                        .font(.system(size: 7))
                        .foregroundStyle(.yellow)
                    Text("RO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(Color.blue)

                Text(vehicle.plateNumber)
                    .font(.system(.title3, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.displayName)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)

                if !vehicle.vin.isEmpty {
                    Text("VIN: \(vehicle.vin)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Scut Rezumat Valabilitate
    private var statusSummaryShield: some View {
        let docs = vehicle.activeDocuments
        let expiredCount = docs.filter { $0.isExpired }.count
        let expiringSoonCount = docs.filter { $0.isExpiringSoon }.count

        let isAllClear = expiredCount == 0 && expiringSoonCount == 0
        let statusColor: Color = expiredCount > 0 ? .red : (expiringSoonCount > 0 ? .orange : .green)
        let iconName = expiredCount > 0 ? "exclamationmark.shield.fill" : (expiringSoonCount > 0 ? "shield.lefthalf.filled" : "checkmark.shield.fill")

        return HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                if expiredCount > 0 {
                    Text("wallet.status.has_expired")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("wallet.status.has_expired_desc \(expiredCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if expiringSoonCount > 0 {
                    Text("wallet.status.has_expiring_soon")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("wallet.status.has_expiring_soon_desc \(expiringSoonCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("wallet.status.all_valid")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("wallet.status.all_valid_desc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.caption2)
                Text("wallet.shield_mode")
                    .font(.caption2.bold())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(statusColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Selector Tab-uri
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WalletTab.allCases) { tab in
                    let isSelected = viewModel.selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.subheadline)
                            Text(tab.titleKey)
                                .font(.subheadline.weight(isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                        .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
