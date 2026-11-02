//
//  AccountSyncSettingsView.swift
//  AutoGuard
//
//  Ecran dedicat pentru gestionarea contului Apple ID, a salvărilor în Cloud (Firebase / iCloud)
//  și a fișierelor de siguranță portabile.
//

import SwiftUI
import SwiftData
import AuthenticationServices
import UniformTypeIdentifiers

struct AccountSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var authService = AppleAuthService.shared
    @State private var backupManager = CloudBackupManager.shared
    @State private var syncManager = FirebaseSyncManager.shared

    @State private var showingExportShareSheet: Bool = false
    @State private var exportedFileURL: URL?
    @State private var showingFileImporter: Bool = false
    @State private var showingRestoreConfirmation: Bool = false
    @State private var showingSignOutAlert: Bool = false
    @State private var showingDeleteAccountAlert: Bool = false
    @State private var alertMessage: String?
    @State private var showingAlertMessage: Bool = false

    var body: some View {
        Form {
            // MARK: - Secțiunea 1: Profil / Autentificare
            Section {
                if let user = authService.currentUser {
                    signedInUserCard(user: user)
                } else {
                    signedOutCard
                }
            } header: {
                Text("settings.account.section_title")
            } footer: {
                if authService.currentUser == nil {
                    Text("settings.account.privacy_footer")
                }
            }

            // MARK: - Secțiunea 2: Sincronizare Cloud & Backup
            if authService.currentUser != nil {
                Section("settings.account.cloud_sync_title") {
                    // Buton Fă Backup Acum
                    Button {
                        triggerCloudBackup()
                    } label: {
                        HStack {
                            Label("settings.account.backup_now", systemImage: "arrow.clockwise.icloud.fill")
                                .foregroundStyle(.blue)
                            Spacer()
                            if syncManager.status == .syncing {
                                ProgressView()
                                    .scaleEffect(0.9)
                            }
                        }
                    }
                    .disabled(syncManager.status == .syncing)

                    // Buton Restaurează din Cloud
                    Button {
                        showingRestoreConfirmation = true
                    } label: {
                        Label("settings.account.restore_cloud", systemImage: "arrow.down.icloud.fill")
                            .foregroundStyle(.primary)
                    }
                    .disabled(syncManager.status == .syncing)

                    // Stare ultim backup
                    HStack {
                        Text("settings.account.last_backup")
                        Spacer()
                        if let lastDate = authService.currentUser?.lastBackupDate {
                            Text(lastDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("settings.account.never")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: - Secțiunea 3: Fișier portabil de siguranță (Offline / Import-Export)
            Section {
                Button {
                    exportLocalBackup()
                } label: {
                    Label("settings.account.export_backup", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.primary)
                }

                Button {
                    showingFileImporter = true
                } label: {
                    Label("settings.account.import_backup", systemImage: "square.and.arrow.down")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("settings.account.offline_backup_title")
            } footer: {
                Text("settings.account.offline_backup_footer")
            }

            // MARK: - Secțiunea 4: Deconectare & Ștergere Cont
            if authService.currentUser != nil {
                Section {
                    Button {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings.account.sign_out")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings.account.delete_account")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.account.title")
        .navigationBarTitleDisplayMode(.inline)
        // Partajare fișier exportat
        .sheet(isPresented: $showingExportShareSheet) {
            if let exportedFileURL {
                ShareSheetView(activityItems: [exportedFileURL])
            }
        }
        // Import fișier
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        // Confirmare restaurare
        .alert("settings.account.restore_confirm_title", isPresented: $showingRestoreConfirmation) {
            Button("settings.account.restore_action", role: .destructive) {
                triggerRestoreFromCloud()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.account.restore_confirm_message")
        }
        // Confirmare deconectare
        .alert("settings.account.sign_out_confirm_title", isPresented: $showingSignOutAlert) {
            Button("settings.account.sign_out", role: .destructive) {
                authService.signOut()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.account.sign_out_confirm_message")
        }
        // Confirmare ștergere cont (Obligatoriu conform App Store Review Guideline 5.1.1(v))
        .alert("settings.account.delete_confirm_title", isPresented: $showingDeleteAccountAlert) {
            Button("settings.account.delete_account", role: .destructive) {
                triggerDeleteAccount()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.account.delete_confirm_message")
        }
        // Alertă generică feedback
        .alert("Torpedou", isPresented: $showingAlertMessage) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Componente Vizuale

    @ViewBuilder
    private func signedInUserCard(user: AppleUserProfile) -> some View {
        HStack(spacing: 14) {
            // Avatar cu inițiale
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 52, height: 52)

                Text(user.initials)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let email = user.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                    Text("settings.account.verified_apple_id")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var signedOutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.account.backup_title")
                        .font(.headline)
                    Text("settings.account.backup_subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    authService.configureRequest(request)
                },
                onCompletion: { result in
                    authService.handleSignInResult(result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 6)
    }

    // MARK: - Acțiuni

    private func triggerCloudBackup() {
        Task {
            do {
                if syncManager.isFirebaseConfigured {
                    try await syncManager.syncToCloud(context: modelContext)
                    alertMessage = AppLanguage.tr(
                        "Copia de siguranță a fost sincronizată cu succes în Cloud!",
                        "Your backup was successfully synced to the Cloud!"
                    )
                } else {
                    _ = try backupManager.createSnapshot(context: modelContext)
                    let now = Date()
                    authService.recordBackupCompleted(at: now)
                    alertMessage = AppLanguage.tr(
                        "Copia de siguranță a fost creată pe dispozitiv. Folosește 'Exportă fișier de siguranță' pentru a o salva în iCloud Drive.",
                        "Backup snapshot created on device. Use 'Export Backup File' below to save it to iCloud Drive."
                    )
                }
                showingAlertMessage = true
            } catch {
                alertMessage = "\(AppLanguage.tr("Eroare la backup", "Backup error")): \(error.localizedDescription)"
                showingAlertMessage = true
            }
        }
    }

    private func triggerRestoreFromCloud() {
        Task {
            do {
                if syncManager.isFirebaseConfigured {
                    try await syncManager.restoreFromCloud(context: modelContext)
                    alertMessage = AppLanguage.tr(
                        "Datele au fost restaurate cu succes din Cloud!",
                        "Your data was successfully restored from the Cloud!"
                    )
                } else {
                    alertMessage = AppLanguage.tr(
                        "Pentru a restaura dintr-un fișier de siguranță, folosește opțiunea 'Importă fișier de siguranță' de mai jos.",
                        "To restore from a backup file, use the 'Import Backup File' option below."
                    )
                }
                showingAlertMessage = true
            } catch {
                alertMessage = "\(AppLanguage.tr("Eroare la restaurare", "Restore error")): \(error.localizedDescription)"
                showingAlertMessage = true
            }
        }
    }

    private func exportLocalBackup() {
        do {
            let fileURL = try backupManager.exportBackupFile(context: modelContext)
            self.exportedFileURL = fileURL
            self.showingExportShareSheet = true
        } catch {
            alertMessage = "\(AppLanguage.tr("Eroare la export", "Export error")): \(error.localizedDescription)"
            showingAlertMessage = true
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            do {
                let snapshot = try backupManager.importBackupFile(
                    from: selectedURL,
                    context: modelContext,
                    strategy: .merge
                )
                alertMessage = AppLanguage.tr(
                    "Au fost importate cu succes datele pentru \(snapshot.vehicles.count) vehicule.",
                    "Successfully imported data for \(snapshot.vehicles.count) vehicles."
                )
                showingAlertMessage = true
            } catch {
                alertMessage = "\(AppLanguage.tr("Eroare la citirea fișierului de backup", "Error reading backup file")): \(error.localizedDescription)"
                showingAlertMessage = true
            }
        case .failure(let error):
            alertMessage = "\(AppLanguage.tr("Selectare anulată", "Selection cancelled")): \(error.localizedDescription)"
            showingAlertMessage = true
        }
    }

    private func triggerDeleteAccount() {
        Task {
            do {
                try await authService.deleteAccount()
                alertMessage = AppLanguage.tr(
                    "Contul și datele tale din Cloud au fost șterse definitiv. Vehiculele tale locale au rămas pe dispozitiv.",
                    "Your account and Cloud data have been permanently deleted. Your local vehicles remain on this device."
                )
                showingAlertMessage = true
            } catch {
                alertMessage = "\(AppLanguage.tr("Eroare la ștergerea contului", "Error deleting account")): \(error.localizedDescription)"
                showingAlertMessage = true
            }
        }
    }
}

// MARK: - Share Sheet Helper

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
