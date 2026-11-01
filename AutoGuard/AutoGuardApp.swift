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
    @AppStorage("weeklyMileageReminderEnabled") private var weeklyMileageReminderEnabled: Bool = true
    @AppStorage("weeklyMileageReminderWeekday") private var reminderWeekday: Int = 1
    @AppStorage("weeklyMileageReminderHour") private var reminderHour: Int = 19
    @AppStorage("weeklyMileageReminderMinute") private var reminderMinute: Int = 0
    
    // Configurația containerului SwiftData pentru stocarea locală (SQLite pe dispozitiv)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            VehicleDocument.self,
            MileageEntry.self,
            ServiceRecord.self,
            FuelEntry.self
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
            print("AVERTISMENT: Eroare la încărcarea containerului persistent SwiftData: \(error). Se folosește container temporar de siguranță.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallbackContainer = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
                return fallbackContainer
            }
            fatalError("Eroare critică SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Containerul cu TabView nativ (Garaj, Service, Asistent, Setări)
            MainTabView()
                .id(appLanguage)
                .environment(\.locale, appLanguage.locale)
                .task {
                    // Actualizăm widget-urile imediat la lansarea aplicației pentru primul vehicul
                    let context = sharedModelContainer.mainContext
                    if let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()), let first = vehicles.first {
                        WidgetDataManager.shared.updateWidgetData(for: first)
                    }

                    let status = await NotificationManager.shared.checkAuthorizationStatus()
                    if status == .authorized || status == .provisional {
                        if weeklyMileageReminderEnabled {
                            NotificationManager.shared.scheduleWeeklyMileageReminder(
                                weekday: reminderWeekday,
                                hour: reminderHour,
                                minute: reminderMinute,
                                language: appLanguage
                            )
                        }

                        // Reîmprospătăm alertele pentru documente și revizii la pornirea aplicației
                        if let vehicles = try? context.fetch(FetchDescriptor<Vehicle>()) {
                            NotificationManager.shared.rescheduleAllReminders(for: vehicles, language: appLanguage)
                        }
                    }
                }
                .onOpenURL { url in
                    if url.scheme == "torpedou" {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("HandleWidgetDeepLink"),
                            object: url
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
