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
    @State private var authService = AppleAuthService.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall: Bool = false

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
                // Secțiunea 0: Cont & Backup Cloud
                Section {
                    NavigationLink {
                        AccountSyncSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(authService.currentUser != nil ? Color.blue.gradient : Color.secondary.opacity(0.15).gradient)
                                    .frame(width: 44, height: 44)

                                if let user = authService.currentUser {
                                    Text(user.initials)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                } else {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                if let user = authService.currentUser {
                                    Text(user.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("settings.account.cloud_sync_active")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("settings.account.sign_in_title")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("settings.account.sign_in_subtitle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Secțiunea 0.5: Torpedou Pro
                Section {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(subscriptionManager.isProUser ? Color.orange.opacity(0.15) : Color.blue.opacity(0.12))
                                    .frame(width: 44, height: 44)

                                Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(subscriptionManager.isProUser ? Color.orange : Color.blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(subscriptionManager.isProUser ? "settings.pro.active_title" : "settings.pro.upgrade_title")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if subscriptionManager.isProUser {
                                        Text("PRO")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.18))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(subscriptionManager.isProUser ? "settings.pro.active_subtitle" : "settings.pro.upgrade_subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

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

                // Secțiunea 3: Widget-uri Ecran Principal & Blocat
                Section("settings.section.widgets") {
                    NavigationLink {
                        WidgetPreviewGalleryView()
                    } label: {
                        Label("settings.widgets.preview_and_setup", systemImage: "square.grid.2x2.fill")
                    }
                }

                // Secțiunea 4: Despre aplicație & Confidențialitate
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
                        Text(authService.currentUser != nil ? "settings.storage.cloud_local" : "settings.storage.local")
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
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
