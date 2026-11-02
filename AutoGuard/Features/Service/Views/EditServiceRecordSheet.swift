//
//  EditServiceRecordSheet.swift
//  AutoGuard
//
//  Formular pentru editarea unei intrări existente de service / revizie.
//  Permite modificarea titlului, categoriei, datei, kilometrajului, costului,
//  a operațiunilor și pieselor folosite, precum și atașarea/modificarea facturii.
//

import PhotosUI
import SwiftData
import SwiftUI

struct EditServiceRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var record: ServiceRecord

    @State private var title: String
    @State private var category: ServiceCategory
    @State private var date: Date
    @State private var mileageText: String
    @State private var priceText: String
    @State private var notes: String

    // Atașament factură / bon
    @State private var invoiceData: Data?
    @State private var invoiceFileName: String?
    @State private var isShowingFileImporter: Bool = false
    @State private var isShowingPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init(record: ServiceRecord) {
        self.record = record
        _title = State(initialValue: record.title)
        _category = State(initialValue: record.category)
        _date = State(initialValue: record.date)
        _mileageText = State(initialValue: "\(record.mileage)")
        _priceText = State(initialValue: record.price != nil ? String(format: "%.2f", record.price!) : "")
        _notes = State(initialValue: record.notes ?? "")
        _invoiceData = State(initialValue: record.invoiceData)
        _invoiceFileName = State(initialValue: record.invoiceFileName)
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
                            Label(cat.titleKey, systemImage: cat.iconName)
                                .tag(cat)
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
                            .frame(minHeight: 120)
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

                                Divider()

                                Button(role: .destructive) {
                                    invoiceData = nil
                                    self.invoiceFileName = nil
                                } label: {
                                    Label("service.detail.remove_invoice", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
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
            .navigationTitle("service.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.bold)
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

    private func saveChanges() {
        guard let mileage = parsedMileage else { return }

        // Feedback haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.category = category
        record.date = date
        record.mileage = mileage
        record.price = parsedPrice

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = trimmedNotes.isEmpty ? nil : notes

        record.invoiceData = invoiceData
        record.invoiceFileName = invoiceFileName

        if let vehicle = record.vehicle {
            if mileage > (vehicle.currentMileage ?? 0) {
                let repo = SwiftDataVehicleRepository()
                _ = repo.addMileageEntry(
                    mileage,
                    date: date,
                    note: "Service: \(record.title)",
                    for: vehicle,
                    in: modelContext
                )
            }
            NotificationManager.shared.scheduleMaintenanceReminder(for: vehicle)
            WidgetDataManager.shared.updateWidgetData(for: vehicle)
        }

        try? modelContext.save()
        dismiss()
    }
}
