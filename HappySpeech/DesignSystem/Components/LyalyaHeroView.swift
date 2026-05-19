import SwiftUI

// MARK: - LyalyaHeroView

/// Hero-представление маскота Ляли — обёртка над `LyalyaMascotView`.
///
/// ### Канон облика (ADR-V30-MASCOT-2D)
/// `LyalyaHeroView` рендерит **единый профессионально анимированный 2D-канон**
/// Ляли через `LyalyaMascotView` (иллюстрации `mascot_lyalya_*`, согласованные
/// с `AppIcon`). 3D-рендер удалён: процедурная USDZ-модель выглядела
/// непрофессионально и вызывала 2D/3D-«мигающий» переход. ADR-V30-MASCOT-2D
/// сменяет ADR-V29-MASCOT-3D.
///
/// Используется на онбординге, SessionComplete, Rewards и других hero-экранах.
///
/// ## Пример
/// ```swift
/// LyalyaHeroView(state: .waving, size: 180)
/// LyalyaHeroView(state: .celebrating, size: 150)
/// ```
public struct LyalyaHeroView: View {

    // MARK: - Public API

    public let state: LyalyaState
    public let size: CGFloat

    // MARK: - Init

    public init(
        state: LyalyaState = .idle,
        size: CGFloat = 160
    ) {
        self.state = state
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        // ADR-V30-MASCOT-2D: единый анимированный 2D-канон маскота на всех
        // hero-экранах. LyalyaMascotView рисует иллюстрацию mascot_lyalya_*,
        // согласованную с AppIcon. Reduce Motion обрабатывается внутри.
        LyalyaMascotView(
            state: state,
            size: size * 0.9
        )
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("LyalyaHeroView — waving") {
    LyalyaHeroView(state: .waving, size: 180)
        .padding(20)
        .background(Color(.systemBackground))
}

#Preview("LyalyaHeroView — celebrating") {
    LyalyaHeroView(state: .celebrating, size: 150)
        .padding(20)
        .background(Color.yellow.opacity(0.15))
}
