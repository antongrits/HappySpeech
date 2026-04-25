import SwiftUI
import OSLog

// MARK: - PermissionFlowView
//
// Универсальный экран запроса разрешений. Сигнатура `init(type:)` сохранена —
// вью подключён в AppCoordinator (`.permissionFlow(PermissionType)`).
//
// Под капотом — Clean Swift VIP (`PermissionsInteractor / Presenter / Router`),
// поддерживает single-mode (один тип, deep-link) и sequential-mode (полный
// onboarding-flow). Реальные системные API — `AVCaptureDevice.requestAccess`,
// `AVAudioApplication.requestRecordPermission`, `UNUserNotificationCenter`.

struct PermissionFlowView: View {

    // MARK: - Inputs

    let type: PermissionType
    var sequential: Bool = false

    // MARK: - Environment

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    // MARK: - VIP State

    @State private var display = PermissionsDisplay()
    @State private var interactor: PermissionsInteractor?
    @State private var presenter: PermissionsPresenter?
    @State private var router: PermissionsRouter?
    @State private var bootstrapped = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PermissionFlowView")

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            if let step = display.currentStep {
                stepContent(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .id(step.id)
            } else {
                ProgressView()
            }

            // Toast
            if let toast = display.toastMessage {
                VStack {
                    Spacer()
                    HSToast(toast, type: toastType(for: display.currentStep?.state))
                        .padding(.bottom, 130)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.4))
                            withAnimation(.easeInOut(duration: 0.25)) {
                                display.clearToast()
                            }
                        }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onChange(of: display.isFinished) { _, finished in
            if finished {
                handleFinished()
            }
        }
        .onChange(of: display.pendingSettingsURL) { _, url in
            guard let url else { return }
            openURL(url)
            display.clearPendingSettings()
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
            value: display.currentIndex
        )
    }

    // MARK: - Step content

    @ViewBuilder
    private func stepContent(_ step: PermissionStepCard) -> some View {
        VStack(spacing: 0) {
            stepProgressIndicator
                .padding(.top, SpacingTokens.regular)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: SpacingTokens.regular)

            iconBlock(step)

            Spacer(minLength: SpacingTokens.regular)

            textBlock(step)

            if let note = step.privacyNote {
                privacyCard(note: note, accent: step.accentColor)
                    .padding(.top, SpacingTokens.regular)
                    .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Spacer(minLength: SpacingTokens.large)

            actionsBlock(step)
        }
        .padding(.bottom, SpacingTokens.large)
        .accessibilityElement(children: .contain)
    }

    // MARK: Progress dots

    @ViewBuilder
    private var stepProgressIndicator: some View {
        if !display.isSingleMode && display.steps.count > 1 {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<display.steps.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == display.currentIndex
                              ? ColorTokens.Brand.primary
                              : ColorTokens.Kid.line)
                        .frame(width: idx == display.currentIndex ? 28 : 8, height: 8)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75),
                            value: display.currentIndex
                        )
                }
                Spacer(minLength: 0)
                Text(display.progressLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityLabel(display.progressLabel)
            }
        }
    }

    // MARK: Icon

    private func iconBlock(_ step: PermissionStepCard) -> some View {
        ZStack {
            Circle()
                .fill(step.accentColor.opacity(0.15))
                .frame(width: 160, height: 160)
                .scaleEffect(reduceMotion ? 1.0 : 1.04)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: display.currentIndex
                )
            Image(systemName: step.icon)
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(step.accentColor)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Texts

    private func textBlock(_ step: PermissionStepCard) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text(step.title)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)

            Text(step.description)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .lineSpacing(5)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityLabel(step.accessibilityLabel)
    }

    // MARK: Privacy card

    private func privacyCard(note: String, accent: Color) -> some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .font(.system(size: 24, weight: .regular))
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                Text(note)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: String(localized: "permissions.a11y.privacy"),
            note
        ))
    }

    // MARK: Actions

    @ViewBuilder
    private func actionsBlock(_ step: PermissionStepCard) -> some View {
        VStack(spacing: SpacingTokens.small) {
            if step.state == .denied || step.state == .restricted {
                deniedCard(step)
            } else {
                HSButton(
                    step.allowTitle,
                    style: .primary,
                    icon: step.state == .granted ? "checkmark" : nil,
                    isLoading: display.isRequesting
                ) {
                    handleAllow(step)
                }
                .accessibilityLabel(step.allowTitle)
                .accessibilityHint(String(localized: "permissions.a11y.allowHint"))
            }

            Button(action: { handleSkip(step) }) {
                Text(step.skipTitle)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "permissions.a11y.skipLabel"))
            .accessibilityHint(String(localized: "permissions.a11y.skipHint"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: Denied card

    private func deniedCard(_ step: PermissionStepCard) -> some View {
        VStack(spacing: SpacingTokens.small) {
            HSCard(style: .tinted(ColorTokens.Semantic.errorBg)) {
                HStack(spacing: SpacingTokens.regular) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ColorTokens.Semantic.error)
                        .font(.system(size: 22))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(String(localized: "permissions.denied.title"))
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text(String(localized: "permissions.denied.desc"))
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                    }
                    Spacer(minLength: 0)
                }
            }
            HSButton(
                String(localized: "permissions.openSettings"),
                style: .secondary,
                icon: "gearshape.fill"
            ) {
                handleOpenSettings()
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func handleAllow(_ step: PermissionStepCard) {
        display.displayLoading(true)
        interactor?.requestPermission(.init(type: step.id))
    }

    private func handleSkip(_ step: PermissionStepCard) {
        interactor?.skipPermission(.init(type: step.id))
    }

    private func handleOpenSettings() {
        interactor?.openSettings(.init())
    }

    private func handleFinished() {
        logger.info("permission flow finished — popping")
        // Onboarding-flow подхватит .finished через Router; для текущего coordinator
        // встраивания просто закрываем экран.
        coordinator.pop()
    }

    private func toastType(for state: PermissionState?) -> HSToast.ToastType {
        switch state {
        case .granted:    return .success
        case .denied:     return .warning
        case .restricted: return .error
        default:          return .info
        }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = PermissionsInteractor()
        let presenter = PermissionsPresenter()
        let router = PermissionsRouter()

        interactor.presenter = presenter
        presenter.display = display
        router.onDismiss = { [weak coordinator] in
            coordinator?.pop()
        }
        router.onFinished = { [weak coordinator] in
            coordinator?.pop()
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        // Single = текущая старая семантика Coordinator (один permission по deep-link).
        interactor.start(.init(single: sequential ? nil : type))
    }
}

// MARK: - Preview

#Preview("Permission - Microphone single") {
    NavigationStack {
        PermissionFlowView(type: .microphone)
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}

#Preview("Permission - Camera single") {
    NavigationStack {
        PermissionFlowView(type: .camera)
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}

#Preview("Permission - Sequential flow") {
    NavigationStack {
        PermissionFlowView(type: .microphone, sequential: true)
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}
