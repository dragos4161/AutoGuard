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
    
    /// Limba curentă selectată în aplicație (sau limba sistemului dacă este pe .system)
    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }
    
    /// Helper rapid pentru alegerea textului în funcție de limba curentă a aplicației (Română vs Engleză)
    static func tr(_ ro: String, _ en: String) -> String {
        current.isRomanian ? ro : en
    }
    
    var displayName: String {
        switch self {
        case .system:
            return AppLanguage.tr("Automat (Sistem)", "Automatic (System)")
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

    var resolvedLanguageCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("ro") ? "ro" : "en"
        case .romanian:
            return "ro"
        case .english:
            return "en"
        }
    }

    var isRomanian: Bool {
        resolvedLanguageCode == "ro"
    }

    var localizedBundle: Bundle {
        if let path = Bundle.main.path(forResource: resolvedLanguageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    /// Obține traducerea localizată conform limbii selectate în aplicație.
    func string(_ key: String) -> String {
        let isRo = resolvedLanguageCode == "ro"

        // 1. Verificăm în bundle-ul compilat al limbii
        let localized = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if localized != key {
            return localized
        }

        // 2. Fallback garantat pentru string-urile cheie din Asistent
        if let dict = assistantFallbackTranslations[key], let val = dict[isRo ? "ro" : "en"] {
            return val
        }

        return key
    }
}

private let assistantFallbackTranslations: [String: [String: String]] = [
    "assistant.prompt.oil": [
        "ro": "Când trebuie să fac schimbul de ulei?",
        "en": "When should I change the oil?"
    ],
    "assistant.prompt.mileage": [
        "ro": "Care sunt kilometrii mașinilor mele?",
        "en": "What is the mileage of my cars?"
    ],
    "assistant.prompt.expirations": [
        "ro": "Ce acte îmi expiră în curând?",
        "en": "What documents are expiring soon?"
    ],
    "assistant.answer.no_vehicles": [
        "ro": "Nu ai nicio mașină înregistrată încă în garaj.",
        "en": "You don't have any vehicles registered in your garage yet."
    ],
    "assistant.answer.mileage_header": [
        "ro": "Iată kilometrajul curent al mașinilor tale:",
        "en": "Here is the current mileage of your vehicles:"
    ],
    "mileage.card.empty": [
        "ro": "Nespecificat",
        "en": "Not specified"
    ],
    "assistant.answer.oil_no_records": [
        "ro": "Nu ai înregistrat încă niciun schimb de ulei în tab-ul Service.",
        "en": "No oil change recorded yet in the Service tab."
    ],
    "assistant.answer.oil_last_change": [
        "ro": "Ultimul schimb de ulei: ",
        "en": "Last oil change: "
    ],
    "assistant.answer.oil_at": [
        "ro": "la",
        "en": "at"
    ],
    "assistant.answer.oil_overdue": [
        "ro": "⚠️ Termen depășit! Fă o programare în service.",
        "en": "⚠️ Overdue! Schedule a service appointment."
    ],
    "assistant.answer.oil_next": [
        "ro": "Următorul schimb: peste aprox.",
        "en": "Next change: in approx."
    ],
    "assistant.answer.oil_months": [
        "ro": "luni",
        "en": "months"
    ],
    "assistant.answer.oil_km_left": [
        "ro": "km rămași",
        "en": "km remaining"
    ],
    "assistant.answer.all_good": [
        "ro": "Vești bune! Toate actele mașinilor tale sunt în regulă și nu expiră în următoarele 30 de zile.",
        "en": "Great news! All vehicle documents are in order and none expire in the next 30 days."
    ],
    "assistant.answer.expiring_header": [
        "ro": "Atenție la următoarele documente:",
        "en": "Attention needed for the following documents:"
    ],
    "assistant.answer.days_left": [
        "ro": "zile rămase",
        "en": "days remaining"
    ],
    "notification.weekly_mileage.title": [
        "ro": "Actualizează kilometrajul 🚗",
        "en": "Update your mileage 🚗"
    ],
    "notification.weekly_mileage.body": [
        "ro": "Este sfârșitul săptămânii! Înregistrează kilometrajul din bord pentru a ține evidența reviziilor și consumului.",
        "en": "It's the end of the week! Log your odometer reading to keep maintenance tracking up to date."
    ],
    "assistant.answer.fallback": [
        "ro": "Pot să te ajut cu informații despre kilometraj, revizii de ulei sau expirarea actelor (RCA, ITP, Rovinietă). Alege una dintre sugestii sau formulează o întrebare legată de acestea!",
        "en": "I can help you with mileage information, oil changes, or document expirations (RCA, ITP, Vignette). Pick one of the suggestions or ask a related question!"
    ],
    "service.category.oil_and_filters": [
        "ro": "Ulei & Filtre",
        "en": "Oil & Filters"
    ],
    "service.category.brakes": [
        "ro": "Sistem Frânare",
        "en": "Brakes"
    ],
    "service.category.timing_belt": [
        "ro": "Kit Distribuție",
        "en": "Timing Belt"
    ],
    "service.category.tires": [
        "ro": "Anvelope & Roți",
        "en": "Tires & Wheels"
    ],
    "service.category.suspension": [
        "ro": "Direcție & Suspensie",
        "en": "Suspension & Steering"
    ],
    "service.category.general": [
        "ro": "Mentenanță Generală",
        "en": "General Maintenance"
    ],
    "common.car": [
        "ro": "Vehicul",
        "en": "Vehicle"
    ],
    "common.date": [
        "ro": "Dată",
        "en": "Date"
    ],
    "common.details": [
        "ro": "Detalii suplimentare",
        "en": "Details"
    ]
]
