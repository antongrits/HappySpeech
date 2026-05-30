import OSLog
import SwiftUI

// MARK: - PaywallRouter

/// Навигация paywall. В текущем флоу paywall показывается как модальный sheet
/// (за `ParentalGate`) и закрывается через `dismiss`, поэтому Router хранит
/// замыкание закрытия и точку перехода в «Управление подпиской».
///
/// Маршрут управления подпиской открывается системным URL App Store —
/// только из родительского контура, без манипулятивных паттернов.
@MainActor
final class PaywallRouter {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Paywall")

    /// Замыкание закрытия paywall (привязывается View через `dismiss`).
    var dismiss: (() -> Void)?

    init() {}

    /// Закрыть paywall (после успешной покупки / восстановления / по «Закрыть»).
    func close() {
        logger.info("PaywallRouter: close")
        dismiss?()
    }

    /// Открыть системную страницу управления подпиской.
    func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        logger.info("PaywallRouter: open manage subscriptions")
        UIApplication.shared.open(url)
    }
}
