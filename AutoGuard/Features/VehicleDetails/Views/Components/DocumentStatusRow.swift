//
//  DocumentStatusRow.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import SwiftData
import SwiftUI

struct DocumentStatusRow: View {
    let doc: VehicleDocument
    let onRenewTap: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: doc.type.iconName)
                .font(.title2)
                .foregroundStyle(doc.statusColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.type.titleKey).font(.headline)
                Text(doc.expirationDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("days_remaining \(doc.daysRemaining)")
                    .font(.caption.bold())
                    .foregroundStyle(doc.statusColor)
            }
            Spacer()  // Împinge butonul în capătul din dreapta și lățimea la 100%!
            Button("common.renew") {
                onRenewTap()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Vehicle.self,
        VehicleDocument.self,
        configurations: config
    )
    let sampleDoc = VehicleDocument(type: .rca, expirationDate: Date())

    DocumentStatusRow(doc: sampleDoc) {
        print("Reînnoiește apăsat")
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
    .modelContainer(container)
}
