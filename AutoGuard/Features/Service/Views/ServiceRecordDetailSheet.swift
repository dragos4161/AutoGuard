//
//  ServiceRecordDetailSheet.swift
//  AutoGuard
//
//  Sheet de detaliu complet pentru o intrare în service / revizie.
//  Permite vizualizarea integrală a operațiunilor și pieselor folosite,
//  a facturii/devizului atașat (QuickLook) și a costului.
//

import QuickLook
import SwiftData
import SwiftUI

struct ServiceRecordDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let record: ServiceRecord
    var onDelete: (() -> Void)? = nil

    @State private var invoicePreviewURL: URL? = nil
    @State private var isNotesCopied: Bool = false
    @State private var isShowingDeleteAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Secțiunea 1: Card Rezumat Principal
                    summaryCard

                    // Secțiunea 2: Vehicul Asociat
                    if let vehicle = record.vehicle {
                        vehicleCard(vehicle)
                    }

                    // Secțiunea 3: Operațiuni și Piese folosite
                    operationsAndPartsCard

                    // Secțiunea 4: Factură / Bon / Deviz atașat
                    invoiceAttachmentCard

                    // Secțiunea 5: Buton Ștergere
                    deleteButtonSection
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("service.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .quickLookPreview($invoicePreviewURL)
            .alert("service.detail.delete_confirm_title", isPresented: $isShowingDeleteAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("common.delete", role: .destructive) {
                    performDelete()
                }
            } message: {
                Text("service.detail.delete_confirm_message")
            }
        }
    }

    // MARK: - Card Rezumat
    @ViewBuilder
    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: record.category.iconName)
                    .font(.title2)
                    .foregroundStyle(record.category.color)
                    .frame(width: 44, height: 44)
                    .background(record.category.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)

                    Text(record.category.titleKey)
                        .font(.caption.bold())
                        .foregroundStyle(record.category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(record.category.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                if let formattedPrice = record.formattedPrice {
                    Text(formattedPrice)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("service.detail.date_label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(record.date, format: .dateTime.day().month().year())
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("service.detail.mileage_label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(record.formattedMileage)
                        .font(.subheadline.bold())
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Card Vehicul
    @ViewBuilder
    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(vehicle.plateNumber)
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let currentMileage = vehicle.currentMileage {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("service.detail.current_odometer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(currentMileage.formatted()) km")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Card Operațiuni & Piese Folosite
    @ViewBuilder
    private var operationsAndPartsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("service.add.notes_label")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                if let notes = record.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        UIPasteboard.general.string = notes
                        isNotesCopied = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isNotesCopied = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isNotesCopied ? "checkmark" : "doc.on.doc")
                            Text(isNotesCopied ? "common.copied" : "common.copy")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(isNotesCopied ? .green : .blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            if let notes = record.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("service.detail.no_notes_placeholder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Card Factură / Bon
    @ViewBuilder
    private var invoiceAttachmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("service.detail.invoice_section_title")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()

                if record.hasInvoice {
                    Text("service.detail.invoice_attached_badge")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Divider()

            if record.hasInvoice, let data = record.invoiceData {
                let fileName = record.invoiceFileName ?? "Factura_\(record.title).pdf"
                let isPDF = fileName.lowercased().hasSuffix(".pdf")
                let sizeKb = Double(data.count) / 1024.0

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: isPDF ? "doc.richtext.fill" : "photo.fill")
                            .font(.title2)
                            .foregroundStyle(isPDF ? .red : .blue)
                            .frame(width: 40, height: 40)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Text(String(format: "%.1f KB", sizeKb))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Button {
                            openInvoice()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                Text("service.row.view_invoice")
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        if let tempURL = prepareTempInvoiceURL() {
                            ShareLink(item: tempURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.blue)
                                    .frame(width: 44, height: 40)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("service.detail.no_invoice_attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Secțiune Ștergere
    @ViewBuilder
    private var deleteButtonSection: some View {
        Button(role: .destructive) {
            isShowingDeleteAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("service.detail.delete_record_button")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Helperi Factură & Ștergere
    private func prepareTempInvoiceURL() -> URL? {
        guard let data = record.invoiceData else { return nil }
        let fileName = record.invoiceFileName ?? "Factura_\(record.title).pdf"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(record.id.uuidString)_\(fileName)")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try? data.write(to: tempURL, options: .atomic)
        }
        return tempURL
    }

    private func openInvoice() {
        if let url = prepareTempInvoiceURL() {
            invoicePreviewURL = url
        }
    }

    private func performDelete() {
        onDelete?()
        modelContext.delete(record)
        try? modelContext.save()
        dismiss()
    }
}
