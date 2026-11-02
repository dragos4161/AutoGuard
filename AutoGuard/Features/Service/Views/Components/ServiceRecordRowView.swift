//
//  ServiceRecordRowView.swift
//  AutoGuard
//
//  Componentă de rând/card pentru o intrare de service din istoric.
//  Permite apăsarea pe card pentru a deschide detaliile complete ale reviziei
//  (operațiuni, piese, deviz, factură).
//

import SwiftUI

struct ServiceRecordRowView: View {
    let record: ServiceRecord
    var onViewInvoice: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isShowingDetailSheet: Bool = false

    var body: some View {
        Button {
            isShowingDetailSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: record.category.iconName)
                        .font(.headline)
                        .foregroundStyle(record.category.color)
                        .frame(width: 30, height: 30)
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

                    VStack(alignment: .trailing, spacing: 3) {
                        if let formattedPrice = record.formattedPrice {
                            Text(formattedPrice)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let notes = record.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if notes.count > 60 || notes.contains("\n") {
                            Text("service.row.view_full_notes")
                                .font(.caption2.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.top, 2)
                }

                if record.hasInvoice {
                    Divider()
                        .padding(.vertical, 2)

                    HStack {
                        Button {
                            if let onViewInvoice {
                                onViewInvoice()
                            } else {
                                isShowingDetailSheet = true
                            }
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
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                isShowingDetailSheet = true
            } label: {
                Label("service.row.view_details", systemImage: "info.circle")
            }

            if record.hasInvoice {
                Button {
                    if let onViewInvoice {
                        onViewInvoice()
                    } else {
                        isShowingDetailSheet = true
                    }
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
        .sheet(isPresented: $isShowingDetailSheet) {
            ServiceRecordDetailSheet(
                record: record,
                onDelete: onDelete
            )
        }
    }
}
