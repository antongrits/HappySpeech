import SwiftUI

// MARK: - HSMeshGradientBackground
//
// Block O — полноэкранный спокойный тёплый фон приложения.
//
// РЕДИЗАЙН Волна A (2026-06-13): убран многоцветный mesh-градиент (коралл +
// лиловый + мятный смешивались в «радугу» — выглядело непрофессионально).
// Теперь фон — практически ОДНОТОННЫЙ, очень мягкий вертикальный тёплый
// градиент в пределах ОДНОГО семейства цвета (cream → чуть теплее cream),
// в стиле референсов open-design (light ≈ #FFF8F0 кремовый, dark — тёмный
// нейтрально-тёплый). Без смешивания разных hue, без волн, без движения.
//
// API/сигнатура сохранены (149 вызовов в проекте не трогаем): тот же
// `init(palette:animated:)`, тот же набор `Palette`. Параметр `animated`
// сохранён для совместимости, но фон статичный (анимация фона запрещена).
//
// Usage:
// ```swift
// ZStack {
//     HSMeshGradientBackground(palette: .kidWarm)
//         .ignoresSafeArea()
//     content
// }
// ```

@available(iOS 17.0, *)
public struct HSMeshGradientBackground: View {

    // MARK: - Palette

    public enum Palette {
        case kidWarm
        case kidWarmDark
        case kidCool
        case rewards
        case calm

        /// Верхний (стартовый) тон мягкого вертикального градиента.
        /// Все варианты — в пределах ОДНОГО тёплого кремового семейства,
        /// никакого зелёного/синего/радужного смешивания.
        var top: Color {
            switch self {
            case .kidWarm, .kidCool, .calm:
                return ColorTokens.Kid.bg
            case .kidWarmDark:
                return ColorTokens.Kid.bgDeep
            case .rewards:
                return ColorTokens.Kid.bgSofter
            }
        }

        /// Нижний (конечный) тон — чуть теплее верхнего, в том же семействе.
        var bottom: Color {
            switch self {
            case .kidWarm, .kidCool:
                return ColorTokens.Kid.bgSofter
            case .calm:
                return ColorTokens.Kid.bgSoft
            case .kidWarmDark:
                return ColorTokens.Kid.bgDeep
            case .rewards:
                return ColorTokens.Kid.bgSofter
            }
        }
    }

    // MARK: - Public API

    public let palette: Palette
    public let animated: Bool

    public init(palette: Palette = .kidWarm, animated: Bool = true) {
        self.palette = palette
        self.animated = animated
    }

    // MARK: - Body
    //
    // Очень мягкий вертикальный градиент в пределах одного тёплого семейства.
    // На практике почти однотонный — разница между top и bottom минимальна,
    // что даёт спокойный фон без видимых «полос» и смешивания цветов.

    public var body: some View {
        LinearGradient(
            colors: [palette.top, palette.bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview("HSMeshGradientBackground") {
    VStack(spacing: 0) {
        HSMeshGradientBackground(palette: .kidWarm)
            .frame(height: 160)
        HSMeshGradientBackground(palette: .kidWarmDark)
            .frame(height: 160)
        HSMeshGradientBackground(palette: .kidCool)
            .frame(height: 160)
        HSMeshGradientBackground(palette: .rewards)
            .frame(height: 160)
        HSMeshGradientBackground(palette: .calm)
            .frame(height: 160)
    }
}
