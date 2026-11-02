//
//  FirebaseSyncManager.swift
//  AutoGuard
//
//  Managerul pentru conectarea viitoare cu Google Firebase (Firestore) pentru sincronizarea
//  cross-platform între iOS și viitoarea versiune de Android.
//

import Foundation
import SwiftData
import SwiftUI
import AuthenticationServices
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

public enum FirebaseSyncStatus: Equatable {
    case notConfigured      // GoogleService-Info.plist nu este prezent în proiect
    case idle               // Configurat și gata de sincronizare
    case syncing            // Sincronizare în desfășurare
    case success(Date)      // Sincronizat cu succes
    case error(String)      // Mesaj de informare / eroare
}

@MainActor
@Observable
public final class FirebaseSyncManager {
    public static let shared = FirebaseSyncManager()

    public private(set) var status: FirebaseSyncStatus = .notConfigured
    public private(set) var isFirebaseConfigured: Bool = false
    public private(set) var lastSyncDate: Date?

    private let lastSyncKey = "torpedou_last_firebase_sync_date"

    private init() {
        checkFirebaseAvailability()
        if let storedDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = storedDate
        }
    }

    /// Inițializează `FirebaseApp.configure()` la pornirea aplicației dacă `GoogleService-Info.plist` există
    public func configureIfNeeded() {
        checkFirebaseAvailability()
        #if canImport(FirebaseCore)
        if isFirebaseConfigured && FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    /// Verifică dacă `GoogleService-Info.plist` este inclus în Bundle-ul aplicației
    public func checkFirebaseAvailability() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: path) {
            self.isFirebaseConfigured = true
            if self.status == .notConfigured {
                self.status = .idle
            }
        } else {
            self.isFirebaseConfigured = false
            self.status = .notConfigured
        }
    }

    /// Autentifică sesiunea Firebase Auth folosind token-ul de la Sign in with Apple
    public func authenticateWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        guard isFirebaseConfigured else { return }
        #if canImport(FirebaseAuth)
        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            self.status = .error(error.localizedDescription)
        }
        #endif
    }

    /// Deconectează utilizatorul din Firebase Auth
    public func signOutFromFirebase() {
        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            try? Auth.auth().signOut()
        }
        #endif
    }

    /// Sincronizare Cloud Firestore (fiecare vehicul într-un document separat sub `users/{uid}/vehicles/{vehicleId}`)
    public func syncToCloud(context: ModelContext) async throws {
        guard isFirebaseConfigured else {
            status = .notConfigured
            throw NSError(
                domain: "FirebaseSync",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: AppLanguage.tr(
                    "Firebase nu este configurat. Folosește 'Exportă fișier de siguranță' pentru a salva datele în iCloud Drive sau Files.",
                    "Firebase is not configured yet. Use 'Export Backup File' to save your data to iCloud Drive or Files."
                )]
            )
        }

        guard let localUser = AppleAuthService.shared.currentUser else {
            let msg = AppLanguage.tr("Trebuie să fii autentificat cu Apple ID.", "You must be signed in with Apple ID.")
            status = .error(msg)
            throw NSError(
                domain: "FirebaseSync",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }

        status = .syncing

        do {
            // Creăm snapshot-ul cu imaginile comprimate pentru a respecta limita de 1 MB / document din Firestore
            let snapshot = try CloudBackupManager.shared.createSnapshot(
                context: context,
                compressImagesForCloud: true
            )

            #if canImport(FirebaseFirestore)
            #if canImport(FirebaseAuth)
            let uid = Auth.auth().currentUser?.uid ?? localUser.id
            #else
            let uid = localUser.id
            #endif

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(uid)

            try await userRef.setData([
                "userIdentifier": localUser.id,
                "email": localUser.email ?? "",
                "displayName": localUser.displayName,
                "lastSyncedAt": FieldValue.serverTimestamp(),
                "schemaVersion": snapshot.schemaVersion,
                "vehicleCount": snapshot.vehicles.count
            ], merge: true)

            let vehiclesCollection = userRef.collection("vehicles")
            let existingDocs = try await vehiclesCollection.getDocuments()
            let currentIds = Set(snapshot.vehicles.map { $0.id.uuidString })

            // Ștergem din Cloud vehiculele care au fost șterse local (inclusiv subcolecția attachments)
            for doc in existingDocs.documents where !currentIds.contains(doc.documentID) {
                if let attachmentsSnap = try? await doc.reference.collection("attachments").getDocuments() {
                    for att in attachmentsSnap.documents {
                        try? await att.reference.delete()
                    }
                }
                try await doc.reference.delete()
            }

            // Salvăm fiecare vehicul în propriul document, iar fișierele (PDF-uri + poze) în Firebase Storage
            for vehicleBackup in snapshot.vehicles {
                let vehicleId = vehicleBackup.id.uuidString
                let vehicleRef = vehiclesCollection.document(vehicleId)
                let attachmentsCol = vehicleRef.collection("attachments")
                var activeAttachmentIds = Set<String>()

                // 1. Încărcăm pozele din Portofel (Talon & Permis) în Firebase Storage
                let regFrontPath = await uploadBase64ToStorage(
                    base64: vehicleBackup.registrationFrontBase64,
                    storagePath: "users/\(uid)/vehicles/\(vehicleId)/wallet/registration_front.jpg",
                    contentType: "image/jpeg"
                )
                let regBackPath = await uploadBase64ToStorage(
                    base64: vehicleBackup.registrationBackBase64,
                    storagePath: "users/\(uid)/vehicles/\(vehicleId)/wallet/registration_back.jpg",
                    contentType: "image/jpeg"
                )
                let licFrontPath = await uploadBase64ToStorage(
                    base64: vehicleBackup.driverLicenseFrontBase64,
                    storagePath: "users/\(uid)/vehicles/\(vehicleId)/wallet/license_front.jpg",
                    contentType: "image/jpeg"
                )
                let licBackPath = await uploadBase64ToStorage(
                    base64: vehicleBackup.driverLicenseBackBase64,
                    storagePath: "users/\(uid)/vehicles/\(vehicleId)/wallet/license_back.jpg",
                    contentType: "image/jpeg"
                )

                // 2. Încărcăm atașamentele documentelor (PDF / JPEG) în Firebase Storage
                var updatedDocuments: [DocumentBackupDTO] = []
                for doc in vehicleBackup.documents {
                    var storagePath: String? = doc.attachmentStoragePath
                    if let base64 = doc.attachmentBase64, !base64.isEmpty {
                        let isPDF = doc.attachmentFileName?.lowercased().hasSuffix(".pdf") == true
                        let ext = isPDF ? "pdf" : "jpg"
                        let mime = isPDF ? "application/pdf" : "image/jpeg"
                        let targetPath = "users/\(uid)/vehicles/\(vehicleId)/documents/\(doc.id.uuidString).\(ext)"

                        if let uploadedPath = await uploadBase64ToStorage(base64: base64, storagePath: targetPath, contentType: mime) {
                            storagePath = uploadedPath
                        } else if base64.count <= 900_000 {
                            // Fallback în subcolecția Firestore `attachments` dacă Firebase Storage nu este încă activat în consolă
                            let attId = doc.id.uuidString
                            activeAttachmentIds.insert(attId)
                            var payload: [String: Any] = [
                                "id": attId,
                                "kind": "document",
                                "dataBase64": base64
                            ]
                            if let fileName = doc.attachmentFileName {
                                payload["fileName"] = String(fileName.prefix(250))
                            }
                            try? await attachmentsCol.document(attId).setData(payload)
                        }
                    }

                    updatedDocuments.append(
                        DocumentBackupDTO(
                            id: doc.id,
                            typeRawValue: doc.typeRawValue,
                            expirationDate: doc.expirationDate,
                            createdAt: doc.createdAt,
                            price: doc.price,
                            provider: doc.provider,
                            policyNumber: doc.policyNumber,
                            isArchived: doc.isArchived,
                            archivedAt: doc.archivedAt,
                            attachmentFileName: doc.attachmentFileName,
                            attachmentBase64: nil,
                            attachmentStoragePath: storagePath
                        )
                    )
                }

                // 3. Încărcăm facturile / devizele service (PDF / JPEG) în Firebase Storage
                var updatedServices: [ServiceBackupDTO] = []
                for service in vehicleBackup.serviceRecords {
                    var storagePath: String? = service.invoiceStoragePath
                    if let base64 = service.invoiceBase64, !base64.isEmpty {
                        let isPDF = service.invoiceFileName?.lowercased().hasSuffix(".pdf") == true
                        let ext = isPDF ? "pdf" : "jpg"
                        let mime = isPDF ? "application/pdf" : "image/jpeg"
                        let targetPath = "users/\(uid)/vehicles/\(vehicleId)/services/\(service.id.uuidString).\(ext)"

                        if let uploadedPath = await uploadBase64ToStorage(base64: base64, storagePath: targetPath, contentType: mime) {
                            storagePath = uploadedPath
                        } else if base64.count <= 900_000 {
                            let attId = service.id.uuidString
                            activeAttachmentIds.insert(attId)
                            var payload: [String: Any] = [
                                "id": attId,
                                "kind": "service",
                                "dataBase64": base64
                            ]
                            if let fileName = service.invoiceFileName {
                                payload["fileName"] = String(fileName.prefix(250))
                            }
                            try? await attachmentsCol.document(attId).setData(payload)
                        }
                    }

                    updatedServices.append(
                        ServiceBackupDTO(
                            id: service.id,
                            date: service.date,
                            mileage: service.mileage,
                            title: service.title,
                            categoryRawValue: service.categoryRawValue,
                            notes: service.notes,
                            price: service.price,
                            invoiceFileName: service.invoiceFileName,
                            invoiceBase64: nil,
                            invoiceStoragePath: storagePath
                        )
                    )
                }

                let cloudVehicleDTO = VehicleBackupDTO(
                    id: vehicleBackup.id,
                    plateNumber: vehicleBackup.plateNumber,
                    make: vehicleBackup.make,
                    model: vehicleBackup.model,
                    year: vehicleBackup.year,
                    vin: vehicleBackup.vin,
                    nickname: vehicleBackup.nickname,
                    createdAt: vehicleBackup.createdAt,
                    oilChangeIntervalKm: vehicleBackup.oilChangeIntervalKm,
                    oilChangeIntervalMonths: vehicleBackup.oilChangeIntervalMonths,
                    documents: updatedDocuments,
                    mileageEntries: vehicleBackup.mileageEntries,
                    serviceRecords: updatedServices,
                    fuelEntries: vehicleBackup.fuelEntries,
                    registrationFrontBase64: regFrontPath == nil ? vehicleBackup.registrationFrontBase64 : nil,
                    registrationBackBase64: regBackPath == nil ? vehicleBackup.registrationBackBase64 : nil,
                    driverLicenseFrontBase64: licFrontPath == nil ? vehicleBackup.driverLicenseFrontBase64 : nil,
                    driverLicenseBackBase64: licBackPath == nil ? vehicleBackup.driverLicenseBackBase64 : nil,
                    registrationFrontStoragePath: regFrontPath,
                    registrationBackStoragePath: regBackPath,
                    driverLicenseFrontStoragePath: licFrontPath,
                    driverLicenseBackStoragePath: licBackPath
                )

                let dict = try CloudBackupManager.shared.encodeVehicleDictionary(cloudVehicleDTO)
                try await vehicleRef.setData(dict)

                if let existingAttachments = try? await attachmentsCol.getDocuments() {
                    for attDoc in existingAttachments.documents where !activeAttachmentIds.contains(attDoc.documentID) {
                        try? await attDoc.reference.delete()
                    }
                }
            }
            #else
            _ = localUser
            _ = snapshot
            #endif

            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: lastSyncKey)
            AppleAuthService.shared.recordBackupCompleted(at: now)
            status = .success(now)
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
    }

    /// Restaurare din Cloud Firestore
    public func restoreFromCloud(context: ModelContext) async throws {
        guard isFirebaseConfigured else {
            status = .notConfigured
            throw NSError(
                domain: "FirebaseSync",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: AppLanguage.tr(
                    "Firebase nu este configurat încă. Folosește 'Importă fișier de siguranță' pentru a restaura o copie locală.",
                    "Firebase is not configured yet. Use 'Import Backup File' to restore a local backup."
                )]
            )
        }

        guard let localUser = AppleAuthService.shared.currentUser else {
            let msg = AppLanguage.tr("Trebuie să fii autentificat cu Apple ID.", "You must be signed in with Apple ID.")
            status = .error(msg)
            throw NSError(
                domain: "FirebaseSync",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }

        status = .syncing

        do {
            #if canImport(FirebaseFirestore)
            #if canImport(FirebaseAuth)
            let uid = Auth.auth().currentUser?.uid ?? localUser.id
            #else
            let uid = localUser.id
            #endif

            let db = Firestore.firestore()
            let vehiclesSnapshot = try await db.collection("users").document(uid).collection("vehicles").getDocuments()

            var restoredVehicles: [VehicleBackupDTO] = []
            for doc in vehiclesSnapshot.documents {
                let vehicleBackup = try CloudBackupManager.shared.decodeVehicleDictionary(doc.data())

                // Preluăm atașamentele din subcolecția `attachments` (fallback) și din Firebase Storage
                var attachmentMap: [String: String] = [:]
                if let attachmentsSnap = try? await doc.reference.collection("attachments").getDocuments() {
                    for attDoc in attachmentsSnap.documents {
                        if let base64 = attDoc.data()["dataBase64"] as? String {
                            attachmentMap[attDoc.documentID] = base64
                        }
                    }
                }

                var enrichedDocs: [DocumentBackupDTO] = []
                for d in vehicleBackup.documents {
                    var resolvedBase64 = attachmentMap[d.id.uuidString] ?? d.attachmentBase64
                    if resolvedBase64 == nil, let storagePath = d.attachmentStoragePath {
                        resolvedBase64 = await downloadBase64FromStorage(storagePath: storagePath)
                    }
                    enrichedDocs.append(
                        DocumentBackupDTO(
                            id: d.id,
                            typeRawValue: d.typeRawValue,
                            expirationDate: d.expirationDate,
                            createdAt: d.createdAt,
                            price: d.price,
                            provider: d.provider,
                            policyNumber: d.policyNumber,
                            isArchived: d.isArchived,
                            archivedAt: d.archivedAt,
                            attachmentFileName: d.attachmentFileName,
                            attachmentBase64: resolvedBase64,
                            attachmentStoragePath: d.attachmentStoragePath
                        )
                    )
                }

                var enrichedServices: [ServiceBackupDTO] = []
                for s in vehicleBackup.serviceRecords {
                    var resolvedBase64 = attachmentMap[s.id.uuidString] ?? s.invoiceBase64
                    if resolvedBase64 == nil, let storagePath = s.invoiceStoragePath {
                        resolvedBase64 = await downloadBase64FromStorage(storagePath: storagePath)
                    }
                    enrichedServices.append(
                        ServiceBackupDTO(
                            id: s.id,
                            date: s.date,
                            mileage: s.mileage,
                            title: s.title,
                            categoryRawValue: s.categoryRawValue,
                            notes: s.notes,
                            price: s.price,
                            invoiceFileName: s.invoiceFileName,
                            invoiceBase64: resolvedBase64,
                            invoiceStoragePath: s.invoiceStoragePath
                        )
                    )
                }

                var regFrontBase64 = vehicleBackup.registrationFrontBase64
                if regFrontBase64 == nil, let path = vehicleBackup.registrationFrontStoragePath {
                    regFrontBase64 = await downloadBase64FromStorage(storagePath: path)
                }
                var regBackBase64 = vehicleBackup.registrationBackBase64
                if regBackBase64 == nil, let path = vehicleBackup.registrationBackStoragePath {
                    regBackBase64 = await downloadBase64FromStorage(storagePath: path)
                }
                var licFrontBase64 = vehicleBackup.driverLicenseFrontBase64
                if licFrontBase64 == nil, let path = vehicleBackup.driverLicenseFrontStoragePath {
                    licFrontBase64 = await downloadBase64FromStorage(storagePath: path)
                }
                var licBackBase64 = vehicleBackup.driverLicenseBackBase64
                if licBackBase64 == nil, let path = vehicleBackup.driverLicenseBackStoragePath {
                    licBackBase64 = await downloadBase64FromStorage(storagePath: path)
                }

                let enrichedVehicle = VehicleBackupDTO(
                    id: vehicleBackup.id,
                    plateNumber: vehicleBackup.plateNumber,
                    make: vehicleBackup.make,
                    model: vehicleBackup.model,
                    year: vehicleBackup.year,
                    vin: vehicleBackup.vin,
                    nickname: vehicleBackup.nickname,
                    createdAt: vehicleBackup.createdAt,
                    oilChangeIntervalKm: vehicleBackup.oilChangeIntervalKm,
                    oilChangeIntervalMonths: vehicleBackup.oilChangeIntervalMonths,
                    documents: enrichedDocs,
                    mileageEntries: vehicleBackup.mileageEntries,
                    serviceRecords: enrichedServices,
                    fuelEntries: vehicleBackup.fuelEntries,
                    registrationFrontBase64: regFrontBase64,
                    registrationBackBase64: regBackBase64,
                    driverLicenseFrontBase64: licFrontBase64,
                    driverLicenseBackBase64: licBackBase64,
                    registrationFrontStoragePath: vehicleBackup.registrationFrontStoragePath,
                    registrationBackStoragePath: vehicleBackup.registrationBackStoragePath,
                    driverLicenseFrontStoragePath: vehicleBackup.driverLicenseFrontStoragePath,
                    driverLicenseBackStoragePath: vehicleBackup.driverLicenseBackStoragePath
                )
                restoredVehicles.append(enrichedVehicle)
            }

            let backupSnapshot = CloudBackupSnapshot(
                createdAt: Date(),
                userIdentifier: localUser.id,
                vehicles: restoredVehicles
            )
            try CloudBackupManager.shared.restore(from: backupSnapshot, context: context, strategy: .merge)
            #else
            _ = localUser
            #endif

            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: lastSyncKey)
            status = .success(now)
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
    }

    /// Șterge toate datele din Cloud Firestore și contul din Firebase Auth (pentru "Șterge contul")
    public func deleteCloudAccountData() async throws {
        #if canImport(FirebaseFirestore)
        if isFirebaseConfigured, let localUser = AppleAuthService.shared.currentUser {
            #if canImport(FirebaseAuth)
            let uid = Auth.auth().currentUser?.uid ?? localUser.id
            #else
            let uid = localUser.id
            #endif

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(uid)
            let vehiclesSnapshot = try await userRef.collection("vehicles").getDocuments()
            for doc in vehiclesSnapshot.documents {
                if let attachmentsSnap = try? await doc.reference.collection("attachments").getDocuments() {
                    for att in attachmentsSnap.documents {
                        try? await att.reference.delete()
                    }
                }
                try await doc.reference.delete()
            }
            try await userRef.delete()
        }
        #endif

        #if canImport(FirebaseAuth)
        if isFirebaseConfigured, let firebaseUser = Auth.auth().currentUser {
            try await firebaseUser.delete()
        }
        #endif

        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        lastSyncDate = nil
    }

    // MARK: - Helperi Firebase Cloud Storage

    /// Încarcă un fișier (codificat Base64) în Firebase Storage și returnează calea dacă reușește
    private func uploadBase64ToStorage(base64: String?, storagePath: String, contentType: String) async -> String? {
        guard let base64, !base64.isEmpty, let data = Data(base64Encoded: base64) else {
            return nil
        }
        #if canImport(FirebaseStorage)
        do {
            let storageRef = Storage.storage().reference().child(storagePath)
            let metadata = StorageMetadata()
            metadata.contentType = contentType
            _ = try await storageRef.putDataAsync(data, metadata: metadata)
            return storagePath
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Descarcă un fișier din Firebase Storage și îl returnează ca string Base64
    private func downloadBase64FromStorage(storagePath: String) async -> String? {
        guard !storagePath.isEmpty else { return nil }
        #if canImport(FirebaseStorage)
        do {
            let storageRef = Storage.storage().reference().child(storagePath)
            let data = try await storageRef.data(maxSize: 15 * 1024 * 1024)
            return data.base64EncodedString()
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
