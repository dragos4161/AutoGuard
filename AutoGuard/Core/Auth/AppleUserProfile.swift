//
//  AppleUserProfile.swift
//  AutoGuard
//
//  Modelul de date pentru utilizatorul autentificat prin Sign in with Apple.
//

import Foundation

public struct AppleUserProfile: Codable, Identifiable, Equatable {
    public let id: String                 // Apple User Identifier unic (ex: 000123.abcde...)
    public var email: String?             // Email partajat sau relay privat Apple (@privaterelay.appleid.com)
    public var givenName: String?         // Prenume
    public var familyName: String?        // Nume de familie
    public var identityToken: String?     // JWT semnat de Apple pentru validare backend / Firebase
    public var authorizationCode: String? // Cod de autorizare pentru token exchange
    public var signedInAt: Date           // Data autentificării
    public var lastBackupDate: Date?      // Data ultimului backup în cloud

    public init(
        id: String,
        email: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        identityToken: String? = nil,
        authorizationCode: String? = nil,
        signedInAt: Date = Date(),
        lastBackupDate: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.givenName = givenName
        self.familyName = familyName
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.signedInAt = signedInAt
        self.lastBackupDate = lastBackupDate
    }

    /// Nume complet formatat pentru interfață
    public var displayName: String {
        let components = [givenName, familyName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !components.isEmpty {
            return components.joined(separator: " ")
        }
        if let email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return "Utilizator Apple"
    }

    /// Inițiale pentru avatar circular
    public var initials: String {
        let first = givenName?.first.map { String($0) } ?? ""
        let last = familyName?.first.map { String($0) } ?? ""
        let combined = "\(first)\(last)".uppercased()
        return combined.isEmpty ? "" : combined
    }
}
