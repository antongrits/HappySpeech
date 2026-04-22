import SwiftUI

// MARK: - HSEmptyStateView

public struct HSEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Попробовать"

    public init(icon: String, title: String, message: String, action: (() -> Void)? = nil, actionTitle: String = "Попробовать") {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionTitle = actionTitle
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            VStack(spacing: SpacingTokens.small) {
                Text(title)
                    .font(TypographyTokens.headline())
                    .bold()
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(TypographyTokens.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let action {
                HSButton(actionTitle, style: .secondary, action: action)
                    .padding(.horizontal, SpacingTokens.xLarge)
            }
        }
        .padding(SpacingTokens.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
