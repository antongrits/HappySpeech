import Foundation
import Observation
import StoreKit

// MARK: - PaywallPresentationLogic

@MainActor
protocol PaywallPresentationLogic: AnyObject {
    func presentLoadOfferings(_ response: PaywallModels.LoadOfferings.Response)
    func presentPurchase(_ response: PaywallModels.Purchase.Response)
    func presentRestore(_ response: PaywallModels.Restore.Response)
}

// MARK: - PaywallDisplayLogic

@MainActor
protocol PaywallDisplayLogic: AnyObject {
    func displayLoadOfferings(_ viewModel: PaywallModels.LoadOfferings.ViewModel)
    func displayPurchase(_ viewModel: PaywallModels.Purchase.ViewModel)
    func displayRestore(_ viewModel: PaywallModels.Restore.ViewModel)
}

// MARK: - PaywallPresenter

/// Форматирует Response → ViewModel: маппит `StoreKit.Product` в ``PlanVM``,
/// собирает перечень ``PremiumFeature`` в ``FeatureVM``, формирует тосты и
/// решает, нужно ли закрыть paywall после покупки/восстановления.
@MainActor
final class PaywallPresenter: PaywallPresentationLogic {

    weak var display: (any PaywallDisplayLogic)?

    // MARK: - PresentationLogic

    func presentLoadOfferings(_ response: PaywallModels.LoadOfferings.Response) {
        let plans = response.products.compactMap(Self.makePlanVM)
        let features = PremiumFeature.allCases.map { feature in
            FeatureVM(
                id: feature.rawValue,
                iconName: feature.iconName,
                title: feature.title,
                subtitle: feature.subtitle
            )
        }
        display?.displayLoadOfferings(.init(
            plans: plans,
            features: features,
            isPremium: response.entitlement.isPremium,
            statusLine: Self.statusLine(for: response.entitlement),
            productsUnavailable: response.productsUnavailable,
            restoreTitle: String(localized: "paywall.restore.cta")
        ))
    }

    func presentPurchase(_ response: PaywallModels.Purchase.Response) {
        let vm: PaywallModels.Purchase.ViewModel
        switch response.outcome {
        case .success:
            vm = .init(
                toastMessage: String(localized: "paywall.toast.success"),
                toastIsError: false,
                shouldDismiss: true,
                isPremium: response.entitlement.isPremium
            )
        case .pending:
            vm = .init(
                toastMessage: String(localized: "paywall.toast.pending"),
                toastIsError: false,
                shouldDismiss: false,
                isPremium: response.entitlement.isPremium
            )
        case .userCancelled:
            // Отмена — без тоста и без закрытия.
            vm = .init(
                toastMessage: nil,
                toastIsError: false,
                shouldDismiss: false,
                isPremium: response.entitlement.isPremium
            )
        case .failed(let error):
            vm = .init(
                toastMessage: error.errorDescription ?? String(localized: "paywall.toast.error"),
                toastIsError: true,
                shouldDismiss: false,
                isPremium: response.entitlement.isPremium
            )
        }
        display?.displayPurchase(vm)
    }

    func presentRestore(_ response: PaywallModels.Restore.Response) {
        if response.didRestorePremium {
            display?.displayRestore(.init(
                toastMessage: String(localized: "paywall.toast.restoreSuccess"),
                toastIsError: false,
                shouldDismiss: true,
                isPremium: true
            ))
        } else if let error = response.error {
            display?.displayRestore(.init(
                toastMessage: error.errorDescription ?? String(localized: "paywall.toast.error"),
                toastIsError: true,
                shouldDismiss: false,
                isPremium: response.entitlement.isPremium
            ))
        } else {
            display?.displayRestore(.init(
                toastMessage: String(localized: "paywall.toast.restoreNothing"),
                toastIsError: false,
                shouldDismiss: false,
                isPremium: response.entitlement.isPremium
            ))
        }
    }

    // MARK: - Mapping Helpers

    /// Маппит `StoreKit.Product` в ``PlanVM`` для paywall-карточки.
    /// `nil`, если продукт не относится к premium-тиру (например, контент-пак —
    /// он не показывается отдельной карточкой в этом paywall).
    static func makePlanVM(_ product: Product) -> PlanVM? {
        guard StoreProductID.premiumTier.contains(product.id) else { return nil }

        let period = periodText(for: product)
        let badge: String?
        let isBest: Bool
        switch product.id {
        case StoreProductID.premiumYearly:
            badge = String(localized: "paywall.badge.bestValue")
            isBest = true
        case StoreProductID.premiumLifetime:
            badge = String(localized: "paywall.badge.lifetime")
            isBest = false
        default:
            badge = nil
            isBest = false
        }

        let title = planTitle(for: product)
        let a11y = String(
            format: String(localized: "paywall.plan.a11y"),
            title, product.displayPrice, period
        )

        return PlanVM(
            id: product.id,
            title: title,
            priceText: product.displayPrice,
            periodText: period,
            badge: badge,
            isBestValue: isBest,
            accessibilityLabel: a11y
        )
    }

    private static func planTitle(for product: Product) -> String {
        switch product.id {
        case StoreProductID.premiumMonthly:
            return String(localized: "paywall.plan.monthly.title")
        case StoreProductID.premiumYearly:
            return String(localized: "paywall.plan.yearly.title")
        case StoreProductID.premiumLifetime:
            return String(localized: "paywall.plan.lifetime.title")
        default:
            return product.displayName
        }
    }

    private static func periodText(for product: Product) -> String {
        switch product.id {
        case StoreProductID.premiumMonthly:
            return String(localized: "paywall.period.monthly")
        case StoreProductID.premiumYearly:
            return String(localized: "paywall.period.yearly")
        case StoreProductID.premiumLifetime:
            return String(localized: "paywall.period.lifetime")
        default:
            return ""
        }
    }

    private static func statusLine(for entitlement: PremiumEntitlement) -> String {
        switch entitlement {
        case .none, .contentPack:
            return String(localized: "paywall.status.free")
        case .premium(let expiresAt):
            if expiresAt == nil {
                return String(localized: "paywall.status.lifetime")
            }
            return String(localized: "paywall.status.active")
        }
    }
}

// MARK: - PaywallDisplay (Observable Store)

@Observable
@MainActor
final class PaywallDisplay: PaywallDisplayLogic {

    var plans: [PlanVM] = []
    var features: [FeatureVM] = []
    var isPremium: Bool = false
    var statusLine: String = ""
    var productsUnavailable: Bool = false
    var restoreTitle: String = String(localized: "paywall.restore.cta")

    var toastMessage: String?
    var toastIsError: Bool = false
    var shouldDismiss: Bool = false

    func displayLoadOfferings(_ viewModel: PaywallModels.LoadOfferings.ViewModel) {
        plans = viewModel.plans
        features = viewModel.features
        isPremium = viewModel.isPremium
        statusLine = viewModel.statusLine
        productsUnavailable = viewModel.productsUnavailable
        restoreTitle = viewModel.restoreTitle
    }

    func displayPurchase(_ viewModel: PaywallModels.Purchase.ViewModel) {
        if let message = viewModel.toastMessage {
            toastMessage = message
            toastIsError = viewModel.toastIsError
        }
        isPremium = viewModel.isPremium
        if viewModel.shouldDismiss {
            shouldDismiss = true
        }
    }

    func displayRestore(_ viewModel: PaywallModels.Restore.ViewModel) {
        toastMessage = viewModel.toastMessage
        toastIsError = viewModel.toastIsError
        isPremium = viewModel.isPremium
        if viewModel.shouldDismiss {
            shouldDismiss = true
        }
    }

    func clearToast() {
        toastMessage = nil
        toastIsError = false
    }
}
