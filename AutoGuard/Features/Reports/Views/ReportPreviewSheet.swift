//
//  ReportPreviewSheet.swift
//  AutoGuard
//
//  Previzualizator nativ pentru raportul "Carte de Service" cu opțiuni de partajare și printare.
//

import PDFKit
import SwiftUI

struct ReportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    let pdfURL: URL

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFKitRepresentedView(url: pdfURL)
                    .background(Color(uiColor: .systemGroupedBackground))

                // Bară inferioară cu buton de partajare
                VStack(spacing: 12) {
                    Divider()

                    ShareLink(item: pdfURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("report.button.share")
                                .font(.headline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
