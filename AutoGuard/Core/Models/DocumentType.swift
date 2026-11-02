//
//  DocumentType.swift
//  AutoGuard
//
//  Creat pentru gestionarea tipurilor de acte auto din România.
//

import SwiftUI

/// Tipul documentului auto (RCA, ITP, Rovinietă, CASCO etc.)
/// În Flutter, acesta ar fi un `enum` simplu cu metode de extensie.
enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case rca = "RCA"
    case itp = "ITP"
    case rovinieta = "Rovinietă"
    case foreignVignette = "Vinietă Străinătate"
    case casco = "CASCO"
    case extinguisher = "Trusă & Stingător"

    var id: String { rawValue }

    /// Cheia de localizare pentru afișarea numelui în interfață
    var titleKey: LocalizedStringKey {
        switch self {
        case .rca: return "doc.type.rca"
        case .itp: return "doc.type.itp"
        case .rovinieta: return "doc.type.rovinieta"
        case .foreignVignette: return "doc.type.foreign_vignette"
        case .casco: return "doc.type.casco"
        case .extinguisher: return "doc.type.extinguisher"
        }
    }

    /// Titlul afișat în interfață (adaptat la limba aplicației)
    var title: String {
        switch self {
        case .rca: return AppLanguage.tr("Poliță RCA", "RCA Insurance")
        case .itp: return AppLanguage.tr("Inspecție ITP", "ITP Inspection")
        case .rovinieta: return AppLanguage.tr("Rovinietă (RO)", "Vignette (RO)")
        case .foreignVignette: return AppLanguage.tr("Vinietă Străinătate", "Foreign Vignette")
        case .casco: return AppLanguage.tr("Asigurare CASCO", "CASCO Insurance")
        case .extinguisher: return AppLanguage.tr("Trusă & Stingător", "Safety Kit & Extinguisher")
        }
    }

    /// Icoana SF Symbol nativă pentru iOS
    var iconName: String {
        switch self {
        case .rca: return "shield.lefthalf.filled"
        case .itp: return "checkmark.seal.fill"
        case .rovinieta: return "road.lanes"
        case .foreignVignette: return "globe.europe.africa.fill"
        case .casco: return "car.badge.shield"
        case .extinguisher: return "cross.case.fill"
        }
    }
}
