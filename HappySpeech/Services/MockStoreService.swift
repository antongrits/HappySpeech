import Foundation
import Observation
import OSLog
import StoreKit

// MARK: - MockStoreService

/// Детерминированная реализация ``StoreService`` для SwiftUI previews и unit-тестов.
///
/// `StoreKit.Product` нельзя создать вручную без подключённого `.storekit`-конфига,
/// поэтому mock работает на уровне состояния: позволяет задать стартовое право
/// (``PremiumEntitlement``), предзаданный исход покупки (``PurchaseOutcome``) и
/// флаг доступности продуктов. Это покрывает ветвления Interactor/Presenter без
/// реального обращения к App Store.
///
/// Для snapshot-тестов paywall (где нужны видимые карточки) ``products`` остаётся
/// пустым — View отображает graceful-состояние «продукты недоступны», а карточки
/// рендерятся из VM-фолбэка Presenter-а.
@MainActor
@Observable
public final class MockStoreService: StoreService {

    // MARK: - Observable State

    public private(set) var products: [Product] = []
    public var premiumEntitlement: PremiumEntitlement
    public private(set) var isLoading: Bool = false
    public var lastError: StoreError?

    public var isPremium: Bool { premiumEntitlement.isPremium }

    // MARK: - Test Knobs

    /// Исход, который вернёт ``purchase(_:)``.
    public var stubbedPurchaseOutcome: PurchaseOutcome

    /// Право, которое выставляется после успешной покупки.
    public var entitlementAfterPurchase: PremiumEntitlement

    /// Право, которое выставляется после восстановления покупок.
    public var entitlementAfterRestore: PremiumEntitlement?

    /// Должен ли ``loadProducts()`` имитировать недоступность продуктов.
    public var simulateProductsUnavailable: Bool

    // MARK: - Spies

    public private(set) var loadProductsCallCount = 0
    public private(set) var purchaseCallCount = 0
    public private(set) var restoreCallCount = 0
    public private(set) var refreshEntitlementsCallCount = 0
    public private(set) var lastPurchasedProductID: String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Store.Mock")

    // MARK: - Init

    public init(
        premiumEntitlement: PremiumEntitlement = .none,
        stubbedPurchaseOutcome: PurchaseOutcome = .success,
        entitlementAfterPurchase: PremiumEntitlement = .premium(expiresAt: nil),
        entitlementAfterRestore: PremiumEntitlement? = nil,
        simulateProductsUnavailable: Bool = false
    ) {
        self.premiumEntitlement = premiumEntitlement
        self.stubbedPurchaseOutcome = stubbedPurchaseOutcome
        self.entitlementAfterPurchase = entitlementAfterPurchase
        self.entitlementAfterRestore = entitlementAfterRestore
        self.simulateProductsUnavailable = simulateProductsUnavailable
    }

    // MARK: - StoreService

    public func loadProducts() async {
        loadProductsCallCount += 1
        isLoading = true
        defer { isLoading = false }
        if simulateProductsUnavailable {
            lastError = .productsUnavailable
            logger.info("loadProducts (mock): simulating unavailable")
        } else {
            lastError = nil
            logger.info("loadProducts (mock): ok")
        }
    }

    public func purchase(_ product: Product) async -> PurchaseOutcome {
        purchaseCallCount += 1
        lastPurchasedProductID = product.id
        isLoading = true
        defer { isLoading = false }

        switch stubbedPurchaseOutcome {
        case .success:
            premiumEntitlement = entitlementAfterPurchase
            lastError = nil
        case .failed(let error):
            lastError = error
        case .pending, .userCancelled:
            break
        }
        logger.info("purchase (mock): \(product.id, privacy: .public) → \(String(describing: self.stubbedPurchaseOutcome), privacy: .public)")
        return stubbedPurchaseOutcome
    }

    public func restorePurchases() async {
        restoreCallCount += 1
        isLoading = true
        defer { isLoading = false }
        if let restored = entitlementAfterRestore {
            premiumEntitlement = restored
            lastError = nil
        } else {
            lastError = .restoreFailed
        }
        logger.info("restorePurchases (mock): \(String(describing: self.premiumEntitlement), privacy: .public)")
    }

    public func refreshEntitlements() async {
        refreshEntitlementsCallCount += 1
    }
}
