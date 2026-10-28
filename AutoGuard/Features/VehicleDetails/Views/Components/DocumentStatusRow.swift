//
//  DocumentStatusRow.swift
//  AutoGuard
//
//  Created by Dragos Dima on 25.10.2026.
//

import SwiftData
import SwiftUI

struct DocumentStatusRow: View {
    let doc: VehicleDocument
    let onRenewTap: () -> Void
    var onEditDateTap: (() -> Void)? = nil
    var onViewAttachmentTap: (() -> Void)? = nil
    var onAttachFileTap: (() -> Void)? = nil
    var onAttachPhotoTap: (() -> Void)? = nil
    var onRemoveAttachmentTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: doc.type.iconName)
                    .font(.title2)
                    .foregroundStyle(doc.statusColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(doc.type.titleKey)
                        .font(.headline)

                    // Data expirării + buton rapid de corectare a datei
                    Button {
                        onEditDateTap?()
                    } label: {
                        HStack(spacing: 4) {
                            Text(doc.expirationDate, format: .dateTime.day().month().year())
                            Image(systemName: "pencil")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if doc.isExpired {
                        Text("doc.status.expired")
                            .font(.caption.bold())
                            .foregroundStyle(doc.statusColor)
                    } else if doc.daysRemaining == 0 {
                        Text("doc.status.expires_today")
                            .font(.caption.bold())
                            .foregroundStyle(doc.statusColor)
                    } else {
                        Text("days_remaining \(doc.daysRemaining)")
                            .font(.caption.bold())
                            .foregroundStyle(doc.statusColor)
                    }
                }

                Spacer()

                Button("common.renew") {
                    onRenewTap()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()

            // Bara de jos pentru documentul digital atașat (PDF / Poză)
            HStack {
                if doc.hasAttachment {
                    Button {
                        onViewAttachmentTap?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.viewfinder.fill")
                                .foregroundStyle(.blue)
                            Text(doc.attachmentFileName ?? String(localized: "doc.attach.view"))
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Menu {
                        Button {
                            onViewAttachmentTap?()
                        } label: {
                            Label("doc.attach.view", systemImage: "eye")
                        }

                        Button {
                            onAttachFileTap?()
                        } label: {
                            Label("doc.attach.replace_pdf", systemImage: "doc.badge.plus")
                        }

                        Button {
                            onAttachPhotoTap?()
                        } label: {
                            Label("doc.attach.replace_photo", systemImage: "photo.badge.plus")
                        }

                        Divider()

                        Button(role: .destructive) {
                            onRemoveAttachmentTap?()
                        } label: {
                            Label("doc.attach.remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
                } else {
                    Menu {
                        Button {
                            onAttachFileTap?()
                        } label: {
                            Label("doc.attach.pdf", systemImage: "doc.fill")
                        }

                        Button {
                            onAttachPhotoTap?()
                        } label: {
                            Label("doc.attach.photo", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paperclip")
                            Text("doc.attach.add_prompt")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if doc.hasAttachment {
                Button {
                    onViewAttachmentTap?()
                } label: {
                    Label("doc.attach.view", systemImage: "eye")
                }
            } else {
                Button {
                    onAttachFileTap?()
                } label: {
                    Label("doc.attach.pdf", systemImage: "doc.fill")
                }
                Button {
                    onAttachPhotoTap?()
                } label: {
                    Label("doc.attach.photo", systemImage: "photo.on.rectangle")
                }
            }

            if let onEditDateTap {
                Button {
                    onEditDateTap()
                } label: {
                    Label("doc.action.correct_date", systemImage: "calendar")
                }
            }

            Button {
                onRenewTap()
            } label: {
                Label("common.renew", systemImage: "arrow.triangle.2.circlepath")
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
    let sampleDoc = VehicleDocument(type: .rca, expirationDate: Date())

    DocumentStatusRow(doc: sampleDoc) {
        print("Reînnoiește apăsat")
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
    .modelContainer(container)
}
