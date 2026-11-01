//
//  AddServiceRecordSheet.swift
//  AutoGuard
//
//  Formular complet pentru înregistrarea unei intrări în service / revizie auto.
//

import PhotosUI
import SwiftData
import SwiftUI

struct AddServiceRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vehicle: Vehicle

    @State private var title: String = ""
    @State private var category: ServiceCategory = .oilAndFilters
    @State private var date: Date = Date()
    @State private var mileageText: String = ""
    @State private var priceText: String = ""
    @State private var notes: String = ""

    // Atașament factură / bon
    @State private var invoiceData: Data? = nil
    @State private var invoiceFileName: String? = nil
    @State private var isShowingFileImporter: Bool = false
    @State private var isShowingPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private let repository: VehicleRepositoryProtocol

    init(
        vehicle: Vehicle,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.repository = repository
    }

    private var parsedMileage: Int? {
        let clean = mileageText.filter { $0.isNumber }
        return Int(clean)
    }

    private var parsedPrice: Double? {
        let clean = priceText.replacingOccurrences(of: ",", with: ".")
        return Double(clean)
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && parsedMileage != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Detalii Principale
                Section("service.add.section.details") {
                    Picker("service.add.category", selection: $category) {
                        ForEach(ServiceCategory.allCases) { cat in
                            Label(cat.localizedTitle, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newCat in
                        if title.isEmpty || ServiceCategory.allCases.contains(where: { $0.localizedTitle == title }) {
                            title = newCat.localizedTitle
                        }
                    }

                    TextField("service.add.title_placeholder", text: $title)

                    DatePicker("service.add.date", selection: $date, displayedComponents: .date)

                    HStack {
                        Text("service.add.mileage")
                        Spacer()
                        TextField("service.add.mileage_placeholder", text: $mileageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                }

                // Secțiunea 2: Cost & Operațiuni Efectuate
                Section("service.add.section.cost_and_notes") {
                    HStack {
                        Text("service.add.price")
                        Spacer()
                        TextField("service.add.price_placeholder", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("RON")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("service.add.notes_label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }

                // Secțiunea 3: Factură / Bon Fiscal
                Section("service.add.section.invoice") {
                    if let invoiceFileName {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                            Text(invoiceFileName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                invoiceData = nil
                                self.invoiceFileName = nil
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Menu {
                            Button {
                                isShowingFileImporter = true
                            } label: {
                                Label("doc.attach.pdf", systemImage: "doc.fill")
                            }

                            Button {
                                isShowingPhotoPicker = true
                            } label: {
                                Label("doc.attach.photo", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "paperclip")
                                Text("service.add.attach_invoice_prompt")
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("service.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        saveRecord()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if title.isEmpty {
                    title = category.localizedTitle
                }
                if let km = vehicle.currentMileage {
                    mileageText = "\(km)"
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleImportedFile(result: result)
            }
            .photosPicker(
                isPresented: $isShowingPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        invoiceData = data
                        invoiceFileName = "Factura_\(category.rawValue).jpg"
                    }
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private func handleImportedFile(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileURL = urls.first else { return }
        let canAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess { fileURL.stopAccessingSecurityScopedResource() }
        }

        if let data = try? Data(contentsOf: fileURL) {
            invoiceData = data
            invoiceFileName = fileURL.lastPathComponent
        }
    }

    private func saveRecord() {
        guard let mileage = parsedMileage else { return }

        // Feedback haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        _ = repository.addServiceRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            date: date,
            mileage: mileage,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            price: parsedPrice,
            invoiceData: invoiceData,
            invoiceFileName: invoiceFileName,
            for: vehicle,
            in: modelContext
        )

        // Actualizăm notificarea de revizie
        NotificationManager.shared.scheduleMaintenanceReminder(for: vehicle)

        dismiss()
    }
}
