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
    @State private var showingPrivacyPolicy: Bool = false

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

                // Secțiunea 0.5: Torpedou Pro (afișat doar când monetizarea este activată)
                if SubscriptionManager.isMonetizationEnabled {
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

                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        HStack {
                            Label("paywall.privacy_policy", systemImage: "hand.raised.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        HStack {
                            Label("paywall.terms_of_use", systemImage: "doc.text")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
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
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicySheetView()
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

// MARK: - Politica de Confidențialitate Integrată (Conform App Store Guidelines)

struct PrivacyPolicySheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.blue.gradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("paywall.privacy_policy")
                                .font(.title3.bold())
                            Text("Torpedou / GloveBox")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 4)

                    policySection(
                        title: AppLanguage.tr(
                            "1. Stocarea Locală pe Dispozitiv (On-Device First)",
                            "1. On-Device Local Storage"
                        ),
                        body: AppLanguage.tr(
                            "Toate datele introduse în aplicația Torpedou (vehicule, numere de înmatriculare, serii de șasiu VIN, termene de expirare RCA/ITP/Rovinietă, revizii, alimentări și fotografii ale documentelor) sunt stocate local pe dispozitivul tău folosind baza de date criptată iOS SwiftData.",
                            "All data entered in Glovebox / Torpedou (vehicles, license plates, VIN numbers, RCA/ITP/Vignette expiration dates, service records, fuel logs, and document photos) is stored locally on your device using the encrypted iOS SwiftData database."
                        )
                    )

                    policySection(
                        title: AppLanguage.tr(
                            "2. Procesarea Imaginilor și Cameră (OCR)",
                            "2. Camera & On-Device Image Processing (OCR)"
                        ),
                        body: AppLanguage.tr(
                            "Scanarea seriei de șasiu (VIN), a numerelor de înmatriculare, a datelor de expirare și a bonurilor de carburant se realizează 100% offline, direct pe procesorul telefonului tău, folosind tehnologia Apple Vision. Imaginile scanate nu sunt trimise către niciun server extern de analiză.",
                            "Scanning VIN numbers, license plates, expiration dates, and fuel receipts is performed 100% offline, directly on your iPhone's processor using Apple Vision technology. Scanned images are never sent to external servers for analysis."
                        )
                    )

                    policySection(
                        title: AppLanguage.tr(
                            "3. Autentificarea cu Apple și Backup în Cloud",
                            "3. Sign in with Apple & Cloud Backup"
                        ),
                        body: AppLanguage.tr(
                            "Autentificarea prin Sign in with Apple este opțională și este utilizată exclusiv pentru identificarea securizată a contului tău în vederea sincronizării și restaurării copiei de siguranță (Cloud Backup). Poți oricând să îți deconectezi sau să îți ștergi complet contul și datele asociate direct din secțiunea Setări -> Cont & Backup Cloud.",
                            "Sign in with Apple is optional and used exclusively to securely identify your account for syncing and restoring your Cloud Backup. You can sign out or permanently delete your account and associated cloud data at any time from Settings -> Account & Cloud Backup."
                        )
                    )

                    policySection(
                        title: AppLanguage.tr(
                            "4. Fără Urmărire Publicitară (Zero Tracking)",
                            "4. Zero Ad Tracking"
                        ),
                        body: AppLanguage.tr(
                            "Aplicația Torpedou nu colectează date de localizare GPS, nu vinde date către terți și nu folosește SDK-uri de publicitate sau profilare comportamentală.",
                            "Glovebox / Torpedou does not collect GPS location data, does not sell data to third parties, and uses no advertising or behavioral profiling SDKs."
                        )
                    )
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("paywall.privacy_policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
