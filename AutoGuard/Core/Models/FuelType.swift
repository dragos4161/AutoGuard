//
//  FuelType.swift
//  AutoGuard
//
//  Tipul de carburant utilizat la alimentare (Benzină, Motorină, GPL, Electric etc.)
//

import SwiftUI

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case petrol95 = "petrol95"
    case petrol98 = "petrol98"
    case diesel = "diesel"
    case premiumDiesel = "premiumDiesel"
    case lpg = "lpg"
    case cng = "cng"
    case electric = "electric"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .petrol95: return "fuel.type.petrol95"
        case .petrol98: return "fuel.type.petrol98"
        case .diesel: return "fuel.type.diesel"
        case .premiumDiesel: return "fuel.type.premium_diesel"
        case .lpg: return "fuel.type.lpg"
        case .cng: return "fuel.type.cng"
        case .electric: return "fuel.type.electric"
        }
    }

    var defaultDisplayName: String {
        switch self {
        case .petrol95: return AppLanguage.tr("Benzină 95", "Petrol 95")
        case .petrol98: return AppLanguage.tr("Benzină Premium (98/100)", "Premium Petrol (98/100)")
        case .diesel: return AppLanguage.tr("Motorină Standard", "Standard Diesel")
        case .premiumDiesel: return AppLanguage.tr("Motorină Premium", "Premium Diesel")
        case .lpg: return AppLanguage.tr("GPL", "LPG")
        case .cng: return AppLanguage.tr("GNC", "CNG")
        case .electric: return AppLanguage.tr("Electric (kWh)", "Electric (kWh)")
        }
    }

    var iconName: String {
        switch self {
        case .petrol95, .petrol98:
            return "fuelpump.fill"
        case .diesel, .premiumDiesel:
            return "fuelpump"
        case .lpg, .cng:
            return "flame.fill"
        case .electric:
            return "bolt.car.fill"
        }
    }

    var unitLabel: String {
        self == .electric ? "kWh" : "L"
    }

    var color: Color {
        switch self {
        case .petrol95: return .green
        case .petrol98: return .teal
        case .diesel: return .black
        case .premiumDiesel: return .indigo
        case .lpg, .cng: return .orange
        case .electric: return .blue
        }
    }
}
