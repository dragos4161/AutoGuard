//
//  WalletRcaCard.swift
//  AutoGuard
//
//  Afișare dedicată a poliței RCA în Portofelul Digital de Acte.
//  Include baza legală (Norma ASF 20/2017) și butonul de verificare în baza oficială AIDA.
//

import QuickLook
import SwiftUI

struct WalletRcaCard: View {
    let vehicle: Vehicle
    let rcaDoc: VehicleDocument?
    @ObservedObject var viewModel: WalletViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Card Principal RCA
            VStack(alignment: .leading, spacing: 14) {
                // Header cu Badge Valabilitate
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.headline)
                                .foregroundStyle(.blue)
                            Text("wallet.rca.card_title")
                                .font(.headline.bold())
                        }

                        if let doc = rcaDoc, !doc.provider.isEmpty {
                            Text(doc.provider)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("wallet.rca.default_title")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Badge de Stare
                    if let doc = rcaDoc {
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

                // Date esențiale poliță
                if let doc = rcaDoc {
                    VStack(spacing: 10) {
                        infoRow(
                            label: "wallet.rca.policy_number",
                            value: doc.policyNumber.isEmpty ? "—" : doc.policyNumber,
                            isMonospaced: true
                        )

                        infoRow(
                            label: "wallet.rca.valid_until",
                            value: doc.expirationDate.formatted(date: .long, time: .omitted),
                            isMonospaced: false
                        )

                        infoRow(
                            label: "wallet.rca.days_left",
                            value: daysLeftDescription(for: doc),
                            valueColor: doc.statusColor
                        )
                    }

                    // Buton Vizualizare Atașament Poliță (PDF sau Poză)
                    if doc.hasAttachment {
                        Button {
                            viewModel.openAttachment(for: doc)
                        } label: {
                            HStack {
                                Image(systemName: doc.attachmentFileName?.lowercased().hasSuffix(".pdf") == true ? "doc.fill" : "photo.fill")
                                    .foregroundStyle(.blue)
                                Text("wallet.rca.view_attached_doc")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("wallet.rca.not_configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)

            // Notă Legală Oficială pentru Poliția Rutieră
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("wallet.legal.basis.title")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text("wallet.legal.basis.rca_description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Buton Verificare Oficială AIDA (BAAR)
            Button {
                viewModel.openAidaVerification()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe.europe.africa.fill")
                    Text("wallet.rca.verify_aida_button")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func infoRow(
        label: LocalizedStringKey,
        value: String,
        isMonospaced: Bool = false,
        valueColor: Color = .primary
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(.subheadline, design: .monospaced, weight: .bold) : .subheadline.bold())
                .foregroundStyle(valueColor)
        }
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
