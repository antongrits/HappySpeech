import SwiftUI

// MARK: - PermissionFlowView

struct PermissionFlowView: View {
    let type: PermissionType
    @Environment(AppCoordinator.self) private var coordinator
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(permissionColor.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: permissionIcon)
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(permissionColor)
                }

                Spacer()

                // Text
                VStack(spacing: SpacingTokens.sp3) {
                    Text(permissionTitle)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)

                    Text(permissionDescription)
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.sp6)
                }

                Spacer()

                // Actions
                VStack(spacing: SpacingTokens.sp3) {
                    HSButton(
                        String(localized: "Разрешить"),
                        style: .primary,
                        icon: "checkmark",
                        isLoading: isRequesting
                    ) {
                        requestPermission()
                    }

                    Button {
                        coordinator.pop()
                    } label: {
                        Text(String(localized: "Пропустить"))
                            .font(TypographyTokens.body())
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp16)
            }
        }
    }

    private var permissionIcon: String {
        switch type {
        case .microphone:    return "mic.fill"
        case .camera:        return "camera.fill"
        case .notifications: return "bell.fill"
        }
    }

    private var permissionColor: Color {
        switch type {
        case .microphone:    return ColorTokens.Brand.primary
        case .camera:        return ColorTokens.Brand.lilac
        case .notifications: return ColorTokens.Brand.butter
        }
    }

    private var permissionTitle: String {
        switch type {
        case .microphone:    return String(localized: "Нужен доступ к микрофону")
        case .camera:        return String(localized: "Нужен доступ к камере")
        case .notifications: return String(localized: "Включить напоминания?")
        }
    }

    private var permissionDescription: String {
        switch type {
        case .microphone:
            return String(localized: "Приложению нужен микрофон, чтобы записывать произношение ребёнка и оценивать результаты.")
        case .camera:
            return String(localized: "Камера используется в AR-упражнениях: ребёнок видит своё лицо и повторяет движения артикуляции.")
        case .notifications:
            return String(localized: "Мы будем напоминать о занятиях в удобное время, чтобы не пропускать тренировки.")
        }
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run {
                isRequesting = false
                coordinator.pop()
            }
        }
    }
}

// MARK: - Preview

#Preview("Permission - Microphone") {
    PermissionFlowView(type: .microphone)
        .environment(AppCoordinator())
}
