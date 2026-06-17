import SwiftUI

// MARK: - HSLoadingView

public struct HSLoadingView: View {
    let message: String
    let lottie: HSLottieAsset
    @State private var rotation: Double = 0

    public init(message: String = "Загрузка...", lottie: HSLottieAsset = .loaderInitializing) {
        self.message = message
        self.lottie = lottie
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.large) {
            // Lottie-лоадер с graceful-fallback на нативный спиннер,
            // если файл анимации отсутствует в бандле.
            HSLottieContainer(
                asset: lottie,
                fallback: AnyView(fallbackSpinner),
                size: CGSize(width: 72, height: 72)
            )
            Text(message)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { rotation = 360 }
    }

    private var fallbackSpinner: some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.Brand.primary.opacity(0.2), lineWidth: 4)
                .frame(width: 56, height: 56)
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(ColorTokens.Brand.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
        }
    }
}
