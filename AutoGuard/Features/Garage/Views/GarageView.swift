//
//  GarageView.swift
//  AutoGuard
//
//  UI pur pentru ecranul principal (Garajul Meu).
//  Toată logica de calcul a stării și operațiile pe date sunt delegate către `GarageViewModel`.
//

import SwiftData
import SwiftUI

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext

    // `@Query` ascultă direct de baza de date SwiftData și oferă colecția actualizată
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles:
        [Vehicle]

    // ViewModel-ul gestionează starea interfeței și calculele de business
    @State private var viewModel = GarageViewModel()
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var isShowingPaywall: Bool = false
    @State private var walletVehicle: Vehicle? = nil
    @State private var isShowingQuickFuelSheet: Bool = false
    @State private var navigationPath = NavigationPath()
    
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if vehicles.isEmpty {
                    // Empty State
                    ContentUnavailableView {
                        Label("garage.empty.title", systemImage: "car.2.fill")
                    } description: {
                        Text(
                            "garage.empty.subtitle"
                        )
                    } actions: {
                        Button {
                            viewModel.isShowingAddVehicleSheet = true
                        } label: {
                            Text("garage.add_vehicle")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                } else {
                    // Lista mașinilor din garaj (adaptivă iPad & iPhone)
                    ScrollView {
                        VStack(spacing: 20) {
                            // Banner de Design Emoțional
                            peaceOfMindBanner
                                .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity)

                            // Cardurile vehiculelor
                            if horizontalSizeClass == .regular {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 360, maximum: 540), spacing: 16)],
                                    spacing: 16
                                ) {
                                    ForEach(vehicles) { vehicle in
                                        vehicleCardItem(vehicle)
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(vehicles) { vehicle in
                                        vehicleCardItem(vehicle)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                quickFuelFAB
            }
            .navigationTitle("garage.title")
            .navigationDestination(for: Vehicle.self) { selectedVehicle in
                // 2. Router-ul central: "Când cineva navighează cu un obiect Vehicle, deschide acest ecran:"
                VehicleDetailsView(vehicle: selectedVehicle)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if SubscriptionManager.isMonetizationEnabled && !subscriptionManager.isProUser {
                            Button {
                                isShowingPaywall = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.caption2.bold())
                                    Text("PRO")
                                        .font(.caption2.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.gradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                        }

                        Button {
                            if SubscriptionManager.isMonetizationEnabled && !vehicles.isEmpty && !subscriptionManager.isProUser {
                                isShowingPaywall = true
                            } else {
                                viewModel.isShowingAddVehicleSheet = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(AppLanguage.allCases) { lang in
                            Button {
                                appLanguage = lang
                            } label: {
                                if appLanguage == lang {
                                    Label(lang.displayName, systemImage: "checkmark")
                                } else {
                                    Text(lang.displayName)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingAddVehicleSheet) {
                AddVehicleView()
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
            .fullScreenCover(item: $walletVehicle) { selectedVehicle in
                DigitalWalletView(vehicle: selectedVehicle)
            }
            .sheet(isPresented: $isShowingQuickFuelSheet) {
                AddFuelEntrySheet()
            }
            .onAppear {
                if let first = vehicles.first {
                    WidgetDataManager.shared.updateWidgetData(for: first)
                } else {
                    WidgetDataManager.shared.clearWidgetData()
                }
            }
            .onChange(of: vehicles) { _, newVehicles in
                if let first = newVehicles.first {
                    WidgetDataManager.shared.updateWidgetData(for: first)
                } else {
                    WidgetDataManager.shared.clearWidgetData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleWidgetDeepLink"))) { notification in
                guard let url = notification.object as? URL else { return }
                if url.host == "vehicle" {
                    let vehicleIdString = url.lastPathComponent
                    if let targetVehicle = vehicles.first(where: { $0.id.uuidString == vehicleIdString }) {
                        navigationPath = NavigationPath()
                        navigationPath.append(targetVehicle)
                    }
                }
            }
        }
    }

    /// Buton plutitor rapid pentru alimentări / scanare bon fiscal (FAB)
    @ViewBuilder
    private var quickFuelFAB: some View {
        if !vehicles.isEmpty {
            Button {
                isShowingQuickFuelSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "fuelpump.fill")
                        .font(.headline)
                    Text("fuel.quick_scan_fab")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.gradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: Color.orange.opacity(0.38), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }

    /// Banner vizual pentru starea garajului (obține datele calculate curat din ViewModel)
    @ViewBuilder
    private var peaceOfMindBanner: some View {
        let banner = viewModel.statusBannerData(for: vehicles)

        HStack(spacing: 12) {
            Image(
                systemName: banner.isWarning
                    ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
            )
            .font(.title2)
            .foregroundStyle(banner.isWarning ? .orange : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.titleKey)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(banner.subtitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            (banner.isWarning ? Color.orange : Color.green).opacity(0.15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func vehicleCardItem(_ vehicle: Vehicle) -> some View {
        NavigationLink(value: vehicle) {
            VehicleCardView(
                vehicle: vehicle,
                onOpenWallet: {
                    walletVehicle = vehicle
                }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteVehicle(
                    vehicle,
                    in: modelContext
                )
            } label: {
                Label(
                    "garage.delete_vehicle",
                    systemImage: "trash"
                )
            }
        }
    }
}

#Preview {
    GarageView()
        .modelContainer(
            for: [Vehicle.self, VehicleDocument.self],
            inMemory: true
        )
}
