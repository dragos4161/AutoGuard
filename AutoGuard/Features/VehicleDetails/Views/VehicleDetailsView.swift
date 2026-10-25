//
//  VehicleDetailsView.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import SwiftData
import SwiftUI

struct VehicleDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var vehicle: Vehicle
    @State private var viewModel = VehicleDetailsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Sus: Cardul cu detaliile mașinii (sau titlul)
                Text(vehicle.displayName)
                    .font(.title2.bold())
                // 2. Jos: Lista de carduri generată de ForEach
                ForEach(viewModel.sortDocuments(for: vehicle)) { doc in
                    DocumentStatusRow(doc: doc) {
                        viewModel.prepareRenewal(for: doc)
                    }
                }
            }
            .padding(16)  // Lasă 16pt spațiu față de marginile ecranului
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
