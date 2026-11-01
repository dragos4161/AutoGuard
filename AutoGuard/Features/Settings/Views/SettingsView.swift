//
//  SettingsView.swift
//  AutoGuard
//
//  Ecranul de setări ale aplicației: selecție limbă, notificări kilometraj și preferințe.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    // Memento Săptămânal Kilometraj
    @AppStorage("weeklyMileageReminderEnabled") private var weeklyMileageReminderEnabled: Bool = true
    @AppStorage("weeklyMileageReminderWeekday") private var reminderWeekday: Int = 1 // 1 = Duminică
    @AppStorage("weeklyMileageReminderHour") private var reminderHour: Int = 19
    @AppStorage("weeklyMileageReminderMinute") private var reminderMinute: Int = 0

    @State private var showingPermissionAlert: Bool = false
    @State private var showingOnboardingTour: Bool = false

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = components.hour ?? 19
                reminderMinute = components.minute ?? 0
                rescheduleIfNeeded()
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Limbă & Regional
                Section("settings.section.language") {
                    Picker("settings.language", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .onChange(of: appLanguage) { _, newLang in
                        if weeklyMileageReminderEnabled {
                            NotificationManager.shared.scheduleWeeklyMileageReminder(
                                weekday: reminderWeekday,
                                hour: reminderHour,
                                minute: reminderMinute,
                                language: newLang
                            )
                        }
                    }
                }

                // Secțiunea 2: Notificări & Memento Săptămânal
                Section {
                    Toggle("settings.notifications.weekly_mileage", isOn: $weeklyMileageReminderEnabled)
                        .onChange(of: weeklyMileageReminderEnabled) { _, isEnabled in
                            handleToggleChanged(isEnabled: isEnabled)
                        }

                    if weeklyMileageReminderEnabled {
                        Picker("settings.notifications.day", selection: $reminderWeekday) {
                            Text("settings.notifications.day.friday").tag(6)
                            Text("settings.notifications.day.saturday").tag(7)
                            Text("settings.notifications.day.sunday").tag(1)
                        }
                        .onChange(of: reminderWeekday) { _, _ in
                            rescheduleIfNeeded()
                        }

                        DatePicker(
                            "settings.notifications.time",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("settings.section.notifications")
                } footer: {
                    Text("settings.notifications.weekly_mileage_footer")
                }

                // Secțiunea 3: Despre aplicație & Confidențialitate
                Section("settings.section.about") {
                    Button {
                        showingOnboardingTour = true
                    } label: {
                        HStack {
                            Label("settings.about.view_tour", systemImage: "sparkles.tv")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("settings.app_name")
                        Spacer()
                        Text("Torpedou / GloveBox")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text("1.0 (Build 1)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("settings.storage")
                        Spacer()
                        Text("settings.storage.local")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings.title")
            .onAppear {
                if weeklyMileageReminderEnabled {
                    rescheduleIfNeeded()
                }
            }
            .alert("settings.notifications.permission_alert_title", isPresented: $showingPermissionAlert) {
                Button("settings.notifications.open_settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.notifications.permission_alert_message")
            }
            .sheet(isPresented: $showingOnboardingTour) {
                OnboardingView(onFinish: {
                    showingOnboardingTour = false
                })
            }
        }
    }

    private func handleToggleChanged(isEnabled: Bool) {
        if isEnabled {
            Task {
                let status = await NotificationManager.shared.checkAuthorizationStatus()
                if status == .notDetermined {
                    let granted = await NotificationManager.shared.requestAuthorization()
                    if granted {
                        NotificationManager.shared.scheduleWeeklyMileageReminder(
                            weekday: reminderWeekday,
                            hour: reminderHour,
                            minute: reminderMinute,
                            language: appLanguage
                        )
                    } else {
                        weeklyMileageReminderEnabled = false
                    }
                } else if status == .denied {
                    weeklyMileageReminderEnabled = false
                    showingPermissionAlert = true
                } else {
                    NotificationManager.shared.scheduleWeeklyMileageReminder(
                        weekday: reminderWeekday,
                        hour: reminderHour,
                        minute: reminderMinute,
                        language: appLanguage
                    )
                }
            }
        } else {
            NotificationManager.shared.cancelWeeklyMileageReminder()
        }
    }

    private func rescheduleIfNeeded() {
        guard weeklyMileageReminderEnabled else { return }
        Task {
            let status = await NotificationManager.shared.checkAuthorizationStatus()
            if status == .authorized || status == .provisional {
                NotificationManager.shared.scheduleWeeklyMileageReminder(
                    weekday: reminderWeekday,
                    hour: reminderHour,
                    minute: reminderMinute,
                    language: appLanguage
                )
            }
        }
    }
}

#Preview {
    SettingsView()
}
