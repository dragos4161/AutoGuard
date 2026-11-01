//
//  AppleAuthService.swift
//  AutoGuard
//
//  Serviciu complet pentru Sign in with Apple conform ghidurilor Apple Human Interface Guidelines.
//  Gestionează autorizarea, salvarea în Keychain și verificarea stării sesiunii la pornire.
//

import Foundation
import AuthenticationServices
import CryptoKit
import Security

@MainActor
@Observable
public final class AppleAuthService: NSObject {
    public static let shared = AppleAuthService()

    public private(set) var currentUser: AppleUserProfile?
    public private(set) var isAuthenticating: Bool = false
    public private(set) var errorMessage: String?

    private let userDefaultsKey = "torpedou_cached_apple_user"
    private let keychainServiceKey = "com.ascend.AutoGuard.apple_auth"
    private var currentNonce: String?

    override private init() {
        super.init()
        loadCachedUser()
        checkCredentialStateOnLaunch()
    }

    public var isSignedIn: Bool {
        currentUser != nil
    }

    // MARK: - Autentificare din SwiftUI

    /// Procesează rezultatul primit direct de la `SignInWithAppleButton` (previne dubla inițializare)
    public func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isAuthenticating = false
        switch result {
        case .success(let authorization):
            processAuthorization(authorization)
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Pornește fluxul programatic de Sign in with Apple (când se folosește un buton personalizat)
    public func startSignInFlow() {
        isAuthenticating = true
        errorMessage = nil

        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    /// Deconectează utilizatorul local
    public func signOut() {
        if let user = currentUser {
            deleteFromKeychain(account: user.id)
        }
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentUser = nil
        isAuthenticating = false
        errorMessage = nil
    }

    /// Actualizează data ultimului backup în cloud
    public func recordBackupCompleted(at date: Date = Date()) {
        guard var user = currentUser else { return }
        user.lastBackupDate = date
        currentUser = user
        saveUser(user)
    }

    // MARK: - Prelucrare Autorizare

    public func processAuthorization(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Răspuns invalid de la serviciul Apple ID."
            return
        }

        let userIdentifier = appleIDCredential.user
        let email = appleIDCredential.email
        let givenName = appleIDCredential.fullName?.givenName
        let familyName = appleIDCredential.fullName?.familyName

        // Salvăm ID-ul sigur în Keychain
        saveToKeychain(account: userIdentifier, data: Data(userIdentifier.utf8))

        var profile = currentUser ?? AppleUserProfile(id: userIdentifier)
        if let email, !email.isEmpty {
            profile.email = email
        }
        if let givenName, !givenName.isEmpty {
            profile.givenName = givenName
        }
        if let familyName, !familyName.isEmpty {
            profile.familyName = familyName
        }
        profile.signedInAt = Date()

        self.currentUser = profile
        self.saveUser(profile)
        self.errorMessage = nil
    }

    // MARK: - Persistență și Verificare

    private func saveUser(_ user: AppleUserProfile) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadCachedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(AppleUserProfile.self, from: data) else {
            return
        }
        self.currentUser = user
    }

    /// Verifică dacă Apple ID-ul utilizatorului este încă valid sau a fost revocat din setările iOS
    private func checkCredentialStateOnLaunch() {
        guard let user = currentUser else { return }
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: user.id) { state, _ in
            Task { @MainActor in
                switch state {
                case .authorized:
                    break
                case .revoked, .notFound:
                    AppleAuthService.shared.signOut()
                case .transferred:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Criptografie & Nonce

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Eroare la generarea nonce securizat: \(errorCode)")
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceKey,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceKey,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate & PresentationContext

extension AppleAuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isAuthenticating = false
        processAuthorization(authorization)
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isAuthenticating = false
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            errorMessage = nil
            return
        }
        errorMessage = error.localizedDescription
    }
}
