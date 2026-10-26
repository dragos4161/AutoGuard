//
//  VehicleCardView.swift
//  AutoGuard
//
//  Cardul vizual pentru o mașină din lista principală (Dashboard).
//  În Flutter, acesta ar fi un `Card` sau `Container` cu decorațiuni și `InkWell`.
//

import SwiftUI

struct VehicleCardView: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Card: Plăcuță + Nume + Icon
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Plăcuța de înmatriculare stilizată românească
                    HStack(spacing: 0) {
                        // Banda albastră europeană
                        VStack(spacing: 1) {
                            Text("★")
                                .font(.system(size: 6))
                                .foregroundStyle(.yellow)
                            Text("RO")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue)

                        // Numărul propriu-zis (ex: B 123 ABC)
                        Text(vehicle.plateNumber)
                            .font(
                                .system(
                                    .subheadline,
                                    design: .monospaced,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )

                    // Nume vehicul (ex: Dacia Duster)
                    Text(vehicle.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !vehicle.nickname.isEmpty {
                        Text(vehicle.nickname)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Iconiță mașină
                Image(systemName: "car.side.fill")
                    .font(.title)
                    .foregroundStyle(.blue.gradient)
            }

            // Grile de status pentru documente (RCA, ITP, Rovinietă)
            if let docs = vehicle.documents, !docs.isEmpty {
                Divider()

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(docs) { doc in
                        HStack(spacing: 6) {
                            Image(systemName: doc.type.iconName)
                                .font(.caption)
                                .foregroundStyle(doc.statusColor)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(doc.type.titleKey)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                statusBadge(for: doc)
                                    .font(.caption.bold())
                                    .foregroundStyle(doc.statusColor)
                            }

                            Spacer()
                        }
                        .padding(8)
                        .background(doc.statusColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func statusBadge(for doc: VehicleDocument) -> some View {
        if doc.isExpired {
            Text("doc.status.expired")
        } else if doc.daysRemaining == 0 {
            Text("doc.status.expires_today")
        } else {
            Text("days_count \(doc.daysRemaining)")
        }
    }
}
