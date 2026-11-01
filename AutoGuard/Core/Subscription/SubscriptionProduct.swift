//
//  SubscriptionProduct.swift
//  AutoGuard
//
//  Definiții pentru nivelurile de abonament, identificatorii de produse StoreKit 2
//  și catalogul de funcționalități Pro.
//

import Foundation
import SwiftUI
import StoreKit

public enum TorpedouProductID: String, CaseIterable {
    case monthly = "com.ascend.AutoGuard.pro.monthly"
    case yearly = "com.ascend.AutoGuard.pro.yearly"
    case lifetime = "com.ascend.AutoGuard.pro.lifetime"

    public var isSubscription: Bool {
        self != .lifetime
    }
}

public enum SubscriptionTier: Equatable {
    case free
    case pro(expirationDate: Date?, isLifetime: Bool)

    public var isPro: Bool {
        if case .pro = self { return true }
        return false
    }

    public var isLifetime: Bool {
        if case .pro(_, let lifetime) = self { return lifetime }
        return false
    }
}

/// Beneficiile exclusive Torpedou Pro prezentate în Paywall
public struct ProFeatureItem: Identifiable {
    public let id = UUID()
    public let icon: String
    public let titleKey: LocalizedStringKey
    public let subtitleKey: LocalizedStringKey
    public let accentColor: Color

    public static let allFeatures: [ProFeatureItem] = [
        ProFeatureItem(
            icon: "car.2.fill",
            titleKey: "paywall.feature.unlimited_vehicles.title",
            subtitleKey: "paywall.feature.unlimited_vehicles.subtitle",
            accentColor: .blue
        ),
        ProFeatureItem(
            icon: "viewfinder.circle.fill",
            titleKey: "paywall.feature.ocr_scanner.title",
            subtitleKey: "paywall.feature.ocr_scanner.subtitle",
            accentColor: .orange
        ),
        ProFeatureItem(
            icon: "doc.richtext.fill",
            titleKey: "paywall.feature.pdf_reports.title",
            subtitleKey: "paywall.feature.pdf_reports.subtitle",
            accentColor: .indigo
        ),
        ProFeatureItem(
            icon: "icloud.and.arrow.up.fill",
            titleKey: "paywall.feature.cloud_backup.title",
            subtitleKey: "paywall.feature.cloud_backup.subtitle",
            accentColor: .teal
        ),
        ProFeatureItem(
            icon: "bell.badge.fill",
            titleKey: "paywall.feature.smart_notifications.title",
            subtitleKey: "paywall.feature.smart_notifications.subtitle",
            accentColor: .red
        ),
        ProFeatureItem(
            icon: "square.grid.2x2.fill",
            titleKey: "paywall.feature.widgets.title",
            subtitleKey: "paywall.feature.widgets.subtitle",
            accentColor: .purple
        )
    ]
}
