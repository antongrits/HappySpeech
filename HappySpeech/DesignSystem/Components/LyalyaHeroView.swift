import SwiftUI

// MARK: - LyalyaHeroView

/// Hero-представление маскота Ляли на основе 2D illustration.
///
/// По умолчанию отображает `LyalyaMascotView` (2D, быстро, без тёмного фона).
/// USDZ/RealityKit намеренно не используется — исключает тёмно-розовый артефакт
/// прямоугольника на онбординге и других hero-экранах (KK v14 fix).
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
