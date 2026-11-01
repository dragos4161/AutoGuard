//
//  NotificationManager.swift
//  AutoGuard
//
//  Manager nativ pentru permisiuni și programarea notificărilor locale iOS (expirări acte & revizii).
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Solicită permisiunea utilizatorului pentru trimiterea notificărilor
    func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Eroare la solicitarea permisiunii de notificări: \(error)")
            return false
        }
    }

    /// Verifică starea curentă a permisiunilor
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Alerte Documente Expirabile (RCA, ITP, Rovinietă)

    /// Programează alerte pentru documentele unui vehicul (la 30, 14, 7, 3 și 1 zi înainte de expirare, la ora 09:00 dimineața)
    func scheduleDocumentReminders(
        for document: VehicleDocument,
        vehicleName: String,
        language: AppLanguage = .system
    ) {
        guard !document.isArchived else {
            cancelDocumentReminders(for: document.id)
            return
        }

        let center = UNUserNotificationCenter.current()
        let docId = document.id.uuidString

        // Eliminăm notificările anterioare pentru acest document
        cancelDocumentReminders(for: document.id)

        let daysIntervals = [30, 14, 7, 3, 1]
        let calendar = Calendar.current
        let isRo = language.isRomanian

        for daysBefore in daysIntervals {
            guard let rawTriggerDate = calendar.date(byAdding: .day, value: -daysBefore, to: document.expirationDate) else {
                continue
            }

            // Setăm ora de livrare la ora 09:00 AM (nu la miezul nopții!)
            var components = calendar.dateComponents([.year, .month, .day], from: rawTriggerDate)
            components.hour = 9
            components.minute = 0

            guard let scheduledDate = calendar.date(from: components), scheduledDate > Date() else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "\(document.type.title) • \(vehicleName)"

            if isRo {
                content.body = daysBefore == 1
                    ? "Atenție! \(document.type.title) pentru \(vehicleName) expiră mâine!"
                    : "Atenție! \(document.type.title) pentru \(vehicleName) expiră în \(daysBefore) zile."
            } else {
                content.body = daysBefore == 1
                    ? "Warning! \(document.type.title) for \(vehicleName) expires tomorrow!"
                    : "Warning! \(document.type.title) for \(vehicleName) expires in \(daysBefore) days."
            }
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(docId)_\(daysBefore)d",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("Eroare la programarea notificării: \(error)")
                }
            }
        }
    }

    /// Anulează alertele programate pentru un document specific (la arhivare sau ștergere)
    func cancelDocumentReminders(for documentId: UUID) {
        let docId = documentId.uuidString
        let intervals = [60, 30, 14, 7, 3, 1]
        let identifiers = intervals.map { "\(docId)_\($0)d" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Alerte Mentenanță & Schimb Ulei

    /// Programează alertă pentru revizie / schimb ulei la ora 09:00 AM cu 14 zile înainte de data limită
    func scheduleMaintenanceReminder(for vehicle: Vehicle, language: AppLanguage = .system) {
        guard let status = vehicle.oilChangeStatus, !status.isOverdue else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "maintenance_\(vehicle.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let calendar = Calendar.current
        guard let alertDate = calendar.date(byAdding: .day, value: -14, to: status.dueDate) else {
            return
        }

        var components = calendar.dateComponents([.year, .month, .day], from: alertDate)
        components.hour = 9
        components.minute = 0

        guard let scheduledDate = calendar.date(from: components), scheduledDate > Date() else {
            return
        }

        let isRo = language.isRomanian
        let content = UNMutableNotificationContent()
        if isRo {
            content.title = "Revizie Ulei • \(vehicle.displayName)"
            content.body = "Se apropie termenul pentru revizia de ulei la \(vehicle.displayName). Planifică vizita în service!"
        } else {
            content.title = "Oil Service • \(vehicle.displayName)"
            content.body = "Oil service due date is approaching for \(vehicle.displayName). Schedule your service visit!"
        }
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Anulează alerta de mentenanță pentru un vehicul
    func cancelMaintenanceReminder(for vehicle: Vehicle) {
        let identifier = "maintenance_\(vehicle.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Resincronizare Globală

    /// Reîmprospătează toate notificările pentru toate vehiculele din garaj (apelat la pornirea aplicației)
    func rescheduleAllReminders(for vehicles: [Vehicle], language: AppLanguage = .system) {
        for vehicle in vehicles {
            scheduleMaintenanceReminder(for: vehicle, language: language)
            for doc in vehicle.documents ?? [] {
                if !doc.isArchived {
                    scheduleDocumentReminders(for: doc, vehicleName: vehicle.displayName, language: language)
                } else {
                    cancelDocumentReminders(for: doc.id)
                }
            }
        }
    }

    // MARK: - Memento Săptămânal Kilometraj

    private let weeklyReminderIdentifier = "weekly_mileage_reminder"

    /// Programează notificarea recurentă săptămânală pentru actualizarea kilometrajului
    func scheduleWeeklyMileageReminder(weekday: Int = 1, hour: Int = 19, minute: Int = 0, language: AppLanguage) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = language.string("notification.weekly_mileage.title")
        content.body = language.string("notification.weekly_mileage.body")
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: weeklyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Eroare la programarea notificării săptămânale: \(error)")
            }
        }
    }

    /// Anulează notificarea recurentă săptămânală
    func cancelWeeklyMileageReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyReminderIdentifier])
    }
}
