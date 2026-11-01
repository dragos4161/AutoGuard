//
//  AppTab.swift
//  AutoGuard
//
//  Definiția tab-urilor principale pentru bara de navigare inferioară (TabView).
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case garage
    case service
    case assistant
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .garage: return "tab.garage"
        case .service: return "tab.service"
        case .assistant: return "tab.assistant"
        case .settings: return "tab.settings"
        }
    }

    var iconName: String {
        switch self {
        case .garage: return "car.2.fill"
        case .service: return "wrench.and.screwdriver.fill"
        case .assistant: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}
