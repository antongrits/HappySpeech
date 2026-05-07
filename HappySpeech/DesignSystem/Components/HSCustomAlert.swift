import SwiftUI

// MARK: - HSCustomAlert
//
// Block O v16 — non-system брендированный алерт.
//
// Кастомный alert вместо системного `Alert` / `confirmationDialog`. Реализован
// как ZStack overlay через ViewModifier `.hsAlert(item:content:)`. Фон —
// `.ultraThinMaterial` blur + dimmer; контейнер — RoundedRectangle с тенью.
// Появление / исчезание — `.transition(.scale.combined(with: .opacity))`.
//
// Поддерживает:
// - title (LocalizedStringKey)
// - message (LocalizedStringKey?)
// - SF Symbol или LyalyaState иллюстрацию
// - до 3 кнопок (`HSAlertAction`)
//
// Usage:
// ```swift
// @State private var alertItem: HSAlertItem?
//
// SomeView()
//     .hsAlert(item: $alertItem)
//
// // ...
// alertItem = HSAlertItem(
//     title: "Сохранить прогресс?",
//     message: "Урок ещё не закончен.",
//     mascot: .thinking,
//     primary: .init(title: "Сохранить", role: .primary, action: { ... }),
//     secondary: .init(title: "Отмена", role: .cancel, action: { })
// )
// ```
//
// References:
// - Medium — Custom Alert SwiftUI ViewModifier (lukecsmith.co.uk)
// - Apple HIG — Alerts
// - kavsoft.dev (custom alert pattern)

@available(iOS 17.0, *)
public struct HSAlertAction {

    public enum Role {
        case primary
        case secondary
        case destructive
        case cancel
    }

    public let title: String
    public let role: Role
    public let action: () -> Void

    public init(title: String, role: Role = .primary, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
}

@available(iOS 17.0, *)
public struct HSAlertItem: Identifiable {

    public enum Illustration {
        case symbol(String)
        case mascot(LyalyaState)
        case none
    }

    public let id = UUID()
    public let title: LocalizedStringKey
    public let message: LocalizedStringKey?
    public let illustration: Illustration
    public let primary: HSAlertAction
    public let secondary: HSAlertAction?
    public let tertiary: HSAlertAction?

    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        symbol: String,
        primary: HSAlertAction,
        secondary: HSAlertAction? = nil,
        tertiary: HSAlertAction? = nil
    ) {
        self.title = title
        self.message = message
        self.illustration = .symbol(symbol)
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
    }

    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        mascot: LyalyaState,
        primary: HSAlertAction,
        secondary: HSAlertAction? = nil,
        tertiary: HSAlertAction? = nil
    ) {
        self.title = title
        self.message = message
        self.illustration = .mascot(mascot)
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
    }

    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        primary: HSAlertAction,
        secondary: HSAlertAction? = nil,
        tertiary: HSAlertAction? = nil
    ) {
        self.title = title
        self.message = message
        self.illustration = .none
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
    }
}

// MARK: - HSCustomAlertView

@available(iOS 17.0, *)
public struct HSCustomAlertView: View {

    public let item: HSAlertItem
    public let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(item: HSAlertItem, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Backdrop blur + dim.
            Rectangle()
                .fill(ColorTokens.Overlay.dimmerHeavy)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    if let cancel = cancelAction {
                        runAction(cancel)
                    }
                }

            // Alert card.
            VStack(spacing: SpacingTokens.large) {
                illustrationView

                VStack(spacing: SpacingTokens.small) {
                    Text(item.title)
                        .font(TypographyTokens.titleSmall())
                        .multilineTextAlignment(.center)

                    if let message = item.message {
                        Text(message)
                            .font(TypographyTokens.body())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                buttonsStack
            }
            .padding(SpacingTokens.large)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 24, x: 0, y: 12)
            .padding(.horizontal, SpacingTokens.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Illustration

    @ViewBuilder
    private var illustrationView: some View {
        switch item.illustration {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(height: 56)
        case .mascot(let state):
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.15))
                    .frame(width: 72, height: 72)
                Text(state.fallbackEmoji)
                    .font(.system(size: 36))
            }
        case .none:
            EmptyView()
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private var buttonsStack: some View {
        VStack(spacing: SpacingTokens.small) {
            buttonView(for: item.primary)
            if let secondary = item.secondary {
                buttonView(for: secondary)
            }
            if let tertiary = item.tertiary {
                buttonView(for: tertiary)
            }
        }
    }

    @ViewBuilder
    private func buttonView(for action: HSAlertAction) -> some View {
        let style = mapStyle(action.role)
        HSButton(action.title, style: style) {
            runAction(action)
        }
    }

    private func runAction(_ action: HSAlertAction) {
        action.action()
        onDismiss()
    }

    private var cancelAction: HSAlertAction? {
        if item.primary.role == .cancel { return item.primary }
        if item.secondary?.role == .cancel { return item.secondary }
        if item.tertiary?.role == .cancel { return item.tertiary }
        return nil
    }

    private func mapStyle(_ role: HSAlertAction.Role) -> HSButton.Style {
        switch role {
        case .primary:     return .primary
        case .secondary:   return .secondary
        case .destructive: return .danger
        case .cancel:      return .ghost
        }
    }
}

// MARK: - View Modifier

@available(iOS 17.0, *)
public extension View {
    /// Прикрепляет кастомный алерт — отображается, когда `item` не nil.
    /// Анимация — scale + opacity, dismiss-on-backdrop поддерживается, если есть `.cancel` action.
    func hsAlert(item: Binding<HSAlertItem?>) -> some View {
        self.modifier(HSAlertModifier(item: item))
    }
}

@available(iOS 17.0, *)
private struct HSAlertModifier: ViewModifier {
    @Binding var item: HSAlertItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content

            if let alertItem = item {
                HSCustomAlertView(item: alertItem) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
                        item = nil
                    }
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                .zIndex(1000)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: item?.id)
    }
}

// MARK: - Preview

#Preview("HSCustomAlert") {
    AlertPreview()
}

@available(iOS 17.0, *)
private struct AlertPreview: View {
    @State private var alert: HSAlertItem?

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            VStack(spacing: SpacingTokens.regular) {
                HSButton("Показать алерт") {
                    alert = HSAlertItem(
                        title: "Закончить занятие?",
                        message: "Прогресс будет сохранён.",
                        mascot: .thinking,
                        primary: HSAlertAction(title: "Закончить", role: .primary, action: { }),
                        secondary: HSAlertAction(title: "Продолжить", role: .cancel, action: { })
                    )
                }
            }
            .padding()
        }
        .hsAlert(item: $alert)
    }
}
