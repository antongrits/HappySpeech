import SwiftUI

// MARK: - HSPaywallTeaser

/// Premium-feature teaser — заглушка для будущей монетизации (post-v1.0).
///
/// `HSPaywallTeaser` — карточка с замочком, заголовком, описанием премиум-функции
/// и неактивной CTA-кнопкой «Узнать больше». В v1.0 кнопка disabled — это просто
/// визуальный hint, что фича на пути. Когда появится in-app purchase flow,
/// `actionDisabled` переключится в `false` и кнопка станет активной.
///
/// Карточка использует `HSLiquidGlassCard` (style `.tinted(gold.opacity(0.18))`),
/// что визуально отделяет премиум-блок от остального контента. Light/Dark адаптация —
/// через токены ColorTokens (карточка автоматически адаптируется).
///
/// ## Пример
/// ```swift
/// HSPaywallTeaser(
///     title: "Расширенная аналитика",
///     subtitle: "Подробные графики прогресса по каждому звуку и экспорт PDF.",
///     onTap: { interactor.openPaywallInfo() }
/// )
/// ```
///
/// ## See Also
/// - ``HSLiquidGlassCard``
/// - ``HSButton``
/// - ``ColorTokens``
@available(iOS 17.0, *)
public struct HSPaywallTeaser: View {

    private let title: String
    private let subtitle: String
    private let icon: String
    private let buttonTitle: String
    private let actionDisabled: Bool
    private let onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - title: Заголовок (по умолчанию «Премиум функция»).
    ///   - subtitle: Описание функции, рус.
    ///   - icon: SF Symbol для иконки. По умолчанию «lock.fill».
    ///   - buttonTitle: Текст CTA. По умолчанию «Узнать больше».
    ///   - actionDisabled: В v1.0 — `true`. После запуска монетизации — `false`.
    ///   - onTap: Опциональный обработчик tap по карточке (если кнопка активна).
    public init(
        title: String = String(localized: "paywall.teaser.defaultTitle", defaultValue: "Премиум функция"),
        subtitle: String,
        icon: String = "lock.fill",
        buttonTitle: String = String(localized: "paywall.teaser.cta", defaultValue: "Узнать больше"),
        actionDisabled: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.buttonTitle = buttonTitle
        self.actionDisabled = actionDisabled
        self.onTap = onTap
    }

    public var body: some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.gold.opacity(0.18)), padding: SpacingTokens.large) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                iconBubble
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(title)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    Text(subtitle)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    ctaButton
                        .padding(.top, SpacingTokens.tiny)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint(actionDisabled
            ? String(localized: "paywall.teaser.hint.disabled", defaultValue: "Скоро появится")
            : String(localized: "paywall.teaser.hint.enabled", defaultValue: "Нажмите для подробностей"))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var iconBubble: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Brand.gold.opacity(0.25))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.gold)
        }
        .accessibilityHidden(true)
        .modifier(GoldShimmer(reduceMotion: reduceMotion))
    }

    @ViewBuilder
    private var ctaButton: some View {
        HSButton(
            buttonTitle,
            style: .secondary,
            size: .small,
            icon: actionDisabled ? "clock" : "arrow.right"
        ) {
            if !actionDisabled, let onTap {
                onTap()
            }
        }
        .disabled(actionDisabled)
        .opacity(actionDisabled ? 0.6 : 1.0)
    }
}

// MARK: - GoldShimmer

@available(iOS 17.0, *)
private struct GoldShimmer: ViewModifier {
    let reduceMotion: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    Circle()
                        .stroke(ColorTokens.Brand.gold.opacity(0.55), lineWidth: 1.5)
                        .scaleEffect(1.0 + phase * 0.18)
                        .opacity(1.0 - phase)
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("HSPaywallTeaser Light") {
    VStack(spacing: SpacingTokens.large) {
        HSPaywallTeaser(
            subtitle: "Подробные графики прогресса по каждому звуку и экспорт PDF для логопеда."
        )
        HSPaywallTeaser(
            title: "Дополнительные истории",
            subtitle: "Открой 30+ новых анимированных историй с маскотом Лялей.",
            icon: "books.vertical.fill"
        )
    }
    .padding(SpacingTokens.large)
    .background(ColorTokens.Parent.bg)
}

@available(iOS 17.0, *)
#Preview("HSPaywallTeaser Dark") {
    HSPaywallTeaser(
        subtitle: "Подробные графики прогресса и экспорт PDF для логопеда."
    )
    .padding(SpacingTokens.large)
    .background(ColorTokens.Parent.bg)
    .preferredColorScheme(.dark)
}
#endif
