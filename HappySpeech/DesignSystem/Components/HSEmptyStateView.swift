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

    // MARK: - Body

    public var body: some View {
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

    // MARK: - Illustration

    @ViewBuilder
    private var illustrationView: some View {
        switch illustration {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .modifier(IdleBounceModifier(reduceMotion: reduceMotion))
        case .mascot(let state):
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.15))
                    .frame(width: 120, height: 120)
                LyalyaMascotView(state: state, size: 96)
            }
            .modifier(IdleBounceModifier(reduceMotion: reduceMotion))
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
            icon: "book.closed",
            title: String(localized: "empty.lessons.title", defaultValue: "Нет уроков"),
            message: String(localized: "empty.lessons.message", defaultValue: "Добавь первый урок и начни путь"),
            action: action,
            actionTitle: actionTitle
        )
    }

    /// Empty-state для домашних заданий.
    static func tasks(
        actionTitle: String = String(localized: "empty.tasks.cta", defaultValue: "Создать задание"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            icon: "list.bullet.clipboard",
            title: String(localized: "empty.tasks.title", defaultValue: "Нет заданий"),
            message: String(localized: "empty.tasks.message", defaultValue: "Сегодня заданий нет — отдыхай!"),
            action: action,
            actionTitle: actionTitle
        )
    }

    /// Empty-state для наград/достижений.
    static func achievements(
        actionTitle: String = String(localized: "empty.achievements.cta", defaultValue: "К занятиям"),
        action: (() -> Void)? = nil
    ) -> HSEmptyStateView {
        HSEmptyStateView(
            icon: "trophy",
            title: String(localized: "empty.achievements.title", defaultValue: "Пока нет наград"),
            message: String(localized: "empty.achievements.message", defaultValue: "Заверши первое занятие, чтобы получить награду"),
            action: action,
            actionTitle: actionTitle
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
            icon: "magnifyingglass",
            title: String(localized: "empty.search.title", defaultValue: "Ничего не найдено"),
            message: message,
            action: action,
            actionTitle: actionTitle
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
