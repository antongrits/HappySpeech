import SwiftUI

// MARK: - HSLoadingView

public struct HSLoadingView: View {
    let message: String
    @State private var rotation: Double = 0

    public init(message: String = "Загрузка...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.large) {
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
            Text(message)
                .font(TypographyTokens.body())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { rotation = 360 }
    }
}
