import SwiftUI

// MARK: - HSEmptyStateView
//
// Block O v16 — branded empty state с маскотом Лялей.
//
// Полноэкранный empty-state контейнер: SF Symbol или маскот сверху + заголовок +
// сообщение + опциональный CTA. Маскот анимируется через PhaseAnimator (idle bounce)
// — это даёт «живой» empty state вместо унылого «пусто».
//
// Сохраняет обратную совместимость с прошлым API (icon-based init), плюс новый
// init с `LyalyaState` для kid-контура.
//
// Usage:
// ```swift
// // SF Symbol-based (старый API)
// HSEmptyStateView(
//     icon: "tray",
//     title: "Нет уроков",
//     message: "Добавь свой первый урок",
//     action: { coordinator.addLesson() }
// )
//
// // Маскот-based (новый API, kid)
// HSEmptyStateView(
//     mascot: .thinking,
//     title: "Здесь пока пусто",
//     subtitle: "Давай попробуем что-нибудь весёлое!",
//     actionTitle: "Начать",
//     action: { interactor.start() }
// )
// ```
//
// References:
// - Apple HIG — Empty States
// - kavsoft.dev (mascot-based loading/empty patterns)

@available(iOS 17.0, *)
public struct HSEmptyStateView: View {

    // MARK: - Variant

    public enum IllustrationKind {
        case symbol(String)
        case mascot(LyalyaState)
        /// Тёплая панель с маскотом (v32 design-modernisation, P5).
        /// Используется в kid-контуре вместо серой символьной заглушки.
        /// - Parameters:
        ///   - mascot: Состояние маскота Ляли.
        ///   - tint: Основной тинт-цвет заливки. По умолчанию `Brand.primaryLo`.
        case warmPanel(mascot: LyalyaState, tint: Color = ColorTokens.Brand.primaryLo)
        /// Lottie-анимация из библиотеки `Animations/EmptyStates/` с graceful-fallback
        /// на SF Symbol, если файл отсутствует в бандле.
        case lottie(HSLottieAsset, fallbackSymbol: String)
    }

    // MARK: - Public API

    public let illustration: IllustrationKind
    public let title: String
    public let message: String
    public let action: (() -> Void)?
    public let actionTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init (старое API — SF Symbol)

    public init(
        icon: String,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        actionTitle: String = "Попробовать"
    ) {
        self.illustration = .symbol(icon)
        self.title = title
        self.message = message
        self.action = action
        self.actionTitle = actionTitle
    }

    // MARK: - Init (новое API — Ляля)

    public init(
        mascot: LyalyaState,
        title: String,
        subtitle: String,
        actionTitle: String = "Попробовать",
        action: (() -> Void)? = nil
    ) {
        self.illustration = .mascot(mascot)
        self.title = title
        self.message = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Init (Lottie — анимированная иллюстрация)

    public init(
        lottie: HSLottieAsset,
        fallbackSymbol: String,
        title: String,
        message: String,
        actionTitle: String = String(localized: "empty.custom.cta", defaultValue: "Попробовать"),
        action: (() -> Void)? = nil
    ) {
        self.illustration = .lottie(lottie, fallbackSymbol: fallbackSymbol)
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Init (warmPanel — kid-circuit, v32)

    public init(
        warmPanel mascot: LyalyaState,
        tint: Color = ColorTokens.Brand.primaryLo,
        title: String,
        subtitle: String,
        actionTitle: String = String(localized: "empty.custom.cta", defaultValue: "Попробовать"),
        action: (() -> Void)? = nil
    ) {
        self.illustration = .warmPanel(mascot: mascot, tint: tint)
        self.title = title
        self.message = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        if case .warmPanel(let mascot, let tint) = illustration {
            warmPanelBody(mascot: mascot, tint: tint)
        } else {
            defaultBody
        }
    }

    // MARK: - Default layout (symbol / mascot variants)

    private var defaultBody: some View {
        VStack(spacing: SpacingTokens.large) {
            illustrationView
                .frame(height: 120)

            VStack(spacing: SpacingTokens.small) {
                Text(title)
                    .font(TypographyTokens.headline())
                    .bold()
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(TypographyTokens.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action {
                HSButton(actionTitle, style: .secondary, action: action)
                    .padding(.horizontal, SpacingTokens.xLarge)
            }
        }
        .padding(SpacingTokens.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }

    // MARK: - WarmPanel layout (v32, P5)

    private func warmPanelBody(mascot: LyalyaState, tint: Color) -> some View {
        HSCard(
            style: .gradientTinted(
                LinearGradient(
                    colors: [
                        tint.opacity(0.18),
                        ColorTokens.Brand.butter.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            padding: SpacingTokens.xLarge
        ) {
            VStack(spacing: SpacingTokens.large) {
                // Маскот в тёплом кружке
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 100, height: 100)
                    LyalyaMascotView(state: mascot, size: 80)
                        .modifier(IdleBounceModifier(reduceMotion: reduceMotion))
                }

                VStack(spacing: SpacingTokens.small) {
                    Text(title)
                        .font(TypographyTokens.kidHero(26))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                    Text(message)
                        .font(TypographyTokens.kidBody(16))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }

                if let action {
                    HSButton(actionTitle, style: .primary, action: action)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }

    // MARK: - Illustration

    @ViewBuilder
    private var illustrationView: some View {
        switch illustration {
        case .symbol(let name):
            // v32 P5: upgraded symbol variant — warm circle background (80pt),
            // symbol at 36pt in Brand.primary.opacity(0.7) (not plain .secondary).
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primaryLo.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: name)
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Brand.primary.opacity(0.70))
            }
            .modifier(IdleBounceModifier(reduceMotion: reduceMotion))
        case .mascot(let state):
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.15))
                    .frame(width: 120, height: 120)
                LyalyaMascotView(state: state, size: 96)
            }
            .modifier(IdleBounceModifier(reduceMotion: reduceMotion))
        case .warmPanel:
            // warmPanel имеет собственный layout — эта ветка никогда не вызывается.
            EmptyView()
        case .lottie(let asset, let fallbackSymbol):
            HSLottieContainer(
                asset: asset,
                fallback: AnyView(
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primaryLo.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: fallbackSymbol)
                            .font(.system(size: 36))
                            .foregroundStyle(ColorTokens.Brand.primary.opacity(0.70))
                    }
                    .modifier(IdleBounceModifier(reduceMotion: reduceMotion))
                ),
                size: CGSize(width: 120, height: 120)
            )
        }
    }
}

// MARK: - IdleBounce

@available(iOS 17.0, *)
private struct IdleBounceModifier: ViewModifier {
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator([0, 1, 0]) { view, phase in
                view
                    .scaleEffect(1.0 + CGFloat(phase) * 0.05)
                    .offset(y: -CGFloat(phase) * 6)
            } animation: { _ in
                .easeInOut(duration: 1.4)
            }
        }
    }
}

// MARK: - Convenience Variants (Block J B.10 v18)

/// Готовые варианты empty-state'ов для типичных сценариев приложения.
///
/// Каждый variant содержит русскоязычный заголовок, подсказку и подходящий SF Symbol —
/// не нужно дублировать копирайт в каждой фиче. Variants создаются через
/// статические фабричные методы, чтобы Russian-локализация работала через
/// `String(localized:)` без дублирования строк по проекту.
///
/// ## Пример
/// ```swift
/// HSEmptyStateView.lessons(action: { coordinator.openCatalog() })
/// HSEmptyStateView.tasks()
/// HSEmptyStateView.search(query: "Звук Ы")
/// ```
@available(iOS 17.0, *)
public extension HSEmptyStateView {

    /// Empty-state для списка уроков.
    static func lessons(
        actionTitle: String = String(localized: "empty.lessons.cta", defaultValue: "Открыть каталог"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyNoSessions,
            fallbackSymbol: "book.closed",
            title: String(localized: "empty.lessons.title", defaultValue: "Нет уроков"),
            message: String(localized: "empty.lessons.message", defaultValue: "Добавь первый урок и начни путь"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state для домашних заданий.
    static func tasks(
        actionTitle: String = String(localized: "empty.tasks.cta", defaultValue: "Создать задание"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyNoHistory,
            fallbackSymbol: "list.bullet.clipboard",
            title: String(localized: "empty.tasks.title", defaultValue: "Нет заданий"),
            message: String(localized: "empty.tasks.message", defaultValue: "Сегодня заданий нет — отдыхай!"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state для наград/достижений.
    static func achievements(
        actionTitle: String = String(localized: "empty.achievements.cta", defaultValue: "К занятиям"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyNoRewards,
            fallbackSymbol: "trophy",
            title: String(localized: "empty.achievements.title", defaultValue: "Пока нет наград"),
            message: String(localized: "empty.achievements.message", defaultValue: "Заверши первое занятие, чтобы получить награду"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state для уведомлений.
    static func notifications(
        actionTitle: String = String(localized: "empty.notifications.cta", defaultValue: "К настройкам"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            icon: "bell.slash",
            title: String(localized: "empty.notifications.title", defaultValue: "Уведомлений нет"),
            message: String(localized: "empty.notifications.message", defaultValue: "Здесь будут напоминания и сводки прогресса"),
            action: action,
            actionTitle: actionTitle
        )
    }

    /// Empty-state для пустого результата поиска.
    static func search(
        query: String = "",
        actionTitle: String = String(localized: "empty.search.cta", defaultValue: "Очистить"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        let message = query.isEmpty
            ? String(localized: "empty.search.message.generic", defaultValue: "Попробуй другой запрос")
            : String(localized: "empty.search.message.withQuery", defaultValue: "Ничего не найдено по запросу") + " «\(query)»"
        return HSEmptyStateView(
            lottie: .emptySearchNoResults,
            fallbackSymbol: "magnifyingglass",
            title: String(localized: "empty.search.title", defaultValue: "Ничего не найдено"),
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state для offline-режима.
    static func offline(
        actionTitle: String = String(localized: "empty.offline.cta", defaultValue: "Повторить"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyOffline,
            fallbackSymbol: "wifi.slash",
            title: String(localized: "empty.offline.title", defaultValue: "Нет соединения"),
            message: String(localized: "empty.offline.message", defaultValue: "Занятия доступны офлайн — синхронизация позже"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state при ошибке сети.
    static func networkError(
        actionTitle: String = String(localized: "empty.network.cta", defaultValue: "Повторить"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyNetworkError,
            fallbackSymbol: "exclamationmark.icloud",
            title: String(localized: "empty.network.title", defaultValue: "Не удалось загрузить"),
            message: String(localized: "empty.network.message", defaultValue: "Проверь соединение и попробуй ещё раз"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state «нет детей в профиле семьи».
    static func noChildren(
        actionTitle: String = String(localized: "empty.children.cta", defaultValue: "Добавить ребёнка"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyNoChildren,
            fallbackSymbol: "person.2",
            title: String(localized: "empty.children.title", defaultValue: "Пока нет профилей"),
            message: String(localized: "empty.children.message", defaultValue: "Добавь профиль ребёнка, чтобы начать"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Empty-state «нет завершённых занятий / истории».
    static func history(
        actionTitle: String = String(localized: "empty.history.cta", defaultValue: "К занятиям"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            lottie: .emptyNoHistory,
            fallbackSymbol: "clock.arrow.circlepath",
            title: String(localized: "empty.history.title", defaultValue: "История пуста"),
            message: String(localized: "empty.history.message", defaultValue: "Заверши первое занятие — оно появится здесь"),
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Generic custom empty-state — для случаев без готового варианта.
    static func custom(
        icon: String = "tray",
        title: String,
        message: String,
        actionTitle: String = String(localized: "empty.custom.cta", defaultValue: "Попробовать"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            icon: icon,
            title: title,
            message: message,
            action: action,
            actionTitle: actionTitle
        )
    }
}

// MARK: - Preview

#Preview("HSEmptyStateView SF Symbol") {
    HSEmptyStateView(
        icon: "tray",
        title: "Нет уроков",
        message: "Добавь свой первый урок и начни путь",
        action: { },
        actionTitle: "Добавить урок"
    )
    .background(ColorTokens.Kid.bg)
}

#Preview("HSEmptyStateView Mascot") {
    HSEmptyStateView(
        mascot: .thinking,
        title: "Здесь пока пусто",
        subtitle: "Давай начнём первое занятие!",
        actionTitle: "Начать",
        action: { }
    )
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}

#Preview("HSEmptyStateView WarmPanel") {
    VStack {
        Spacer()
        HSEmptyStateView(
            warmPanel: .happy,
            title: "Здесь пока пусто",
            subtitle: "Пройди первое занятие, чтобы увидеть результаты!",
            actionTitle: "Начать занятие",
            action: { }
        )
        Spacer()
    }
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
