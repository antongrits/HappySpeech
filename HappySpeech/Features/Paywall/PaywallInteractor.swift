import Foundation
import OSLog

// MARK: - PaywallBusinessLogic

@MainActor
protocol PaywallBusinessLogic: AnyObject {
    func loadOfferings(_ request: PaywallModels.LoadOfferings.Request)
    func purchase(_ request: PaywallModels.Purchase.Request)
    func restore(_ request: PaywallModels.Restore.Request)
}

// MARK: - PaywallInteractor

/// Бизнес-логика paywall. Оркеструет ``StoreService``: загрузка продуктов,
/// покупка, восстановление, проверка прав. Не знает о UI — формирование
/// ViewModel делегируется ``PaywallPresenter``.
///
/// Контур: parent / specialist. Вызывается только за `ParentalGate`.
@MainActor
final class PaywallInteractor: PaywallBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any PaywallPresentationLogic)?

    private let storeService: any StoreService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Paywall")

    // MARK: - Init

    init(storeService: any StoreService) {
        self.storeService = storeService
    }

    // MARK: - BusinessLogic

    func loadOfferings(_ request: PaywallModels.LoadOfferings.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await storeService.loadProducts()
            let response = PaywallModels.LoadOfferings.Response(
                products: storeService.products,
                entitlement: storeService.premiumEntitlement,
                productsUnavailable: storeService.products.isEmpty
            )
            logger.info("loadOfferings: products=\(self.storeService.products.count, privacy: .public) premium=\(self.storeService.isPremium, privacy: .public)")
            presenter?.presentLoadOfferings(response)
        }
    }

    func purchase(_ request: PaywallModels.Purchase.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let product = storeService.products.first(where: { $0.id == request.productID }) else {
                logger.error("purchase: product not found \(request.productID, privacy: .public)")
                presenter?.presentPurchase(.init(
                    outcome: .failed(.purchaseFailed),
                    entitlement: storeService.premiumEntitlement
                ))
                return
            }
            let outcome = await storeService.purchase(product)
            logger.info("purchase outcome=\(String(describing: outcome), privacy: .public)")
            presenter?.presentPurchase(.init(
                outcome: outcome,
                entitlement: storeService.premiumEntitlement
            ))
        }
    }

    func restore(_ request: PaywallModels.Restore.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let wasPremium = storeService.isPremium
            await storeService.restorePurchases()
            let nowPremium = storeService.isPremium
            logger.info("restore: was=\(wasPremium, privacy: .public) now=\(nowPremium, privacy: .public)")
            presenter?.presentRestore(.init(
                entitlement: storeService.premiumEntitlement,
                didRestorePremium: nowPremium,
                error: storeService.lastError
            ))
        }
    }
}
