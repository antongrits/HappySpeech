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
///
/// Используется на онбординге, SessionComplete, Rewards и других hero-экранах.
///
/// ## Пример
/// ```swift
/// LyalyaHeroView(state: .waving, mood: 0.7, size: 180)
/// LyalyaHeroView(state: .celebrating, mood: 1.0, size: 150)
/// ```
public struct LyalyaHeroView: View {

    // MARK: - Public API

    public let state: LyalyaState
    public let mood: Float
    public let size: CGFloat
    public let mouthOpen: Float
    public let viseme: LyalyaViseme

    // MARK: - Init

    public init(
        state: LyalyaState = .idle,
        mood: Float = 0.5,
        size: CGFloat = 160,
        mouthOpen: Float = 0,
        viseme: LyalyaViseme = .rest
    ) {
        self.state = state
        self.mood = mood
        self.size = size
        self.mouthOpen = mouthOpen
        self.viseme = viseme
    }

    // MARK: - Body

    public var body: some View {
        LyalyaMascotView(
            state: state,
            size: size * 0.9
        )
        .frame(width: size, height: size)
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
