//
//  MileageSheet.swift
//  AutoGuard
//
//  Sheet nativ pentru actualizarea rapidă a kilometrajului și vizualizarea istoricului odometrului.
//

import SwiftData
import SwiftUI

struct MileageSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vehicle: Vehicle

    @State private var inputMileageText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var inputNote: String = ""
    @State private var hasSavedFeedback: Bool = false
    @FocusState private var isFieldFocused: Bool

    private let repository: VehicleRepositoryProtocol

    init(
        vehicle: Vehicle,
        repository: VehicleRepositoryProtocol = SwiftDataVehicleRepository()
    ) {
        self.vehicle = vehicle
        self.repository = repository
    }

    private var currentRecordedMileage: Int? {
        vehicle.currentMileage
    }

    private var parsedInputMileage: Int? {
        let clean = inputMileageText.filter { $0.isNumber }
        return Int(clean)
    }

    private var isLowerThanPrevious: Bool {
        guard let entered = parsedInputMileage, let current = currentRecordedMileage else {
            return false
        }
        return entered < current
    }

    var body: some View {
        NavigationStack {
            List {
                // Secțiunea 1: Actualizare rapidă odometru
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("mileage.input.label")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let current = currentRecordedMileage {
                                Text("mileage.current \(current)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            TextField("mileage.input.placeholder", text: $inputMileageText)
                                .keyboardType(.numberPad)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .focused($isFieldFocused)
                                .onChange(of: inputMileageText) { _, newValue in
                                    // Păstrăm doar cifre
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        inputMileageText = filtered
                                    }
                                }

                            Text("km")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if isLowerThanPrevious {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("mileage.warning.lower")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        DatePicker(
                            "mileage.date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .font(.subheadline)

                        Button {
                            saveMileageEntry()
                        } label: {
                            HStack {
                                Spacer()
                                if hasSavedFeedback {
                                    Label("mileage.saved", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                } else {
                                    Text("mileage.save_button")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                parsedInputMileage != nil
                                    ? (hasSavedFeedback ? Color.green : Color.blue)
                                    : Color.gray.opacity(0.4)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(parsedInputMileage == nil)
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("mileage.section.add")
                }

                // Secțiunea 2: Istoricul înregistrărilor
                Section {
                    let entries = vehicle.sortedMileageEntries
                    if entries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "road.lanes")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text("mileage.history.empty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            mileageRow(entry: entry, previousEntry: (index + 1 < entries.count) ? entries[index + 1] : nil)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                } header: {
                    Text("mileage.section.history")
                } footer: {
                    if !vehicle.sortedMileageEntries.isEmpty {
                        Text("mileage.history.footer")
                    }
                }
            }
            .navigationTitle("mileage.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let current = currentRecordedMileage {
                    inputMileageText = "\(current)"
                }
            }
        }
    }

    @ViewBuilder
    private func mileageRow(entry: MileageEntry, previousEntry: MileageEntry?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.formattedMileage)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(entry.date, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Badge diferență față de înregistrarea anterioară
            if let previous = previousEntry {
                let diff = entry.mileage - previous.mileage
                if diff != 0 {
                    let isPositive = diff > 0
                    Text("\(isPositive ? "+" : "")\(diff) km")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isPositive ? Color.blue : Color.orange).opacity(0.12))
                        .foregroundStyle(isPositive ? Color.blue : Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func saveMileageEntry() {
        guard let mileage = parsedInputMileage else { return }

        // Feedback haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        _ = repository.addMileageEntry(
            mileage,
            date: selectedDate,
            note: inputNote.isEmpty ? nil : inputNote,
            for: vehicle,
            in: modelContext
        )

        withAnimation(.spring) {
            hasSavedFeedback = true
        }

        // Închide tastatura
        isFieldFocused = false

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.spring) {
                hasSavedFeedback = false
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let entries = vehicle.sortedMileageEntries
        for index in offsets {
            let entry = entries[index]
            repository.deleteMileageEntry(entry, in: modelContext)
        }
    }
}

#Preview {
    let sampleVehicle = Vehicle(
        plateNumber: "B 123 ABC",
        make: "Dacia",
        model: "Duster"
    )
    let entry1 = MileageEntry(mileage: 145000, date: Date())
    let entry2 = MileageEntry(mileage: 141200, date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!)
    sampleVehicle.mileageEntries = [entry1, entry2]

    return MileageSheet(vehicle: sampleVehicle)
}
