//
//  VehicleExportSheet.swift
//  AutoGuard
//
//  Dialog unificat de export pentru Dosarul Vehiculului:
//  1. Carte de Service Digitală (PDF A4 nativ)
//  2. Raport Tabelar Cheltuieli & Revizii (CSV / Excel)
//

import SwiftUI

struct VehicleExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle

    @State private var pdfURL: URL? = nil
    @State private var csvURL: URL? = nil
    @State private var isShowingPdfPreview: Bool = false
    @State private var isGenerating: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Vehicul
                    vehicleHeaderCard

                    // Opțiunea 1: Carte de Service PDF
                    pdfExportCard

                    // Opțiunea 2: Export Tabelar CSV / Excel
                    csvExportCard

                    // Notă de Confidențialitate & Securitate
                    privacyNoteCard
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("report.export.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateFiles()
            }
            .sheet(isPresented: $isShowingPdfPreview) {
                if let url = pdfURL {
                    ReportPreviewSheet(vehicle: vehicle, pdfURL: url)
                }
            }
        }
    }

    // MARK: - Header Vehicul
    private var vehicleHeaderCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline.bold())
                Text(vehicle.plateNumber)
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let km = vehicle.formattedMileage {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("report.export.odometer_label")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(km)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Card Export PDF
    private var pdfExportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.richtext.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("report.export.pdf_title")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("report.export.pdf_subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("report.export.pdf_description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 12) {
                Button {
                    isShowingPdfPreview = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("report.export.preview_pdf")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(pdfURL == nil)

                if let url = pdfURL {
                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("report.button.share")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Card Export CSV
    private var csvExportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.gradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "tablecells.badge.ellipsis")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("report.export.csv_title")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("report.export.csv_subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("report.export.csv_description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            if let url = csvURL {
                ShareLink(item: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("report.export.share_csv")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Notă de Confidențialitate
    private var privacyNoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("report.export.privacy_note")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Generare Fișiere Locale
    private func generateFiles() {
        Task {
            let pdf = VehicleReportGenerator.shared.generatePdf(for: vehicle)
            let csv = VehicleExportService.shared.generateExpensesCsv(for: vehicle)
            await MainActor.run {
                self.pdfURL = pdf
                self.csvURL = csv
            }
        }
    }
}
