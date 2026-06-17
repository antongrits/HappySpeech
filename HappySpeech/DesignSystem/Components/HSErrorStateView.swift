import SwiftUI

// MARK: - HSErrorStateView
//
// Эталон states-empty-error: иконка предупреждения в тёплом кружке,
// заголовок Kid.ink, описание ошибки Kid.inkMuted, кнопка повтора.

public struct HSErrorStateView: View {
    let error: Error
    let onRetry: (() -> Void)?

    public init(error: Error, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.large) {
            // Иконка в тёплом кружке — единый стиль с HSEmptyStateView
            ZStack {
                Circle()
                    .fill(ColorTokens.Semantic.warningBg)
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(ColorTokens.Semantic.warning)
            }
            .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "errorState.title"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(error.localizedDescription)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.small)
            }
            if let onRetry {
                HSButton(String(localized: "errorState.retry"), style: .primary, action: onRetry)
                    .padding(.horizontal, SpacingTokens.xLarge)
                    .accessibilityLabel(String(localized: "errorState.retry"))
            }
        }
        .padding(SpacingTokens.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
