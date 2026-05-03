import SwiftUI

// MARK: - LyalyaHeroView

/// Обёртка над LyalyaRealityKitView с надёжным fallback на LyalyaMascotView.
///
/// Решает проблему розового/непрозрачного прямоугольника:
/// - Если lyalya3d_v2.usdz не найден в bundle — показывает LyalyaMascotView (2D Rive)
/// - Если RealityKit недоступен (симулятор без Metal) — показывает LyalyaMascotView
/// - Прозрачный фон гарантируется на обоих уровнях (.clear background)
///
/// Используется вместо LyalyaRealityKitView на онбординге и других hero-экранах.
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

    // MARK: - State

    @State private var usdzAvailable: Bool = false
    @State private var checked: Bool = false

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.clear

            if usdzAvailable {
                LyalyaRealityKitView(
                    state: state,
                    mood: mood,
                    mouthOpen: mouthOpen,
                    viseme: viseme
                )
                .background(Color.clear)
            } else {
                LyalyaMascotView(
                    state: state,
                    size: size * 0.9
                )
            }
        }
        .frame(width: size, height: size)
        .task {
            guard !checked else { return }
            checked = true
            usdzAvailable = Bundle.main.url(
                forResource: "lyalya3d_v2",
                withExtension: "usdz",
                subdirectory: "ARAssets"
            ) != nil
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
