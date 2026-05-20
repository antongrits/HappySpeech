import SwiftUI

// MARK: - HSGlassNavigationBar
//
// Block O v16 — кастомный glass-навбар поверх контента.
//
// Не системный navigation bar — тонкая «капсульная» полоска поверх контента
// с back-кнопкой и заголовком. На iOS 26+ использует Liquid Glass `.glassEffect()`,
// на iOS 17/18 — `.ultraThinMaterial`.
//
// Применяется в детальных экранах (LessonDetail, SoundPackDetail, ParentReport),
// чтобы дать App Store-like wow-эффект и не зависеть от системного NavBar.
//
// Usage:
// ```swift
// VStack(spacing: 0) {
//     HSGlassNavigationBar(
//         title: "Урок 5: Свистящие",
//         onBack: { dismiss() }
//     ) {
//         Button { } label: { Image(systemName: "ellipsis") }
//     }
//     ScrollView { ... }
// }
// ```
//
// References:
// - Apple Docs: Liquid Glass (iOS 26)
// - kavsoft.dev/swiftui_3.0_hero_animation (custom navbar pattern)

@available(iOS 17.0, *)
public struct HSGlassNavigationBar<Trailing: View>: View {

    // MARK: - Public API

    public let title: LocalizedStringKey
    public let subtitle: LocalizedStringKey?
    public let onBack: (() -> Void)?
    public let trailing: () -> Trailing

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.circuitContext) private var circuit
    @Environment(\.hapticService) private var hapticService

    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.trailing = trailing
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            if let onBack {
                backButton(action: onBack)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(inkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let subtitle {
                    Text(subtitle)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(inkColor.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
                .foregroundStyle(inkColor)
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .frame(maxWidth: .infinity)
        .background(barBackground)
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.top, SpacingTokens.small)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Back Button

    @ViewBuilder
    private func backButton(action: @escaping () -> Void) -> some View {
        Button {
            hapticService.impact(.light)
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(inkColor.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(inkColor)
        .accessibilityLabel(Text("Назад"))
    }

    // MARK: - Background

    @ViewBuilder
    private var barBackground: some View {
        let shape = RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
        if #available(iOS 26, *), !reduceMotion {
            // iOS 26 Liquid Glass — true system glass with adaptive blur.
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay(
                    shape
                        .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 0.5)
                )
                .shadow(color: ColorTokens.Overlay.shadow, radius: 14, x: 0, y: 6)
        } else {
            // iOS 17–25 (and Reduced Motion) fallback — static ultraThinMaterial.
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape
                        .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 0.5)
                )
                .shadow(color: ColorTokens.Overlay.shadow, radius: 14, x: 0, y: 6)
        }
    }

    private var inkColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Kid.ink
        case .parent:     return ColorTokens.Parent.ink
        case .specialist: return ColorTokens.Spec.ink
        }
    }
}

// MARK: - Preview

#Preview("HSGlassNavigationBar") {
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        VStack {
            HSGlassNavigationBar(
                title: "Урок 5: Свистящие",
                subtitle: "12 слов · 8 минут",
                onBack: { }
            ) {
                Button { } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                }
            }
            Spacer()
        }
    }
    .environment(\.circuitContext, .kid)
}
