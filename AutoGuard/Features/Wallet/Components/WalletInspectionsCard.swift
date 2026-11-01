//
//  WalletInspectionsCard.swift
//  AutoGuard
//
//  Afișare dedicată a ITP-ului, Rovinietei și Trusei/Stingătorului în Portofelul Digital.
//  Include butoane rapide de interogare în bazele oficiale RAROM și CNAIR.
//

import SwiftUI

struct WalletInspectionsCard: View {
    let vehicle: Vehicle
    @ObservedObject var viewModel: WalletViewModel

    var itpDoc: VehicleDocument? { vehicle.document(for: .itp) }
    var rovinietaDoc: VehicleDocument? { vehicle.document(for: .rovinieta) }
    var extinguisherDoc: VehicleDocument? { vehicle.document(for: .extinguisher) }

    var body: some View {
        VStack(spacing: 16) {
            // Card ITP
            inspectionSectionCard(
                title: "doc.type.itp",
                icon: "checkmark.seal.fill",
                doc: itpDoc,
                verifyButtonTitle: "wallet.itp.verify_rarom",
                onVerify: { viewModel.openRaromVerification() }
            )

            // Card Rovinietă
            inspectionSectionCard(
                title: "doc.type.rovinieta",
                icon: "road.lanes",
                doc: rovinietaDoc,
                verifyButtonTitle: "wallet.rovinieta.verify_cnair",
                onVerify: { viewModel.openCnairVerification() }
            )

            // Card Trusă & Stingător
            if let ext = extinguisherDoc {
                simpleStatusCard(
                    title: "doc.type.extinguisher",
                    icon: "cross.case.fill",
                    doc: ext
                )
            }
        }
    }

    private func inspectionSectionCard(
        title: LocalizedStringKey,
        icon: String,
        doc: VehicleDocument?,
        verifyButtonTitle: LocalizedStringKey,
        onVerify: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text(title)
                        .font(.headline.bold())
                }

                Spacer()

                if let doc {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(doc.statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText(for: doc))
                            .font(.caption.bold())
                            .foregroundStyle(doc.statusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(doc.statusColor.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    Text("wallet.doc.missing")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Divider()

            if let doc {
                VStack(spacing: 8) {
                    HStack {
                        Text("wallet.rca.valid_until")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(doc.expirationDate.formatted(date: .long, time: .omitted))
                            .font(.subheadline.bold())
                    }

                    HStack {
                        Text("wallet.rca.days_left")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(daysLeftDescription(for: doc))
                            .font(.subheadline.bold())
                            .foregroundStyle(doc.statusColor)
                    }
                }
            }

            // Buton Verificare Oficială
            Button(action: onVerify) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text(verifyButtonTitle)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func simpleStatusCard(
        title: LocalizedStringKey,
        icon: String,
        doc: VehicleDocument
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text("Expiră: \(doc.expirationDate.formatted(date: .abbreviated, time: .omitted)) (\(doc.daysRemaining) zile)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(doc.statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusText(for doc: VehicleDocument) -> LocalizedStringKey {
        if doc.isExpired {
            return "wallet.status.expired"
        } else if doc.isExpiringSoon {
            return "wallet.status.expiring_soon"
        } else {
            return "wallet.status.valid"
        }
    }

    private func daysLeftDescription(for doc: VehicleDocument) -> String {
        if doc.daysRemaining < 0 {
            return "\(abs(doc.daysRemaining)) zile depășite"
        } else if doc.daysRemaining == 0 {
            return "Expiră astăzi"
        } else {
            return "\(doc.daysRemaining) zile rămase"
        }
    }
}
