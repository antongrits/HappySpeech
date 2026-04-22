import SwiftUI

// MARK: - HSBadge

/// Small label badge for status, sound names, counts.
public struct HSBadge: View {

    public enum BadgeStyle {
        case filled(Color)
        case outlined(Color)
        case success
        case warning
        case info
        case neutral
    }

    private let text: String
    private let style: BadgeStyle
    private let icon: String?

    public init(_ text: String, style: BadgeStyle = .neutral, icon: String? = nil) {
        self.text = text
        self.style = style
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(backgroundShape)
        .accessibilityLabel(text)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:              return .white
        case .outlined(let c):     return c
        case .success:             return ColorTokens.Semantic.success
        case .warning:             return ColorTokens.Semantic.warning
        case .info:                return ColorTokens.Semantic.info
        case .neutral:             return Color.secondary
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch style {
        case .filled(let c):
            Capsule().fill(c)
        case .outlined(let c):
            Capsule().strokeBorder(c, lineWidth: 1)
                .background(Capsule().fill(c.opacity(0.08)))
        case .success:
            Capsule().fill(ColorTokens.Semantic.successBg)
        case .warning:
            Capsule().fill(ColorTokens.Semantic.warningBg)
        case .info:
            Capsule().fill(ColorTokens.Semantic.infoBg)
        case .neutral:
            Capsule().fill(Color.primary.opacity(0.07))
        }
    }
}

// MARK: - HSToast

/// Bottom-aligned dismissable toast notification.
public struct HSToast: View {

    public enum ToastType {
        case success, error, warning, info
    }

    private let message: String
    private let type: ToastType

    public init(_ message: String, type: ToastType = .info) {
        self.message = message
        self.type = type
    }

    public var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(message)
                .font(TypographyTokens.body(14))
                .foregroundStyle(Color.primary)
                .lineLimit(3)
                .ctaTextStyle()

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var iconName: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch type {
        case .success: return ColorTokens.Semantic.success
        case .error:   return ColorTokens.Semantic.error
        case .warning: return ColorTokens.Semantic.warning
        case .info:    return ColorTokens.Semantic.info
        }
    }
}

// MARK: - Preview

#Preview("Badges & Toast") {
    VStack(spacing: 16) {
        HStack {
            HSBadge("С", style: .filled(ColorTokens.Brand.primary))
            HSBadge("Успех", style: .success, icon: "checkmark")
            HSBadge("Ошибка", style: .outlined(ColorTokens.Semantic.error))
            HSBadge("Слог", style: .info)
        }
        HSToast("Данные сохранены!", type: .success)
        HSToast("Нет интернета. Работаем офлайн.", type: .warning)
    }
    .padding()
}
