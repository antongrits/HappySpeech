import Foundation

// MARK: - PremiumFeature

/// Возможности, доступные только по premium-праву.
///
/// **Терапевтика всегда бесплатна** (Apple Kids Category). Premium открывает только
/// «надстройки» для родителя / специалиста: углублённую аналитику, экспорт,
/// мульти-профиль, доп. контент-пак и инструменты специалиста.
public enum PremiumFeature: String, Sendable, CaseIterable {

    /// Расширенная аналитика: 90 дней истории вместо 7, графики по фонемам.
    case extendedAnalytics

    /// Экспорт PDF-отчёта для логопеда.
    case pdfExport

    /// Более одного профиля ребёнка (бесплатно — один).
    case multipleChildren

    /// Дополнительный контент-пак (редкие звуки, культурный).
    case advancedContentPack

    /// Еженедельные инсайты от LLM в родительской сводке.
    case weeklyLLMInsights

    /// Инструменты специалиста (продвинутый scoring, batch-экспорт).
    case specialistTools

    /// Человекочитаемое название (рус.) — для paywall-перечня преимуществ.
    public var title: String {
        switch self {
        case .extendedAnalytics:
            return String(localized: "premium.feature.extendedAnalytics.title",
                          defaultValue: "Расширенная аналитика", bundle: .main)
        case .pdfExport:
            return String(localized: "premium.feature.pdfExport.title",
                          defaultValue: "Экспорт PDF для логопеда", bundle: .main)
        case .multipleChildren:
            return String(localized: "premium.feature.multipleChildren.title",
                          defaultValue: "До пяти профилей детей", bundle: .main)
        case .advancedContentPack:
            return String(localized: "premium.feature.advancedContentPack.title",
                          defaultValue: "Дополнительные контент-паки", bundle: .main)
        case .weeklyLLMInsights:
            return String(localized: "premium.feature.weeklyLLMInsights.title",
                          defaultValue: "Еженедельные инсайты", bundle: .main)
        case .specialistTools:
            return String(localized: "premium.feature.specialistTools.title",
                          defaultValue: "Инструменты специалиста", bundle: .main)
        }
    }

    /// Короткое описание выгоды (рус.).
    public var subtitle: String {
        switch self {
        case .extendedAnalytics:
            return String(localized: "premium.feature.extendedAnalytics.subtitle",
                          defaultValue: "90 дней истории и графики по каждому звуку.", bundle: .main)
        case .pdfExport:
            return String(localized: "premium.feature.pdfExport.subtitle",
                          defaultValue: "Готовый отчёт о прогрессе для занятий с логопедом.", bundle: .main)
        case .multipleChildren:
            return String(localized: "premium.feature.multipleChildren.subtitle",
                          defaultValue: "Отдельный прогресс для каждого ребёнка в семье.", bundle: .main)
        case .advancedContentPack:
            return String(localized: "premium.feature.advancedContentPack.subtitle",
                          defaultValue: "Новые упражнения для редких звуков и игр.", bundle: .main)
        case .weeklyLLMInsights:
            return String(localized: "premium.feature.weeklyLLMInsights.subtitle",
                          defaultValue: "Понятные рекомендации по итогам недели.", bundle: .main)
        case .specialistTools:
            return String(localized: "premium.feature.specialistTools.subtitle",
                          defaultValue: "Продвинутая оценка и пакетный экспорт данных.", bundle: .main)
        }
    }

    /// SF Symbol для иконки в paywall-перечне.
    public var iconName: String {
        switch self {
        case .extendedAnalytics:    return "chart.line.uptrend.xyaxis"
        case .pdfExport:            return "doc.richtext"
        case .multipleChildren:     return "person.2.fill"
        case .advancedContentPack:  return "books.vertical.fill"
        case .weeklyLLMInsights:    return "sparkles"
        case .specialistTools:      return "stethoscope"
        }
    }
}

// MARK: - EntitlementGate

/// Чистая (без побочных эффектов) логика проверки прав доступа.
///
/// Принимает текущее ``PremiumEntitlement`` и отвечает, разрешена ли конкретная
/// ``PremiumFeature``. Инкапсулирует правило «advancedContentPack доступен и по
/// отдельной покупке контент-пака, и по полному premium», тогда как остальные
/// фичи требуют именно premium.
///
/// Не обращается к StoreKit напрямую — это делает ``StoreService``. Такое
/// разделение делает gate легко тестируемым.
public struct EntitlementGate: Sendable {

    private let entitlement: PremiumEntitlement

    public init(entitlement: PremiumEntitlement) {
        self.entitlement = entitlement
    }

    /// `true`, если фича доступна при текущем праве.
    public func canAccess(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .advancedContentPack:
            // Доступен либо по полному premium, либо по покупке самого пака.
            if entitlement.isPremium { return true }
            if case .contentPack(let id) = entitlement,
               id == StoreProductID.contentPackAdvanced {
                return true
            }
            return false
        case .extendedAnalytics,
             .pdfExport,
             .multipleChildren,
             .weeklyLLMInsights,
             .specialistTools:
            return entitlement.isPremium
        }
    }

    /// `true`, если фича закрыта при текущем праве (нужен апгрейд).
    public func requiresUpgrade(for feature: PremiumFeature) -> Bool {
        !canAccess(feature)
    }
}
