//
//  PaywallView.swift
//  AutoGuard
//
//  Ecranul principal de abonare Torpedou Pro conform standardelor Apple App Store.
//  Design modern cu beneficii vizuale, selector de planuri (Trial, Lunar, Lifetime)
//  și transparență totală privind facturarea.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedProductID: String = TorpedouProductID.yearly.rawValue
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isSuccessPurchased: Bool = false

    private let features = ProFeatureItem.allFeatures

    var body: some View {
        NavigationStack {
            ZStack {
                // Fundal gradient elegant
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Hero
                        heroHeaderView

                        // Lista de beneficii Pro
                        featuresListView

                        // Selector de planuri (StoreKit 2)
                        pricingPlansView

                        // Cronologie Trial Gratuit
                        if selectedProductID == TorpedouProductID.yearly.rawValue {
                            trialTimelineView
                        }

                        // Buton CTA Principal
                        ctaPurchaseButton

                        // Footer legal
                        legalFooterView
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test Pro") {
                        subscriptionManager.toggleProForTesting()
                        if subscriptionManager.isProUser {
                            dismiss()
                        }
                    }
                    .font(.caption2.bold())
                }
                #endif
            }
            .alert("Torpedou Pro", isPresented: $showingAlert) {
                Button("common.ok", role: .cancel) {
                    if subscriptionManager.isProUser {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
            }
        }
    }

    // MARK: - Hero Header
    @ViewBuilder
    private var heroHeaderView: some View {
        VStack(spacing: 10) {
            // Insignă strălucitoare
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.bold())
                Text("TORPEDOU PRO")
                    .font(.caption.bold())
                    .tracking(1.2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.gradient)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)

            Text("paywall.hero.title")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text("paywall.hero.subtitle")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
        }
        .padding(.top, 6)
    }

    // MARK: - Lista de Beneficii
    @ViewBuilder
    private var featuresListView: some View {
        VStack(spacing: 12) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(feature.accentColor.opacity(0.12))
                            .frame(width: 38, height: 38)

                        Image(systemName: feature.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(feature.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.titleKey)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text(feature.subtitleKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Selector de Planuri
    @ViewBuilder
    private var pricingPlansView: some View {
        VStack(spacing: 10) {
            // 1. Plan Anual (Recomandat cu Trial)
            planCardView(
                productID: TorpedouProductID.yearly.rawValue,
                title: "paywall.plan.yearly.title",
                price: subscriptionManager.products.first(where: { $0.id == TorpedouProductID.yearly.rawValue })?.displayPrice ?? "59.99 lei",
                period: "paywall.plan.yearly.period",
                badge: "paywall.plan.yearly.badge",
                subtitle: "paywall.plan.yearly.subtitle"
            )

            // 2. Plan Lunar
            planCardView(
                productID: TorpedouProductID.monthly.rawValue,
                title: "paywall.plan.monthly.title",
                price: subscriptionManager.products.first(where: { $0.id == TorpedouProductID.monthly.rawValue })?.displayPrice ?? "9.99 lei",
                period: "paywall.plan.monthly.period",
                badge: nil,
                subtitle: "paywall.plan.monthly.subtitle"
            )

            // 3. Plan Lifetime (Achiziție Unică)
            planCardView(
                productID: TorpedouProductID.lifetime.rawValue,
                title: "paywall.plan.lifetime.title",
                price: subscriptionManager.products.first(where: { $0.id == TorpedouProductID.lifetime.rawValue })?.displayPrice ?? "149.99 lei",
                period: "paywall.plan.lifetime.period",
                badge: "paywall.plan.lifetime.badge",
                subtitle: "paywall.plan.lifetime.subtitle"
            )
        }
    }

    @ViewBuilder
    private func planCardView(
        productID: String,
        title: LocalizedStringKey,
        price: String,
        period: LocalizedStringKey,
        badge: LocalizedStringKey?,
        subtitle: LocalizedStringKey
    ) -> some View {
        let isSelected = selectedProductID == productID

        Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: 12) {
                // Radio button indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)

                    Text(period)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cronologie Trial Gratuit
    @ViewBuilder
    private var trialTimelineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text("paywall.trial.timeline_title")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                timelineStep(day: "paywall.trial.step1.day", text: "paywall.trial.step1.text")
                timelineStep(day: "paywall.trial.step2.day", text: "paywall.trial.step2.text")
                timelineStep(day: "paywall.trial.step3.day", text: "paywall.trial.step3.text")
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func timelineStep(day: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(day)
                .font(.caption2.bold())
                .frame(width: 55, alignment: .leading)
                .foregroundStyle(.blue)

            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Buton CTA
    @ViewBuilder
    private var ctaPurchaseButton: some View {
        Button {
            executePurchase()
        } label: {
            HStack {
                Spacer()
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(ctaButtonTitle)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .frame(height: 52)
            .background(Color.blue.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .disabled(subscriptionManager.isPurchasing)
        .padding(.top, 4)
    }

    private var ctaButtonTitle: LocalizedStringKey {
        if selectedProductID == TorpedouProductID.yearly.rawValue {
            return "paywall.cta.start_trial"
        } else if selectedProductID == TorpedouProductID.lifetime.rawValue {
            return "paywall.cta.buy_lifetime"
        } else {
            return "paywall.cta.subscribe_monthly"
        }
    }

    // MARK: - Footer Legal & Restaurare
    @ViewBuilder
    private var legalFooterView: some View {
        VStack(spacing: 8) {
            Button {
                executeRestore()
            } label: {
                Text("paywall.restore_purchases")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    Text("paywall.terms_of_use")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .underline()
                }

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://torpedou.app/privacy")!) {
                    Text("paywall.privacy_policy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .underline()
                }
            }
            .padding(.top, 2)

            Text("paywall.legal_disclaimer")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .padding(.top, 6)
    }

    // MARK: - Logica de Achiziție

    private func executePurchase() {
        Task {
            // Găsim produsul StoreKit
            if let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) {
                let success = await subscriptionManager.purchase(product)
                if success {
                    dismiss()
                } else if let error = subscriptionManager.errorMessage {
                    alertMessage = error
                    showingAlert = true
                }
            } else {
                // Dacă produsele din App Store nu sunt încărcate (ex: Simulator fără rețea),
                // activăm modul demonstrativ dacă utilizatorul confirmă
                #if DEBUG
                subscriptionManager.toggleProForTesting()
                dismiss()
                #else
                alertMessage = "Nu s-au putut contacta serverele App Store. Verifică conexiunea la internet."
                showingAlert = true
                #endif
            }
        }
    }

    private func executeRestore() {
        Task {
            let restored = await subscriptionManager.restorePurchases()
            if restored {
                alertMessage = "Abonamentul tău Torpedou Pro a fost restaurat cu succes!"
                showingAlert = true
            } else {
                alertMessage = "Nu au fost găsite achiziții active asociate acestui cont Apple ID."
                showingAlert = true
            }
        }
    }
}
