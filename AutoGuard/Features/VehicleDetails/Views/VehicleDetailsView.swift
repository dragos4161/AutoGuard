//
//  VehicleDetailsView.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import PhotosUI
import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VehicleDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var vehicle: Vehicle
    @State private var viewModel = VehicleDetailsViewModel()
    @State private var isShowingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // --------------------------------------------------
                // SECȚIUNEA 1: Informații Mașină
                // --------------------------------------------------
                VStack(alignment: .leading, spacing: 8) {
                    Text("vehicle_details.section.info")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    VehicleInfoCard(vehicle: vehicle)
                }

                // --------------------------------------------------
                // SECȚIUNEA 2: Documente și Expirări
                // --------------------------------------------------
                VStack(alignment: .leading, spacing: 8) {
                    Text("vehicle_details.section.documents")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.sortDocuments(for: vehicle)) { doc in
                            DocumentStatusRow(
                                doc: doc,
                                onRenewTap: {
                                    viewModel.prepareRenewal(for: doc)
                                },
                                onEditDateTap: {
                                    viewModel.prepareDateCorrection(for: doc)
                                },
                                onViewAttachmentTap: {
                                    viewModel.openAttachment(for: doc)
                                },
                                onAttachFileTap: {
                                    viewModel.triggerFileImport(for: doc)
                                },
                                onAttachPhotoTap: {
                                    viewModel.triggerPhotoPicker(for: doc)
                                },
                                onRemoveAttachmentTap: {
                                    viewModel.removeAttachment(for: doc, in: modelContext)
                                }
                            )
                        }
                    }
                }

                // --------------------------------------------------
                // SECȚIUNEA 3: Istoric Documente (Arhivate la reînnoire)
                // --------------------------------------------------
                if !vehicle.archivedDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("vehicle_details.section.history")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        LazyVStack(spacing: 10) {
                            ForEach(vehicle.archivedDocuments) { archivedDoc in
                                archivedDocumentRow(for: archivedDoc)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(vehicle.plateNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.edit") {
                    isShowingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            EditVehicleView(vehicle: vehicle)
        }
        // Modal 1: Corectarea datei curente (fără istoric)
        .sheet(isPresented: $viewModel.isShowingCorrectionSheet) {
            dateCorrectionSheet
                .presentationDetents([.medium])
        }
        // Modal 2: Reînnoire document (mută vechiul în istoric + creează unul nou)
        .sheet(isPresented: $viewModel.isShowingRenewalSheet) {
            renewalSheet
                .presentationDetents([.medium])
        }
        // Selector nativ de fișiere (PDF / Imagini din Files / iCloud Drive)
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImportedFile(result: result, in: modelContext)
        }
        // Selector nativ din Galeria Foto
        .photosPicker(
            isPresented: $viewModel.isShowingPhotoPicker,
            selection: $viewModel.selectedPhotoItem,
            matching: .images
        )
        .onChange(of: viewModel.selectedPhotoItem) { _, newValue in
            guard newValue != nil else { return }
            Task {
                await viewModel.handleSelectedPhoto(in: modelContext)
            }
        }
        // Vizualizator nativ iOS QuickLook (cu Zoom, Share, AirDrop, Print)
        .quickLookPreview($viewModel.previewURL)
    }

    // MARK: - Rând pentru un document din Istoric
    @ViewBuilder
    private func archivedDocumentRow(for doc: VehicleDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: doc.type.iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.type.titleKey)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text("doc.history.expired_on")
                    Text(doc.expirationDate, format: .dateTime.day().month().year())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if doc.hasAttachment {
                Button {
                    viewModel.openAttachment(for: doc)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.viewfinder.fill")
                        Text("doc.attach.view_short")
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("doc.status.archived")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if doc.hasAttachment {
                Button {
                    viewModel.openAttachment(for: doc)
                } label: {
                    Label("doc.attach.view", systemImage: "eye")
                }
            } else {
                Button {
                    viewModel.triggerFileImport(for: doc)
                } label: {
                    Label("doc.attach.pdf", systemImage: "doc.fill")
                }
                Button {
                    viewModel.triggerPhotoPicker(for: doc)
                } label: {
                    Label("doc.attach.photo", systemImage: "photo.on.rectangle")
                }
            }

            Button(role: .destructive) {
                viewModel.deleteArchivedDocument(doc, in: modelContext)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Sheet pentru Corectarea unei Date Greșite
    @ViewBuilder
    private var dateCorrectionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if let doc = viewModel.selectedDocument {
                        HStack {
                            Image(systemName: doc.type.iconName)
                                .foregroundStyle(.blue)
                            Text(doc.type.titleKey)
                                .font(.headline)
                        }
                    }

                    DatePicker(
                        "doc.correction.new_date",
                        selection: $viewModel.correctionDate,
                        displayedComponents: .date
                    )
                } footer: {
                    Text("doc.correction.footer")
                }
            }
            .navigationTitle("doc.correction.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        viewModel.isShowingCorrectionSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        viewModel.confirmDateCorrection(in: modelContext)
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - Sheet pentru Reînnoire (Păstrează vechiul în Istoric)
    @ViewBuilder
    private var renewalSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if let doc = viewModel.selectedDocument {
                        HStack {
                            Image(systemName: doc.type.iconName)
                                .foregroundStyle(.green)
                            Text(doc.type.titleKey)
                                .font(.headline)
                        }
                    }

                    DatePicker(
                        "doc.renewal.new_date",
                        selection: $viewModel.renewalDate,
                        displayedComponents: .date
                    )
                } footer: {
                    Text("doc.renewal.footer")
                }
            }
            .navigationTitle("doc.renewal.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        viewModel.isShowingRenewalSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.renew") {
                        viewModel.confirmRenewal(in: modelContext)
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Vehicle.self,
        VehicleDocument.self,
        configurations: config
    )
    let sampleVehicle = Vehicle(
        plateNumber: "B 123 ABC",
        make: "Dacia",
        model: "Duster",
        year: 2023,
        vin: "VF1HJD20668912345",
        nickname: "Mașina familiei"
    )
    let rca = VehicleDocument(type: .rca, expirationDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!)
    let itp = VehicleDocument(type: .itp, expirationDate: Calendar.current.date(byAdding: .day, value: 120, to: Date())!)
    sampleVehicle.documents = [rca, itp]

    return NavigationStack {
        VehicleDetailsView(vehicle: sampleVehicle)
    }
    .modelContainer(container)
}
