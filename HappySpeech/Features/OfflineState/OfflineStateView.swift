import SwiftUI

// MARK: - OfflineStateView

struct OfflineStateView: View {
    @State private var pendingCount = 3
    @State private var isRetrying = false
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Illustration
                illustrationSection

                Spacer()

                // Info
                infoSection

                // Actions
                actionsSection
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp16)
            }
        }
    }

    private var illustrationSection: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.08))
                .frame(width: 200, height: 200)

            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(Color.orange.opacity(0.6))

                if pendingCount > 0 {
                    Text(pendingBadgeText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpacingTokens.sp3)
                        .padding(.vertical, SpacingTokens.sp1)
                        .background(Capsule().fill(Color.orange))
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(localized: "Нет подключения к интернету"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text(String(localized: "Приложение работает офлайн. Занятия доступны. Данные синхронизируются автоматически, когда интернет появится."))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp6)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var actionsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // Continue offline
            HSButton(
                String(localized: "Продолжить без интернета"),
                style: .primary,
                icon: "arrow.right"
            ) {
                coordinator.navigate(to: .childHome(childId: "preview-child-1"))
            }

            // Retry connection
            HSButton(
                isRetrying
                    ? String(localized: "Проверяем...")
                    : String(localized: "Проверить подключение"),
                style: .secondary,
                icon: isRetrying ? nil : "arrow.clockwise",
                isLoading: isRetrying
            ) {
                retryConnection()
            }
        }
    }

    private var pendingBadgeText: String {
        "\(pendingCount) ожидают синхронизации"
    }

    private func retryConnection() {
        isRetrying = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                isRetrying = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Offline State") {
    OfflineStateView()
        .environment(AppCoordinator())
}
