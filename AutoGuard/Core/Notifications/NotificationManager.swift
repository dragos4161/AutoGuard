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

    /// Programează alerte pentru documentele unui vehicul (la 30 zile, 7 zile și 1 zi înainte)
    func scheduleDocumentReminders(for document: VehicleDocument, vehicleName: String) {
        guard !document.isArchived else { return }

        let center = UNUserNotificationCenter.current()
        let docId = document.id.uuidString

        // Elimină eventualele notificări anterioare pentru acest document
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(docId)_30d",
            "\(docId)_7d",
            "\(docId)_1d"
        ])

        let daysIntervals = [30, 7, 1]
        let calendar = Calendar.current

        for daysBefore in daysIntervals {
            guard let triggerDate = calendar.date(byAdding: .day, value: -daysBefore, to: document.expirationDate),
                  triggerDate > Date() else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "\(document.type.rawValue) - \(vehicleName)"
            content.body = daysBefore == 1
                ? "Atenție! Documentul expiră mâine!"
                : "Atenție! Documentul expiră în \(daysBefore) zile."
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(docId)_\(daysBefore)d",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    /// Programează alertă pentru revizie / schimb ulei
    func scheduleMaintenanceReminder(for vehicle: Vehicle) {
        guard let status = vehicle.oilChangeStatus, !status.isOverdue else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "maintenance_\(vehicle.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let calendar = Calendar.current
        // Alertă cu 14 zile înainte de termenul limită
        guard let alertDate = calendar.date(byAdding: .day, value: -14, to: status.dueDate),
              alertDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Revizie Ulei - \(vehicle.displayName)"
        content.body = "Se apropie termenul pentru schimbul de ulei la \(vehicle.displayName). Planifică vizita în service!"
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
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
