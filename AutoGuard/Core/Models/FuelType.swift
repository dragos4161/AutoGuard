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
        case .petrol95: return "Benzină 95"
        case .petrol98: return "Benzină Premium (98/100)"
        case .diesel: return "Motorină Standard"
        case .premiumDiesel: return "Motorină Premium"
        case .lpg: return "GPL"
        case .cng: return "GNC"
        case .electric: return "Electric (kWh)"
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
