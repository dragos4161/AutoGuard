//
//  AppLanguage.swift
//  AutoGuard
//
//  Created by Dragos Dima on 26.10.2026.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case romanian = "ro"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return "Automat (Sistem)"
        case .romanian:
            return "Română 🇷🇴"
        case .english:
            return "English 🇬🇧"
        }
    }
    
    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent // Ia limba curentă din setările iOS
        case .romanian:
            return Locale(identifier: "ro")
        case .english:
            return Locale(identifier: "en")
        }
    }
}
