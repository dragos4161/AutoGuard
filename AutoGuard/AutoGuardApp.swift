//
//  AutoGuardApp.swift
//  AutoGuard
//
//  Punctul de intrare în aplicație (în Flutter: echivalentul funcției `main()` și a widgetului `MaterialApp`).
//

import SwiftUI
import SwiftData

@main
struct AutoGuardApp: App {
    
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system
    
    // Configurația containerului SwiftData pentru stocarea locală (SQLite pe dispozitiv)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            VehicleDocument.self
        ])

        // Folosim `cloudKitDatabase: .none` pentru dezvoltare locală și Previews rapide în Simulator
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Eroare la crearea ModelContainer SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Ecranul inițial cu care pornește aplicația
            GarageView()
                .id(appLanguage)
                .environment(\.locale, appLanguage.locale)
        }
        .modelContainer(sharedModelContainer)
    }
}
