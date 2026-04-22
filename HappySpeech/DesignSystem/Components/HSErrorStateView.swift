import SwiftUI

// MARK: - HSErrorStateView

public struct HSErrorStateView: View {
    let error: Error
    let onRetry: (() -> Void)?

    public init(error: Error, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            VStack(spacing: SpacingTokens.small) {
                Text("Что-то пошло не так")
                    .font(TypographyTokens.headline())
                    .bold()
                Text(error.localizedDescription)
                    .font(TypographyTokens.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let onRetry {
                HSButton("Попробовать снова", style: .primary, action: onRetry)
                    .padding(.horizontal, SpacingTokens.xLarge)
            }
        }
        .padding(SpacingTokens.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
