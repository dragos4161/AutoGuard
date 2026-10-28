//
//  VehicleInfoCardView.swift
//  AutoGuard
//
//  Created by Dragos Dima on 27.10.2026.
//

import SwiftData
import SwiftUI

struct VehicleInfoCard: View {
    let vehicle: Vehicle
    @State private var hasCopiedVin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    if !vehicle.nickname.isEmpty {
                        Text(vehicle.nickname)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(String(vehicle.year))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("vin.title")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if vehicle.vin.isEmpty {
                        Text("vin.empty")  // Se va traduce automat!
                            .foregroundStyle(.secondary)
                    } else {
                        Text(vehicle.vin)
                            .font(
                                .system(
                                    .subheadline,
                                    design: .monospaced,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
                if !vehicle.vin.isEmpty {
                    Button {
                        copyVinToClipboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(
                                systemName: hasCopiedVin
                                    ? "checkmark" : "doc.on.doc"
                            )
                            .font(.caption.bold())
                            if hasCopiedVin {
                                Text("text.copy")
                                    .font(.caption2.bold())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            hasCopiedVin
                                ? Color.green.opacity(0.15)
                                : Color(uiColor: .tertiarySystemFill)
                        )
                        .foregroundStyle(
                            hasCopiedVin ? Color.green : Color.primary
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func copyVinToClipboard() {
        UIPasteboard.general.string = vehicle.vin

        // Feedback haptic nativ (vibrație scurtă de succes)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Schimbăm iconița cu animație
        withAnimation(.spring) {
            hasCopiedVin = true
        }

        // După 2 secunde revenim la starea inițială
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring) {
                hasCopiedVin = false
            }
        }
    }
}

#Preview {
    let sampleVehicle = Vehicle(
        plateNumber: "B 123 ABC",
        make: "Dacia",
        model: "Duster",
        year: 2023,
        vin: "VF1HJD20668912345",
        nickname: "Mașina familiei"
    )
    return VehicleInfoCard(vehicle: sampleVehicle)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
