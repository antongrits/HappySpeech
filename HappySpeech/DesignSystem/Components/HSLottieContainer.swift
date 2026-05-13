import Lottie
import SwiftUI

// MARK: - HSLottieView

/// Обёртка над `LottieView` из airbnb/lottie-ios 4.5+.
///
/// Использует нативный `LottieView(animation:)` API с поддержкой:
/// - loop / playOnce / bounce
/// - Reduced Motion (при `accessibilityReduceMotion` рисует первый кадр без анимации)
/// - optional fallback View, если анимация не найдена в бандле
///
/// Пример использования:
/// ```swift
/// HSLottieView(name: "lyalya_celebrate", loopMode: .loop)
///     .frame(width: 200, height: 200)
/// ```
public struct HSLottieView: View {

    private let name: String
    private let loopMode: LottieLoopMode
    private let contentMode: UIView.ContentMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        loopMode: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.name = name
        self.loopMode = loopMode
        self.contentMode = contentMode
    }

    public var body: some View {
        if reduceMotion {
            // Reduced Motion: статичный первый кадр без воспроизведения
            LottieView(animation: .named(name))
                .animationSpeed(0)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            LottieView(animation: .named(name))
                .playing(loopMode: loopMode)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

// MARK: - HSLottieContainer (обратная совместимость)

/// Совместимая обёртка — используй `HSLottieView` для новых экранов.
/// Если анимация `name` не найдена в бандле, отображает `fallback`.
public struct HSLottieContainer: View {

    private let name: String
    private let fallback: AnyView
    private let size: CGSize

    public init(
        name: String,
        fallback: AnyView,
        size: CGSize = CGSize(width: 200, height: 200)
    ) {
        self.name = name
        self.fallback = fallback
        self.size = size
    }

    public var body: some View {
        if LottieAnimation.named(name) != nil {
            HSLottieView(name: name, loopMode: .loop)
                .frame(width: size.width, height: size.height)
        } else {
            fallback
                .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - Preview

#Preview("HSLottieView real API") {
    VStack(spacing: SpacingTokens.large) {
        HSLottieView(name: "lyalya_celebrate", loopMode: .loop)
            .frame(width: 200, height: 200)

        HSLottieView(name: "loading_dots", loopMode: .loop)
            .frame(width: 80, height: 80)

        HSLottieContainer(
            name: "nonexistent_animation",
            fallback: AnyView(
                // Plan v21 Block C: эмодзи запрещены в DesignSystem — SF Symbol fallback.
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .symbolRenderingMode(.hierarchical)
            ),
            size: CGSize(width: 200, height: 200)
        )
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}
