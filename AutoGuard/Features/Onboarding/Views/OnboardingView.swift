//
//  OnboardingView.swift
//  AutoGuard
//
//  Flux de bun venit pentru utilizatorii noi (prezentare beneficii & activare notificări).
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentTab: Int = 0
    @State private var notificationsAuthorized: Bool = false
    @State private var isRequestingNotifications: Bool = false

    private let totalTabs = 3

    var body: some View {
        ZStack {
            // Fundal dinamic și subtil
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: Buton "Omite" (vizibil doar pe primele 2 slide-uri)
                HStack {
                    Spacer()
                    if currentTab < totalTabs - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("onboarding.skip")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    } else {
                        // Spacer pentru păstrarea înălțimii
                        Text(" ")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 12)

                // Slider pagini
                TabView(selection: $currentTab) {
                    slideOneView
                        .tag(0)

                    slideTwoView
                        .tag(1)

                    slideThreeView
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Footer: Indicator pagini + Butoane de acțiune
                VStack(spacing: 16) {
                    // Indicator pagini stil Apple (Pastile dinamice)
                    HStack(spacing: 8) {
                        ForEach(0..<totalTabs, id: \.self) { index in
                            Capsule()
                                .fill(currentTab == index ? Color.blue : Color.secondary.opacity(0.3))
                                .frame(width: currentTab == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentTab)
                        }
                    }
                    .padding(.top, 8)

                    // Buton principal (Continuă / Începe acum)
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()

                        if currentTab < totalTabs - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentTab += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentTab == totalTabs - 1 ? "onboarding.get_started" : "onboarding.next")
                                .font(.headline.bold())
                            if currentTab < totalTabs - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)

                    // Notă de confidențialitate
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("onboarding.privacy_note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .task {
            checkCurrentNotificationStatus()
        }
    }

    private func completeOnboarding() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onFinish()
    }

    private func checkCurrentNotificationStatus() {
        Task {
            let status = await NotificationManager.shared.checkAuthorizationStatus()
            notificationsAuthorized = (status == .authorized || status == .provisional)
        }
    }

    // MARK: - Slide 1: Documente & Siguranță
    private var slideOneView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Ilustrație stivă documente
            ZStack {
                // Card 3 (spate - Rovinietă)
                documentMockupRow(
                    title: AppLanguage.tr("Rovinietă 12 Luni", "12-Month Vignette"),
                    badge: AppLanguage.tr("Activ", "Active"),
                    icon: "road.lanes",
                    color: .purple
                )
                    .scaleEffect(0.88)
                    .offset(y: -24)
                    .opacity(0.5)

                // Card 2 (mijloc - ITP)
                documentMockupRow(
                    title: AppLanguage.tr("Inspecție ITP", "ITP Inspection"),
                    badge: AppLanguage.tr("180 zile", "180 days"),
                    icon: "checkmark.seal.fill",
                    color: .blue
                )
                    .scaleEffect(0.94)
                    .offset(y: -12)
                    .opacity(0.8)

                // Card 1 (față - RCA)
                documentMockupRow(
                    title: AppLanguage.tr("Poliță RCA", "RCA Insurance"),
                    badge: AppLanguage.tr("90 zile", "90 days"),
                    icon: "shield.lefthalf.filled",
                    color: .green
                )
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            }
            .frame(height: 180)
            .padding(.horizontal, 24)

            Spacer()

            // Texte slide 1
            VStack(spacing: 10) {
                Text("onboarding.slide1.tag")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())

                Text("onboarding.slide1.title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("onboarding.slide1.subtitle")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func documentMockupRow(title: String, badge: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(AppLanguage.tr("Copie digitală atașată", "Digital copy attached"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(badge)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Slide 2: Notificări & Alerte
    private var slideTwoView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Ilustrație Clopoțel & Mockup Notificare iOS
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 90, height: 90)

                    Circle()
                        .stroke(Color.orange.opacity(0.25), lineWidth: 2)
                        .frame(width: 110, height: 110)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.multicolor)
                }

                // Mockup Banner Notificare iOS
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(AppLanguage.tr("Torpedou", "Glovebox"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(AppLanguage.tr("acum", "now"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(AppLanguage.tr("Poliță RCA expiră în 7 zile!", "RCA Insurance expires in 7 days!"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text(AppLanguage.tr(
                            "Reînnoiește din timp pentru a evita amenzile rutiere.",
                            "Renew early to avoid traffic fines."
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Texte & Buton Permisiune
            VStack(spacing: 10) {
                Text("onboarding.slide2.tag")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())

                Text("onboarding.slide2.title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("onboarding.slide2.subtitle")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .lineSpacing(4)

                // Buton activare notificări direct din slide
                Button {
                    requestNotifications()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: notificationsAuthorized ? "checkmark.circle.fill" : "bell.fill")
                        Text(notificationsAuthorized ? "onboarding.slide2.notif_enabled" : "onboarding.slide2.enable_notif")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(notificationsAuthorized ? Color.green.opacity(0.15) : Color.blue.opacity(0.12))
                    .foregroundStyle(notificationsAuthorized ? Color.green : Color.blue)
                    .clipShape(Capsule())
                }
                .disabled(notificationsAuthorized || isRequestingNotifications)
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func requestNotifications() {
        isRequestingNotifications = true
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            await MainActor.run {
                notificationsAuthorized = granted
                isRequestingNotifications = false
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(granted ? .success : .warning)
            }
        }
    }

    // MARK: - Slide 3: Revizii & Mentenanță
    private var slideThreeView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Card Mockup Schimb Ulei & Bare Progres
            VStack(spacing: 12) {
                HStack {
                    Label(AppLanguage.tr("Schimb Ulei & Filtre", "Oil & Filters Change"), systemImage: "drop.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)

                    Spacer()

                    Text(AppLanguage.tr("În grafic", "On track"))
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }

                Divider()

                // Bara 1: Kilometri (80%)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(AppLanguage.tr("Kilometraj", "Mileage"))
                            .font(.caption.bold())
                        Spacer()
                        Text("8.000 / 10.000 km (80%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule().fill(Color.orange)
                                .frame(width: geo.size.width * 0.8)
                        }
                    }
                    .frame(height: 8)
                }

                // Bara 2: Timp (50%)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(AppLanguage.tr("Perioadă", "Time Period"))
                            .font(.caption.bold())
                        Spacer()
                        Text(AppLanguage.tr("6 / 12 luni (50%)", "6 / 12 months (50%)"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule().fill(Color.blue)
                                .frame(width: geo.size.width * 0.5)
                        }
                    }
                    .frame(height: 8)
                }

                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(AppLanguage.tr(
                        "Limita de kilometri va fi atinsă prima.",
                        "The mileage limit will be reached first."
                    ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 24)

            Spacer()

            // Texte slide 3
            VStack(spacing: 10) {
                Text("onboarding.slide3.tag")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())

                Text("onboarding.slide3.title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("onboarding.slide3.subtitle")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
