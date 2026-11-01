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
    @State private var alertMessage: String?
    @State private var showingAlertMessage: Bool = false
    @State private var showingFirebaseInfoSheet: Bool = false

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

            // MARK: - Secțiunea 4: Configurare Firebase
            Section("settings.account.firebase_title") {
                HStack {
                    Label("Google Firebase Cloud", systemImage: "flame.fill")
                        .foregroundStyle(syncManager.isFirebaseConfigured ? .orange : .secondary)

                    Spacer()

                    Text(syncManager.isFirebaseConfigured ? "settings.account.active" : "settings.account.ready_for_setup")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(syncManager.isFirebaseConfigured ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundStyle(syncManager.isFirebaseConfigured ? .green : .orange)
                        .clipShape(Capsule())
                }

                Button {
                    showingFirebaseInfoSheet = true
                } label: {
                    HStack {
                        Text("settings.account.how_firebase_works")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }

            // MARK: - Secțiunea 5: Deconectare
            if authService.currentUser != nil {
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings.account.sign_out")
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
        // Alertă generică feedback
        .alert("Torpedou", isPresented: $showingAlertMessage) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        // Modal informativ Firebase
        .sheet(isPresented: $showingFirebaseInfoSheet) {
            firebaseInfoSheetView
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
                    authService.startSignInFlow()
                },
                onCompletion: { result in
                    // Gestionat automat prin delegate în AppleAuthService
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var firebaseInfoSheetView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "flame.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange.gradient)

                        Text("Google Firebase Sync")
                            .font(.title2.bold())

                        Text("settings.account.firebase_desc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("settings.account.firebase_steps_title")
                            .font(.headline)

                        stepRow(
                            number: "1",
                            title: "settings.account.firebase_step1_title",
                            desc: "settings.account.firebase_step1_desc"
                        )

                        stepRow(
                            number: "2",
                            title: "settings.account.firebase_step2_title",
                            desc: "settings.account.firebase_step2_desc"
                        )

                        stepRow(
                            number: "3",
                            title: "settings.account.firebase_step3_title",
                            desc: "settings.account.firebase_step3_desc"
                        )
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Firebase Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") {
                        showingFirebaseInfoSheet = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(number: String, title: LocalizedStringKey, desc: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Acțiuni

    private func triggerCloudBackup() {
        Task {
            do {
                try await syncManager.syncToCloud(context: modelContext)
                alertMessage = "Copia de siguranță a fost sincronizată cu succes în Cloud!"
                showingAlertMessage = true
            } catch {
                alertMessage = "Eroare la sincronizare: \(error.localizedDescription)"
                showingAlertMessage = true
            }
        }
    }

    private func triggerRestoreFromCloud() {
        Task {
            do {
                try await syncManager.restoreFromCloud(context: modelContext)
                alertMessage = "Datele au fost restaurate cu succes din Cloud!"
                showingAlertMessage = true
            } catch {
                alertMessage = "Eroare la restaurare: \(error.localizedDescription)"
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
            alertMessage = "Eroare la export: \(error.localizedDescription)"
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
                alertMessage = "Au fost importate cu succes datele pentru \(snapshot.vehicles.count) vehicule."
                showingAlertMessage = true
            } catch {
                alertMessage = "Eroare la citirea fișierului de backup: \(error.localizedDescription)"
                showingAlertMessage = true
            }
        case .failure(let error):
            alertMessage = "Selectare anulată: \(error.localizedDescription)"
            showingAlertMessage = true
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
