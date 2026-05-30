import Foundation
import StoreKit

// MARK: - Paywall VIP Models
//
// Контур: parent / specialist (за ParentalGate). Терапевтика бесплатна.
// VIP transport: Request / Response / ViewModel.

enum PaywallModels {

    // MARK: - LoadOfferings

    enum LoadOfferings {
        struct Request: Sendable {}
        struct Response: Sendable {
            let products: [Product]
            let entitlement: PremiumEntitlement
            let productsUnavailable: Bool
        }
        struct ViewModel: Sendable {
            let plans: [PlanVM]
            let features: [FeatureVM]
            let isPremium: Bool
            let statusLine: String
            let productsUnavailable: Bool
            let restoreTitle: String
        }
    }

    // MARK: - Purchase

    enum Purchase {
        struct Request: Sendable {
            let productID: String
        }
        struct Response: Sendable {
            let outcome: PurchaseOutcome
            let entitlement: PremiumEntitlement
        }
        struct ViewModel: Sendable {
            /// Сообщение для тоста (успех / pending / ошибка). `nil` — при отмене (без UI).
            let toastMessage: String?
            let toastIsError: Bool
            /// `true`, если покупка успешна и paywall можно закрыть.
            let shouldDismiss: Bool
            let isPremium: Bool
        }
    }

    // MARK: - Restore

    enum Restore {
        struct Request: Sendable {}
        struct Response: Sendable {
            let entitlement: PremiumEntitlement
            let didRestorePremium: Bool
            let error: StoreError?
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let toastIsError: Bool
            let shouldDismiss: Bool
            let isPremium: Bool
        }
    }
}

// MARK: - PlanVM

/// ViewModel одной карточки тарифа в paywall.
struct PlanVM: Sendable, Equatable, Identifiable {
    /// Product ID — используется как идентификатор для покупки.
    let id: String
    let title: String
    let priceText: String          // product.displayPrice
    let periodText: String         // «в месяц» / «в год» / «навсегда»
    let badge: String?             // «Выгодно» для годовой подписки
    let isBestValue: Bool
    /// VoiceOver-метка карточки целиком.
    let accessibilityLabel: String
}

// MARK: - FeatureVM

/// Строка перечня премиум-преимуществ.
struct FeatureVM: Sendable, Equatable, Identifiable {
    let id: String
    let iconName: String
    let title: String
    let subtitle: String
}
