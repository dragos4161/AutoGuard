//
//  ServiceCategory.swift
//  AutoGuard
//
//  Categoriile pentru operațiunile de service auto (revizii, frâne, distribuție etc.)
//

import SwiftUI

enum ServiceCategory: String, Codable, CaseIterable, Identifiable {
    case oilAndFilters = "oilAndFilters"
    case brakes = "brakes"
    case timingBelt = "timingBelt"
    case tires = "tires"
    case suspension = "suspension"
    case general = "general"

    var id: String { rawValue }

    var titleResource: LocalizedStringResource {
        switch self {
        case .oilAndFilters: return "service.category.oil_and_filters"
        case .brakes: return "service.category.brakes"
        case .timingBelt: return "service.category.timing_belt"
        case .tires: return "service.category.tires"
        case .suspension: return "service.category.suspension"
        case .general: return "service.category.general"
        }
    }

    var localizedTitle: String {
        switch self {
        case .oilAndFilters: return AppLanguage.tr("Ulei & Filtre", "Oil & Filters")
        case .brakes: return AppLanguage.tr("Sistem Frânare", "Brakes")
        case .timingBelt: return AppLanguage.tr("Kit Distribuție", "Timing Belt")
        case .tires: return AppLanguage.tr("Anvelope & Roți", "Tires & Wheels")
        case .suspension: return AppLanguage.tr("Direcție & Suspensie", "Suspension & Steering")
        case .general: return AppLanguage.tr("Mentenanță Generală", "General Maintenance")
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .oilAndFilters: return "service.category.oil_and_filters"
        case .brakes: return "service.category.brakes"
        case .timingBelt: return "service.category.timing_belt"
        case .tires: return "service.category.tires"
        case .suspension: return "service.category.suspension"
        case .general: return "service.category.general"
        }
    }

    var iconName: String {
        switch self {
        case .oilAndFilters: return "drop.fill"
        case .brakes: return "circle.circle.fill"
        case .timingBelt: return "gearshape.2.fill"
        case .tires: return "tirepressure"
        case .suspension: return "steeringwheel"
        case .general: return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .oilAndFilters: return .orange
        case .brakes: return .red
        case .timingBelt: return .purple
        case .tires: return .blue
        case .suspension: return .teal
        case .general: return .gray
        }
    }
}
