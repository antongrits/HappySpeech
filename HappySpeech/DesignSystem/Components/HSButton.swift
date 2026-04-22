import SwiftUI

// MARK: - HSButton

/// Primary CTA button used throughout the app.
/// Adapts to kid / parent / specialist circuits.
public struct HSButton: View {

    public enum Style {
        case primary    // filled coral CTA
        case secondary  // outlined
        case ghost      // text only
        case danger     // red destructive action
    }

    public enum ButtonSize {
        case large      // full-width CTA
        case medium     // inline
        case small      // compact
    }

    private let title: String
    private let style: Style
    private let size: ButtonSize
    private let icon: String?
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.circuitContext) private var circuit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    public init(
        _ title: String,
        style: Style = .primary,
        size: ButtonSize = .large,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: {
            if !isLoading { action() }
        }) {
            HStack(spacing: SpacingTokens.sp2) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .semibold))
                    }
                    Text(title)
                        .font(TypographyTokens.cta())
                        .ctaTextStyle()
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: size == .large ? .infinity : nil)
            .padding(.horizontal, horizontalPad)
            .frame(height: height)
            .background(backgroundShape)
            .overlay(borderShape)
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .disabled(isLoading)
    }

    // MARK: - Computed Properties

    private var height: CGFloat {
        switch size {
        case .large:  return 56
        case .medium: return 44
        case .small:  return 36
        }
    }

    private var horizontalPad: CGFloat {
        switch size {
        case .large:  return SpacingTokens.large
        case .medium: return SpacingTokens.regular
        case .small:  return SpacingTokens.small
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .large:  return 18
        case .medium: return 16
        case .small:  return 14
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return accentColor
        case .ghost:     return accentColor
        case .danger:    return .white
        }
    }

    private var accentColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Brand.primary
        case .parent:     return ColorTokens.Parent.accent
        case .specialist: return ColorTokens.Spec.accent
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
            .fill(backgroundColor)
    }

    @ViewBuilder
    private var borderShape: some View {
        if style == .secondary {
            RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                .strokeBorder(accentColor, lineWidth: 1.5)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return accentColor
        case .secondary:
            return Color.clear
        case .ghost:
            return Color.clear
        case .danger:
            return ColorTokens.Semantic.error
        }
    }
}

// MARK: - Preview

#Preview("HSButton States") {
    VStack(spacing: 16) {
        HSButton("Начать занятие", style: .primary, icon: "play.fill") {}
        HSButton("Настройки", style: .secondary) {}
        HSButton("Отмена", style: .ghost) {}
        HSButton("Удалить", style: .danger, icon: "trash") {}
        HSButton("Загрузка...", isLoading: true) {}
        HSButton("Компактная", size: .small) {}
    }
    .padding()
    .environment(\.circuitContext, .kid)
}
