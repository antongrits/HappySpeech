import Foundation
import Observation
import OSLog
import StoreKit

// MARK: - LiveStoreService

/// Боевая реализация ``StoreService`` на StoreKit 2.
///
/// Полный жизненный цикл:
/// - **Загрузка**: `Product.products(for:)` по ``StoreProductID/all``.
/// - **Покупка**: `product.purchase()` → обработка `.success(.verified/.unverified)` /
///   `.pending` (Ask to Buy) / `.userCancelled`.
/// - **Права**: `Transaction.currentEntitlements` (работает offline из локального receipt).
/// - **Realtime-обновления**: слушаем `Transaction.updates` в `Task`, ссылка хранится
///   и отменяется в `deinit` (предотвращает утечку listener-а).
/// - **Восстановление**: `AppStore.sync()` — только по явному tap «Восстановить покупки».
///
/// Транзакции финализируются `transaction.finish()` после выдачи права —
/// иначе StoreKit будет повторно доставлять их при каждом запуске.
///
/// COPPA / Kids: сервис вызывается только из родительского/специалистского контура
/// за `ParentalGate`. Аналитика — через ``AnalyticsService`` (локальный OSLog, без сторонних SDK).
@MainActor
@Observable
public final class LiveStoreService: StoreService {

    // MARK: - Observable State

    public private(set) var products: [Product] = []
    public private(set) var premiumEntitlement: PremiumEntitlement = .none
    public private(set) var isLoading: Bool = false
    public private(set) var lastError: StoreError?

    public var isPremium: Bool { premiumEntitlement.isPremium }

    // MARK: - Private

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Store")
    private let analytics: (any AnalyticsService)?

    /// Listener `Transaction.updates`. Хранится в Sendable-боксе, чтобы безопасно
    /// отменить в `nonisolated deinit` (Swift 6 strict concurrency).
    private let updatesTaskBox = TransactionListenerBox()

    // MARK: - Init

    public init(analytics: (any AnalyticsService)? = nil) {
        self.analytics = analytics
        // Запускаем слушатель транзакций сразу — он переживёт жизнь сервиса.
        // Ловит покупки, сделанные вне приложения (Ask to Buy approval, renewals, refunds).
        updatesTaskBox.task = makeTransactionListener()
    }

    deinit {
        updatesTaskBox.task?.cancel()
    }

    // MARK: - StoreService

    public func loadProducts() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: StoreProductID.all)
            // Порядок paywall: monthly → yearly → lifetime (как в StoreProductID.premiumTier).
            products = loaded.sorted { lhs, rhs in
                order(of: lhs.id) < order(of: rhs.id)
            }
            logger.info("loadProducts: \(self.products.count, privacy: .public) products loaded")
            if products.isEmpty {
                lastError = .productsUnavailable
            }
            await refreshEntitlements()
        } catch {
            logger.error("loadProducts failed: \(error.localizedDescription, privacy: .public)")
            lastError = .productsUnavailable
        }
    }

    public func purchase(_ product: Product) async -> PurchaseOutcome {
        guard AppStore.canMakePayments else {
            logger.warning("purchase blocked: payments not allowed on device")
            lastError = .notAllowed
            return .failed(.notAllowed)
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        analytics?.track(event: AnalyticsEvent(
            name: "paywall_purchase_started",
            parameters: ["product_id": product.id]
        ))

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await applyAndFinish(transaction)
                    logger.info("purchase verified: \(product.id, privacy: .public)")
                    analytics?.track(event: AnalyticsEvent(
                        name: "paywall_purchase_success",
                        parameters: ["product_id": product.id]
                    ))
                    return .success
                case .unverified(let transaction, let error):
                    // Подпись JWS не прошла проверку — не выдаём право.
                    logger.error("purchase unverified: \(product.id, privacy: .public) — \(error.localizedDescription, privacy: .public)")
                    await transaction.finish()
                    lastError = .verificationFailed
                    return .failed(.verificationFailed)
                }
            case .pending:
                // Ask to Buy: ждём одобрения родителя через Family Sharing.
                logger.info("purchase pending (Ask to Buy): \(product.id, privacy: .public)")
                analytics?.track(event: AnalyticsEvent(
                    name: "paywall_purchase_pending",
                    parameters: ["product_id": product.id]
                ))
                return .pending
            case .userCancelled:
                logger.info("purchase cancelled by user: \(product.id, privacy: .public)")
                return .userCancelled
            @unknown default:
                logger.error("purchase unknown result: \(product.id, privacy: .public)")
                lastError = .purchaseFailed
                return .failed(.purchaseFailed)
            }
        } catch {
            logger.error("purchase threw: \(error.localizedDescription, privacy: .public)")
            lastError = .purchaseFailed
            return .failed(.purchaseFailed)
        }
    }

    public func restorePurchases() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            logger.info("restorePurchases: synced, entitlement=\(String(describing: self.premiumEntitlement), privacy: .public)")
            analytics?.track(event: AnalyticsEvent(name: "paywall_restore_done"))
        } catch {
            logger.error("restorePurchases failed: \(error.localizedDescription, privacy: .public)")
            lastError = .restoreFailed
        }
    }

    public func refreshEntitlements() async {
        var resolved: PremiumEntitlement = .none

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Игнорируем отозванные (refund) транзакции.
            if transaction.revocationDate != nil { continue }

            switch transaction.productID {
            case StoreProductID.premiumLifetime:
                // Lifetime перебивает любые подписки.
                resolved = .premium(expiresAt: nil)
            case StoreProductID.premiumMonthly, StoreProductID.premiumYearly:
                // Подписка активна, если ещё не истекла (или дата неизвестна).
                if let expiry = transaction.expirationDate {
                    if expiry > Date(), !resolved.isLifetime {
                        resolved = .premium(expiresAt: expiry)
                    }
                } else if !resolved.isLifetime {
                    resolved = .premium(expiresAt: nil)
                }
            case StoreProductID.contentPackAdvanced:
                // Контент-пак не повышает до premium, но фиксируем право,
                // если ещё не выдан полный premium.
                if case .none = resolved {
                    resolved = .contentPack(id: transaction.productID)
                }
            default:
                break
            }
        }

        premiumEntitlement = resolved
        logger.info("refreshEntitlements → \(String(describing: self.premiumEntitlement), privacy: .public)")
    }

    // MARK: - Private Helpers

    private func makeTransactionListener() -> Task<Void, Never> {
        let logger = self.logger
        return Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else {
                    logger.error("Transaction.updates delivered an unverified transaction — ignored")
                    continue
                }
                await self.applyAndFinish(transaction)
            }
        }
    }

    /// Финализирует транзакцию и пересчитывает права.
    private func applyAndFinish(_ transaction: Transaction) async {
        await transaction.finish()
        await refreshEntitlements()
    }

    /// Сортировочный приоритет продукта для отображения в paywall.
    private func order(of productID: String) -> Int {
        switch productID {
        case StoreProductID.premiumMonthly:  return 0
        case StoreProductID.premiumYearly:   return 1
        case StoreProductID.premiumLifetime: return 2
        case StoreProductID.contentPackAdvanced: return 3
        default: return 99
        }
    }
}

// MARK: - TransactionListenerBox

/// Sendable-контейнер для `Task` слушателя транзакций. Позволяет хранить ссылку
/// вне main-actor изоляции и безопасно отменять её из `nonisolated deinit`
/// при strict concurrency Swift 6.
private final class TransactionListenerBox: @unchecked Sendable {
    var task: Task<Void, Never>?
}
