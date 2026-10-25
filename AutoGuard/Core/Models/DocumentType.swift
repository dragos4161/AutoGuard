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
    case casco = "CASCO"
    case extinguisher = "Trusă & Stingător"

    var id: String { rawValue }

    /// Titlul afișat în interfață
    var title: String {
        switch self {
        case .rca: return "Poliță RCA"
        case .itp: return "Inspecție ITP"
        case .rovinieta: return "Rovinietă"
        case .casco: return "Asigurare CASCO"
        case .extinguisher: return "Trusă & Stingător"
        }
    }

    /// Icoana SF Symbol nativă pentru iOS
    var iconName: String {
        switch self {
        case .rca: return "shield.lefthalf.filled"
        case .itp: return "checkmark.seal.fill"
        case .rovinieta: return "road.lanes"
        case .casco: return "car.badge.shield"
        case .extinguisher: return "cross.case.fill"
        }
    }
}
