import SwiftUI

// MARK: - HSLottieContainer

/// Placeholder for future Lottie animations. Currently the Lottie SDK
/// is not linked, so this view always renders the provided fallback.
/// Once Lottie is integrated, swap the `body` to `LottieView(name:)` and
/// keep the same public API so all call sites continue to work.
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
        fallback
            .frame(width: size.width, height: size.height)
            .onAppear {
                HSLogger.ui.debug(
                    "HSLottieContainer: Lottie not available, rendering fallback for '\(self.name, privacy: .public)'"
                )
            }
    }
}

// MARK: - Preview

#Preview("HSLottieContainer fallback") {
    VStack(spacing: SpacingTokens.large) {
        HSLottieContainer(
            name: "lyalya_celebrate",
            fallback: AnyView(
                Text(verbatim: "🎉")
                    .font(.system(size: 80))
            ),
            size: CGSize(width: 200, height: 200)
        )
        HSLottieContainer(
            name: "loading_dots",
            fallback: AnyView(
                ProgressView()
                    .progressViewStyle(.circular)
            ),
            size: CGSize(width: 80, height: 80)
        )
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}
