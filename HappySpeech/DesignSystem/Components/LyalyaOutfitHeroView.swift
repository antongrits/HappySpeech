import SwiftUI

// MARK: - LyalyaOutfitHeroView

/// Hero-вью маскота, которое **видимо отражает выбранный наряд** Ляли.
///
/// ### Зачем
/// Анимированный канон ``LyalyaMascotView`` (`mascot_lyalya_*`) — это отдельная
/// система поз, которую нельзя «переодеть» (ре-риг невозможен). Чтобы смена
/// одежды в кастомизации была видна ребёнку на ключевых экранах-приветствиях
/// (главный экран ребёнка, превью кастомизации), этот вью показывает
/// **статичную иллюстрацию наряда** `lyalya_outfit_<id>`, когда выбран наряд,
/// отличный от повседневного.
///
/// ### Поведение
/// - Наряд `.everyday` (по умолчанию) → показываем живой анимированный
///   ``LyalyaMascotView`` (state передаётся снаружи) — он «дышит», машет и т.д.
/// - Любой другой наряд → показываем статичную картинку `lyalya_outfit_<id>`
///   с лёгким idle-парением (отключается при Reduce Motion).
///
/// Выбранный наряд читается из `@Environment(LyalyaCustomizationStorage.self)`.
/// Если storage недоступен (например, изолированный preview) — рендерим
/// анимированный канон, чтобы вью никогда не оставался пустым.
///
/// ## Пример
/// ```swift
/// LyalyaOutfitHeroView(state: .waving, size: 160)
/// ```
public struct LyalyaOutfitHeroView: View {

    // MARK: - Public API

    public let state: LyalyaState
    public let size: CGFloat

    // MARK: - Environment

    @Environment(LyalyaCustomizationStorage.self) private var customization: LyalyaCustomizationStorage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation state

    @State private var floatOffset: CGFloat = 0

    // MARK: - Init

    public init(state: LyalyaState = .idle, size: CGFloat = 160) {
        self.state = state
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let outfit = customization?.outfit, outfit != .everyday {
                outfitImage(outfit)
            } else {
                // Повседневный наряд / нет storage → живой анимированный канон.
                LyalyaMascotView(state: state, size: size)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Outfit illustration

    @ViewBuilder
    private func outfitImage(_ outfit: LyalyaOutfit) -> some View {
        Image(outfit.illustrationName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .colorMultiply(skinTintColor)
            .offset(y: floatOffset)
            .id(outfit.rawValue)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            .animation(reduceMotion ? .none : MotionTokens.spring, value: outfit)
            .onAppear { startFloating() }
            .accessibilityElement()
            .accessibilityLabel(
                String(
                    format: String(localized: "lyalya.hero.outfit.a11y"),
                    outfit.localizedName
                )
            )
    }

    // MARK: - Skin tint (синхронно с LyalyaMascotView)

    private var skinTintColor: Color {
        switch customization?.colorVariant {
        case .warm:   return ColorTokens.Skin.warm
        case .cool:   return ColorTokens.Skin.cool
        case .nature: return ColorTokens.Skin.nature
        case .none:   return ColorTokens.Skin.classic
        }
    }

    // MARK: - Idle float

    private func startFloating() {
        guard !reduceMotion else {
            floatOffset = 0
            return
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            floatOffset = -6
        }
    }
}

// MARK: - Preview

#Preview("LyalyaOutfitHeroView — outfit") {
    LyalyaOutfitHeroView(state: .waving, size: 180)
        .padding(24)
        .environment(LyalyaCustomizationStorage.shared)
        .background(Color(.systemBackground))
}
