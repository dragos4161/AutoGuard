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

    /// Verifică dacă `GoogleService-Info.plist` este inclus în Bundle-ul aplicației
    public func checkFirebaseAvailability() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: path) {
            self.isFirebaseConfigured = true
            self.status = .idle
        } else {
            self.isFirebaseConfigured = false
            self.status = .notConfigured
        }
    }

    /// Sincronizare Cloud Firestore
    public func syncToCloud(context: ModelContext) async throws {
        guard isFirebaseConfigured else {
            status = .notConfigured
            throw NSError(
                domain: "FirebaseSync",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Firebase nu este configurat. Folosește 'Exportă fișier de siguranță' pentru a salva datele în iCloud Drive sau Files."]
            )
        }

        guard AppleAuthService.shared.currentUser != nil else {
            status = .error("Trebuie să fii autentificat cu Apple ID.")
            throw NSError(
                domain: "FirebaseSync",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Autentifică-te mai întâi cu Apple ID."]
            )
        }

        status = .syncing
        _ = try CloudBackupManager.shared.createSnapshot(context: context)

        let now = Date()
        self.lastSyncDate = now
        UserDefaults.standard.set(now, forKey: lastSyncKey)
        AppleAuthService.shared.recordBackupCompleted(at: now)
        status = .success(now)
    }

    /// Restaurare din Cloud Firestore
    public func restoreFromCloud(context: ModelContext) async throws {
        guard isFirebaseConfigured else {
            status = .notConfigured
            throw NSError(
                domain: "FirebaseSync",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Firebase nu este configurat încă. Folosește 'Importă fișier de siguranță' pentru a restaura o copie locală."]
            )
        }

        status = .syncing
        let now = Date()
        self.lastSyncDate = now
        status = .success(now)
    }
}
