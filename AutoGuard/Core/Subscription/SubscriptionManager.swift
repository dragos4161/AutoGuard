//
//  SubscriptionManager.swift
//  AutoGuard
//
//  Managerul principal de monetizare și achiziții StoreKit 2.
//  Ascultă actualizările de tranzacții în timp real, verifică semnăturile Apple
//  și gestionează starea de abonat Pro pe toate ecranele.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
@Observable
public final class SubscriptionManager {
    public static let shared = SubscriptionManager()

    public private(set) var products: [Product] = []
    public private(set) var tier: SubscriptionTier = .free
    public private(set) var isLoading: Bool = false
    public private(set) var isPurchasing: Bool = false
    public private(set) var errorMessage: String?

    // Stocare locală de rezervă pentru acces offline rapid
    private let proCacheKey = "torpedou_is_pro_active"
    private var updateListenerTask: Task<Void, Never>?

    private init() {
        // Citire stare cached la pornire
        let cachedPro = UserDefaults.standard.bool(forKey: proCacheKey)
        if cachedPro {
            self.tier = .pro(expirationDate: nil, isLifetime: false)
        }

        // Pornim ascultătorul de tranzacții din fundal (StoreKit 2)
        updateListenerTask = listenForTransactionUpdates()

        Task {
            await loadProducts()
            await updatePurchasedEntitlements()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    public var isProUser: Bool {
        tier.isPro
    }

    // MARK: - Încărcare Catalog Produse

    public func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            let productIDs = TorpedouProductID.allCases.map(\.rawValue)
            let fetchedProducts = try await Product.products(for: productIDs)

            // Sortăm produsele: Anual primul (recomandat), apoi Lunar, apoi Lifetime
            self.products = fetchedProducts.sorted { p1, p2 in
                if p1.id == TorpedouProductID.yearly.rawValue { return true }
                if p2.id == TorpedouProductID.yearly.rawValue { return false }
                if p1.id == TorpedouProductID.monthly.rawValue { return true }
                return false
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Achiziție Produs

    public func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedEntitlements()
                await transaction.finish()
                isPurchasing = false
                return true

            case .userCancelled:
                isPurchasing = false
                return false

            case .pending:
                // Tranzacție în așteptare (ex: Ask to Buy pentru minori)
                isPurchasing = false
                errorMessage = "Tranzacția este în așteptarea aprobării familiei."
                return false

            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            isPurchasing = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restaurare Achiziții

    public func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedEntitlements()
            isLoading = false
            return tier.isPro
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Verificare Drepturi Active (Entitlements)

    public func updatePurchasedEntitlements() async {
        var foundPro = false
        var isLifetime = false
        var latestExpiration: Date? = nil

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.revocationDate == nil {
                    if transaction.productID == TorpedouProductID.lifetime.rawValue {
                        foundPro = true
                        isLifetime = true
                        break
                    } else if transaction.productID == TorpedouProductID.yearly.rawValue ||
                                transaction.productID == TorpedouProductID.monthly.rawValue {
                        foundPro = true
                        if let exp = transaction.expirationDate {
                            if latestExpiration == nil || exp > latestExpiration! {
                                latestExpiration = exp
                            }
                        }
                    }
                }
            } catch {
                // Tranzacție invalidă sau neautentică
            }
        }

        if foundPro {
            self.tier = .pro(expirationDate: latestExpiration, isLifetime: isLifetime)
            UserDefaults.standard.set(true, forKey: proCacheKey)
        } else {
            self.tier = .free
            UserDefaults.standard.set(false, forKey: proCacheKey)
        }
    }

    // MARK: - Listener Tranzacții în Timp Real

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedEntitlements()
                    await transaction.finish()
                } catch {
                    // Tranzacție invalidă
                }
            }
        }
    }

    // MARK: - Verificare Criptografică a Tranzacției

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Debug / Simulator Toggle (pentru testare fără cont de sandbox)

    #if DEBUG
    public func toggleProForTesting() {
        if isProUser {
            tier = .free
            UserDefaults.standard.set(false, forKey: proCacheKey)
        } else {
            tier = .pro(expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()), isLifetime: false)
            UserDefaults.standard.set(true, forKey: proCacheKey)
        }
    }
    #endif
}
