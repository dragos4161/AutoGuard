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
    
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    var body: some View {
        NavigationStack {
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
                    // Lista mașinilor din garaj
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Banner de Design Emoțional (delegat la ViewModel)
                            peaceOfMindBanner

                            // Cardurile pentru fiecare vehicul
                            ForEach(vehicles) { vehicle in
                                NavigationLink(value: vehicle) {  // <-- Trimite doar valoarea 'vehicle'!
                                    VehicleCardView(vehicle: vehicle)
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
                        .padding(16)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle("garage.title")
            .navigationDestination(for: Vehicle.self) { selectedVehicle in
                // 2. Router-ul central: "Când cineva navighează cu un obiect Vehicle, deschide acest ecran:"
                VehicleDetailsView(vehicle: selectedVehicle)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isShowingAddVehicleSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
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
        }
    }

    /// Banner vizual pentru starea garajului (obține datele calculate curat din ViewModel)
    @ViewBuilder
    private var peaceOfMindBanner: some View {
        let banner = viewModel.statusBannerData(for: vehicles)

        HStack(spacing: 12) {
            Image(
                systemName: banner.isWarning
                    ? "exclamationmark.triangle.fill" : "heckmark.shield.fill"
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
}

#Preview {
    GarageView()
        .modelContainer(
            for: [Vehicle.self, VehicleDocument.self],
            inMemory: true
        )
}
