import Foundation
import StoreKit

// MARK: - StoreService

/// Протокол монетизации на базе StoreKit 2.
///
/// `StoreService` — единая точка входа для покупок и проверки прав доступа (entitlements).
/// Используется **только** в родительском / специалистском контуре за `ParentalGate`
/// (Apple Kids Category — App Review 1.3 / 5.1.4). Детский контур к нему не обращается.
///
/// Терапевтический контент **всегда бесплатен**. Premium открывает только
/// аналитику, экспорт, дополнительные профили детей, доп. контент-паки и
/// инструменты специалиста — см. ``PremiumFeature``.
///
/// Реализации:
/// - ``LiveStoreService`` — реальный StoreKit 2 (`Product.products(for:)`, `purchase()`,
///   `Transaction.currentEntitlements`, `Transaction.updates`, `AppStore.sync()`).
/// - ``MockStoreService`` — детерминированная реализация для preview / unit-тестов.
///
/// ## See Also
/// - ``PremiumEntitlement``
/// - ``EntitlementGate``
/// - ``PremiumFeature``
@MainActor
public protocol StoreService: AnyObject {

    /// Загруженные из App Store продукты (после ``loadProducts()``).
    /// Пустой массив, если магазин недоступен или `.storekit`-конфиг не подключён.
    var products: [Product] { get }

    /// Текущее право доступа пользователя. Обновляется из `Transaction.currentEntitlements`
    /// при старте и из `Transaction.updates` в реальном времени.
    var premiumEntitlement: PremiumEntitlement { get }

    /// `true`, если у пользователя есть активная premium-подписка / lifetime.
    /// Удобный фасад над ``premiumEntitlement``.
    var isPremium: Bool { get }

    /// Идёт загрузка продуктов или обработка покупки.
    var isLoading: Bool { get }

    /// Последняя пользовательская ошибка (для отображения в UI). `nil`, если ошибок нет.
    var lastError: StoreError? { get }

    /// Загружает продукты из App Store по известным product ID.
    /// Без подключённого `.storekit`-конфига в симуляторе возвращает пустой список.
    func loadProducts() async

    /// Совершает покупку продукта. Обрабатывает все исходы StoreKit 2:
    /// verified / unverified / pending (Ask to Buy) / userCancelled.
    /// - Returns: результат покупки для отображения соответствующего UI.
    func purchase(_ product: Product) async -> PurchaseOutcome

    /// Восстанавливает покупки через `AppStore.sync()`.
    /// Вызывается только по явному tap «Восстановить покупки».
    func restorePurchases() async

    /// Пересчитывает ``premiumEntitlement`` из `Transaction.currentEntitlements`.
    /// Безопасно вызывать многократно (например, при возврате приложения на передний план).
    func refreshEntitlements() async
}

// MARK: - PremiumEntitlement

/// Право доступа пользователя к premium-возможностям.
public enum PremiumEntitlement: Sendable, Equatable {

    /// Нет активных прав — доступен только бесплатный (терапевтический) функционал.
    case none

    /// Активная premium-подписка / lifetime.
    /// - Parameter expiresAt: дата окончания. `nil` означает lifetime (бессрочно).
    case premium(expiresAt: Date?)

    /// Куплен отдельный контент-пак.
    /// - Parameter id: идентификатор пака (product ID).
    case contentPack(id: String)

    /// `true`, если право даёт полный premium-доступ (подписка/lifetime).
    public var isPremium: Bool {
        if case .premium = self { return true }
        return false
    }

    /// `true` для lifetime (premium без даты окончания).
    public var isLifetime: Bool {
        if case .premium(let expiresAt) = self { return expiresAt == nil }
        return false
    }
}

// MARK: - PurchaseOutcome

/// Исход покупки для UI-обработки.
public enum PurchaseOutcome: Sendable, Equatable {

    /// Покупка успешна и верифицирована, право выдано.
    case success

    /// Покупка в ожидании (Ask to Buy — родитель должен подтвердить).
    /// UI показывает дружелюбный тост-объяснение.
    case pending

    /// Пользователь отменил покупку. UI не показывает ошибку.
    case userCancelled

    /// Покупка не удалась с пользовательской ошибкой.
    case failed(StoreError)
}

// MARK: - StoreError

/// Пользовательские ошибки магазина с локализованными сообщениями (рус.).
public enum StoreError: LocalizedError, Sendable, Equatable {

    /// Продукты не загрузились (нет сети / магазин недоступен / конфиг не подключён).
    case productsUnavailable

    /// Транзакция не прошла верификацию StoreKit (`.unverified`).
    case verificationFailed

    /// Покупка не удалась по системной причине.
    case purchaseFailed

    /// Восстановление покупок не удалось.
    case restoreFailed

    /// Покупки запрещены на устройстве (родительский контроль / ограничения).
    case notAllowed

    public var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return String(localized: "paywall.error.productsUnavailable",
                          defaultValue: "Не удалось загрузить варианты подписки. Проверьте соединение и попробуйте позже.",
                          bundle: .main)
        case .verificationFailed:
            return String(localized: "paywall.error.verificationFailed",
                          defaultValue: "Не удалось подтвердить покупку у App Store. Попробуйте ещё раз.",
                          bundle: .main)
        case .purchaseFailed:
            return String(localized: "paywall.error.purchaseFailed",
                          defaultValue: "Покупка не завершилась. Повторите попытку позже.",
                          bundle: .main)
        case .restoreFailed:
            return String(localized: "paywall.error.restoreFailed",
                          defaultValue: "Не удалось восстановить покупки. Проверьте, что вы вошли с тем же Apple ID.",
                          bundle: .main)
        case .notAllowed:
            return String(localized: "paywall.error.notAllowed",
                          defaultValue: "Покупки недоступны на этом устройстве.",
                          bundle: .main)
        }
    }
}

// MARK: - StoreProductID

/// Известные идентификаторы продуктов App Store Connect.
public enum StoreProductID {
    public static let premiumMonthly  = "ru.happyspeech.premium.monthly"
    public static let premiumYearly   = "ru.happyspeech.premium.yearly"
    public static let premiumLifetime = "ru.happyspeech.premium.lifetime"
    public static let contentPackAdvanced = "ru.happyspeech.contentpack.advanced"

    /// Идентификаторы подписок / lifetime — три варианта в paywall.
    public static let premiumTier: [String] = [premiumMonthly, premiumYearly, premiumLifetime]

    /// Все продаваемые продукты (подписки + контент-пак).
    public static let all: [String] = premiumTier + [contentPackAdvanced]
}
