import SwiftUI

// MARK: - HSOfflineBanner

/// Persistent top banner shown when NetworkMonitor detects offline state.
/// Contains sync queue item count and retry button.
public struct HSOfflineBanner: View {

    private let pendingCount: Int
    private let onRetry: (() -> Void)?
    @State private var expanded = false

    public init(pendingCount: Int = 0, onRetry: (() -> Void)? = nil) {
        self.pendingCount = pendingCount
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Нет интернета"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    if pendingCount > 0 {
                        Text(pendingCountText)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                if let onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Text(String(localized: "Повторить"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(.white.opacity(0.25))
                            )
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp2)
        }
        .background(Color(hex: "#E85D35"))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Нет подключения к интернету. \(pendingCountText)")
    }

    private var pendingCountText: String {
        if pendingCount == 0 { return "" }
        let word = pluralise(pendingCount, one: "запись", few: "записи", many: "записей")
        return "\(pendingCount) \(word) ожидают синхронизации"
    }

    private func pluralise(_ n: Int, one: String, few: String, many: String) -> String {
        let mod100 = n % 100
        let mod10  = n % 10
        if mod100 >= 11 && mod100 <= 19 { return many }
        if mod10 == 1 { return one }
        if mod10 >= 2 && mod10 <= 4 { return few }
        return many
    }
}

// MARK: - HSEmptyState

/// Empty state view for lists and screens with no data.
public struct HSEmptyState: View {
    private let icon: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String = "tray",
        title: String,
        message: String = "",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(Color.secondary.opacity(0.5))

            Text(title)
                .font(TypographyTokens.headline())
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primary)

            if !message.isEmpty {
                Text(message)
                    .font(TypographyTokens.body())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, SpacingTokens.sp8)
            }

            if let actionTitle, let action {
                HSButton(actionTitle, style: .secondary, size: .medium, action: action)
                    .padding(.top, SpacingTokens.sp2)
            }
        }
        .padding(SpacingTokens.sp8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - HSErrorState

public struct HSErrorState: View {
    private let error: any Error
    private let onRetry: (() -> Void)?

    public init(error: any Error, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }

    public var body: some View {
        HSEmptyState(
            icon: "exclamationmark.triangle",
            title: String(localized: "Что-то пошло не так"),
            message: error.localizedDescription,
            actionTitle: onRetry != nil ? String(localized: "Попробовать снова") : nil,
            action: onRetry
        )
    }
}

// MARK: - Preview

#Preview("Offline & States") {
    VStack(spacing: 0) {
        HSOfflineBanner(pendingCount: 3) {}
        Spacer()
        HSEmptyState(
            icon: "text.bubble",
            title: "Пока нет занятий",
            message: "Начните первое занятие, чтобы увидеть прогресс здесь.",
            actionTitle: "Начать занятие"
        ) {}
        Spacer()
    }
}
