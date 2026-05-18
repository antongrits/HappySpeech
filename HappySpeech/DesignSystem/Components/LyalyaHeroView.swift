import SwiftUI

// MARK: - LyalyaHeroView

/// Hero-представление маскота Ляли — обёртка над `LyalyaMascotView`.
///
/// ### Канон облика (D-3 v27 — унификация маскота)
/// `LyalyaHeroView` рендерит **единый 2D-канон** Ляли через `LyalyaMascotView`
/// (2D-иллюстрации `mascot_lyalya_*`, согласованные с `AppIcon`).
/// Ранее hero-экраны использовали 3D-рендер `lyalya3d_v2.usdz`, который
/// изображал серого «робота» и расходился с брендом «подружка-пчёлка».
/// 3D-слой убран — на всех экранах теперь один облик маскота.
///
/// Параметры `mood`, `mouthOpen`, `viseme`, `force2D` сохранены для
/// совместимости callsite, но `force2D` теперь не влияет на рендер
/// (он всегда 2D), а `mouthOpen`/`viseme` 2D-каноном не используются.
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
    public let mood: Float
    public let size: CGFloat
    public let mouthOpen: Float
    public let viseme: LyalyaViseme
    /// Сохранён для совместимости callsite. С D-3 v27 рендер всегда 2D,
    /// поэтому флаг больше не влияет на отображение.
    public let force2D: Bool

    // MARK: - Init

    public init(
        state: LyalyaState = .idle,
        mood: Float = 0.5,
        size: CGFloat = 160,
        mouthOpen: Float = 0,
        viseme: LyalyaViseme = .rest,
        force2D: Bool = false
    ) {
        self.state = state
        self.mood = mood
        self.size = size
        self.mouthOpen = mouthOpen
        self.viseme = viseme
        self.force2D = force2D
    }

    // MARK: - Body

    public var body: some View {
        // D-3 v27: единый 2D-канон маскота на всех hero-экранах.
        // LyalyaMascotView рисует 2D-иллюстрацию mascot_lyalya_*, согласованную
        // с AppIcon. Reduce Motion обрабатывается внутри LyalyaMascotView.
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
