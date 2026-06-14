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
                .foregroundStyle(ColorTokens.Semantic.warning)
            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "errorState.title"))
                    .font(TypographyTokens.headline())
                    .bold()
                Text(error.localizedDescription)
                    .font(TypographyTokens.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let onRetry {
                HSButton(String(localized: "errorState.retry"), style: .primary, action: onRetry)
                    .padding(.horizontal, SpacingTokens.xLarge)
            }
        }
        .padding(SpacingTokens.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
