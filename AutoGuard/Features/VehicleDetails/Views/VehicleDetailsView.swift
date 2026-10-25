//
//  VehicleDetailsView.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import SwiftUI
import SwiftData

struct VehicleDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var vehicle: Vehicle
    @State private var viewModel = VehicleDetailsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text("Hello")
            }
        }
    }
}
