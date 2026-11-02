//
//  FuelHistoryView.swift
//  AutoGuard
//
//  Ecran complet cu istoricul detaliat al alimentărilor și statistici de consum.
//

import SwiftData
import SwiftUI

struct FuelHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle

    @State private var showingAddSheet: Bool = false

    var body: some View {
        Group {
            if vehicle.sortedFuelEntries.isEmpty {
                ContentUnavailableView {
                    Label("fuel.empty.title", systemImage: "fuelpump.slash")
                } description: {
                    Text("fuel.empty.subtitle")
                } actions: {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Text("fuel.add.button")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    // Secțiunea 1: Statistici Generale
                    Section {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                // Consum mediu
                                statCard(
                                    title: "fuel.stats.avg_consumption",
                                    value: vehicle.formattedAverageConsumption ?? "—",
                                    subtitle: vehicle.averageConsumption != nil
                                        ? AppLanguage.tr("calculat pe plinuri", "based on full tanks")
                                        : AppLanguage.tr("necesită 2 plinuri", "needs 2 full tanks"),
                                    color: .green
                                )

                                // Total cheltuit
                                statCard(
                                    title: "fuel.stats.total_spent",
                                    value: String(format: "%.0f lei", vehicle.totalFuelSpent),
                                    subtitle: String(format: AppLanguage.tr("%.1f L carburant", "%.1f L fuel"), vehicle.totalFuelLiters),
                                    color: .blue
                                )
                            }

                            if let avgPrice = vehicle.averagePricePerLiter {
                                HStack {
                                    Text(AppLanguage.tr("Preț mediu:", "Avg. price:"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f lei / L", avgPrice))
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(AppLanguage.tr("\(vehicle.sortedFuelEntries.count) alimentări", "\(vehicle.sortedFuelEntries.count) fill-ups"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

                    // Secțiunea 2: Înregistrări
                    Section("fuel.history.title") {
                        ForEach(vehicle.sortedFuelEntries) { entry in
                            FuelEntryRowView(entry: entry, calculation: vehicle.calculation(for: entry))
                        }
                        .onDelete(perform: deleteFuelEntries)
                    }
                }
            }
        }
        .navigationTitle("fuel.history.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddFuelEntrySheet(vehicle: vehicle)
        }
    }

    private func statCard(title: LocalizedStringKey, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func deleteFuelEntries(at offsets: IndexSet) {
        let sorted = vehicle.sortedFuelEntries
        for index in offsets {
            let entry = sorted[index]
            modelContext.delete(entry)
        }
        do {
            try modelContext.save()
        } catch {
            print("Eroare la salvare ștergere alimentare: \(error)")
        }
        WidgetDataManager.shared.updateWidgetData(for: vehicle)
    }
}
