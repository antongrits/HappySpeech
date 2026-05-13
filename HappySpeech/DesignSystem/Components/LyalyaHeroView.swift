import SwiftUI

// MARK: - LyalyaHeroView

/// Hero-представление маскота Ляли — обёртка над `LyalyaMascotView`.
///
/// Hybrid-архитектура (см. `HSMascotView`):
/// - **Layer 2**: 2D PNG-иллюстрация (`mascot_lyalya_*` из Assets) — гарантирует
///   видимость маскота на симуляторе без TrueDepth и до загрузки 3D usdz.
/// - **Layer 3**: `LyalyaRealityKitView` (`lyalya3d_v2.usdz`, RealityKit nonAR
///   с прозрачным фоном) — рендерится поверх 2D, когда сцена загружена.
///
/// История фиксов прозрачного фона:
/// - KK v14 (8c06a48f) — временно отключил RealityKit из-за артефакта розового фона.
/// - F.1 v15 (ec6c2072) — починил `arView.environment.background = .color(.clear)`,
///   `cameraMode = .nonAR`, `isOpaque = false`.
/// - K v17 (1bb8b6d1) — visual audit 94 файлов, 0 артефактов прозрачности.
/// - H v18 — visual verify iPhone SE (3rd gen): pink rectangle не воспроизводится.
/// - E v21 — `LyalyaHeroView` теперь использует `LyalyaRealityKitView` 3D
///   как основной слой (требование пользователя: 3D героев на каждом экране).
///   При `accessibilityReduceMotion = true` или `force2D = true` fallback на 2D.
///
/// Используется на онбординге, SessionComplete, Rewards и других hero-экранах.
///
/// ## Пример
/// ```swift
/// LyalyaHeroView(state: .waving, mood: 0.7, size: 180)
/// LyalyaHeroView(state: .celebrating, mood: 1.0, size: 150)
/// // Принудительный 2D fallback (например, в headers где >1 hero на экране):
/// LyalyaHeroView(state: .pointing, size: 60, force2D: true)
/// ```
public struct LyalyaHeroView: View {

    // MARK: - Public API

    public let state: LyalyaState
    public let mood: Float
    public let size: CGFloat
    public let mouthOpen: Float
    public let viseme: LyalyaViseme
    /// Принудительный 2D fallback (для случаев когда нужно несколько Ляль на экране,
    /// или для headers / small-size mini-mascots, где 3D overkill GPU-wise).
    public let force2D: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        // Reduce Motion fallback: 3D idle-анимации (breathing, sway, blink)
        // запускаются внутри RealityKit Coordinator → даже если reduceMotion
        // обрабатывается там же, мы для GPU-экономии force-switch на 2D.
        // Также если callsite явно запросил force2D (например в header 36pt).
        if reduceMotion || force2D || size < 80 {
            LyalyaMascotView(
                state: state,
                size: size * 0.9
            )
            .frame(width: size, height: size)
        } else {
            LyalyaRealityKitView(
                state: state,
                mood: mood,
                mouthOpen: mouthOpen,
                viseme: viseme
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Preview

#Preview("LyalyaHeroView — waving") {
    LyalyaHeroView(state: .waving, mood: 0.7, size: 180)
        .padding(20)
        .background(Color(.systemBackground))
}

#Preview("LyalyaHeroView — celebrating") {
    LyalyaHeroView(state: .celebrating, mood: 1.0, size: 150)
        .padding(20)
        .background(Color.yellow.opacity(0.15))
}
