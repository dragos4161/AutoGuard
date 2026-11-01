//
//  ServiceRecordRowView.swift
//  AutoGuard
//
//  Componentă de rând/card pentru o intrare de service din istoric.
//

import SwiftUI

struct ServiceRecordRowView: View {
    let record: ServiceRecord
    var onViewInvoice: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: record.category.iconName)
                    .font(.headline)
                    .foregroundStyle(record.category.color)
                    .frame(width: 28, height: 28)
                    .background(record.category.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(record.date, format: .dateTime.day().month().year())
                        Text("•")
                        Text(record.formattedMileage)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let formattedPrice = record.formattedPrice {
                    Text(formattedPrice)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }

            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            if record.hasInvoice {
                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Button {
                        onViewInvoice?()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.text.viewfinder")
                            Text("service.row.view_invoice")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if record.hasInvoice {
                Button {
                    onViewInvoice?()
                } label: {
                    Label("service.row.view_invoice", systemImage: "eye")
                }
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }
}
