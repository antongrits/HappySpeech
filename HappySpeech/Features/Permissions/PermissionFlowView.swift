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
//
// Дизайн:
// - тёплый фон (Kid.bg, нежно-жёлтый),
// - маскот Ляля сверху (состояние меняется по шагу: explaining → celebrating),
// - большая иллюстрация в круге с градиентом цвета шага,
// - заголовок + описание (Dynamic Type compatible),
// - HSLiquidGlassCard вокруг зоны privacy/actions,
// - шагомер (capsule dots) внизу,
// - финальный праздничный экран с конфетти после всех шагов.

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
    @State private var grantedPulse: Bool = false
    @State private var celebrationActive: Bool = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PermissionFlowView")

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            if display.isFinished && !display.isSingleMode {
                allDoneContent
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let step = display.currentStep {
                stepContent(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .id(step.id)
            } else {
                ProgressView()
            }

            // Toast (всегда поверх, кроме финального экрана)
            if let toast = display.toastMessage, !display.isFinished {
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
            handleFinishedChange(finished)
        }
        .onChange(of: display.pendingSettingsURL) { _, url in
            guard let url else { return }
            openURL(url)
            display.clearPendingSettings()
        }
        .onChange(of: display.currentStep?.state) { _, newState in
            // Подсветка "Отлично!" badge при granted.
            guard newState == .granted else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6)) {
                grantedPulse = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeInOut(duration: 0.3)) {
                    grantedPulse = false
                }
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
            value: display.currentIndex
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85),
            value: display.isFinished
        )
    }

    // MARK: - Step content

    @ViewBuilder
    private func stepContent(_ step: PermissionStepCard) -> some View {
        VStack(spacing: 0) {
            stepProgressIndicator
                .padding(.top, SpacingTokens.regular)
                .padding(.horizontal, SpacingTokens.screenEdge)

            mascotBlock(step)
                .padding(.top, SpacingTokens.regular)

            iconBlock(step)
                .padding(.top, SpacingTokens.small)

            grantedBadge(step)

            Spacer(minLength: SpacingTokens.regular)

            textBlock(step)

            Spacer(minLength: SpacingTokens.regular)

            actionsCard(step)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.large)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: All-done content

    @ViewBuilder
    private var allDoneContent: some View {
        let card = PermissionsPresenter.makeAllDoneCard(steps: display.steps)

        ZStack {
            // Конфетти / радостный фон-градиент
            LinearGradient(
                colors: [
                    ColorTokens.Brand.butter.opacity(0.35),
                    ColorTokens.Kid.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: SpacingTokens.large) {
                Spacer(minLength: SpacingTokens.large)

                LyalyaMascotView(state: card.lyalyaState, size: 200)
                    .accessibilityLabel(String(localized: "permissions.lyalya.a11y.celebrating"))
                    .scaleEffect(celebrationActive ? 1.05 : 1.0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: celebrationActive
                    )

                VStack(spacing: SpacingTokens.small) {
                    Text(card.title)
                        .font(TypographyTokens.title(28))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)

                    Text(card.subtitle)
                        .font(TypographyTokens.body(17))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .lineSpacing(5)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, SpacingTokens.large)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer(minLength: SpacingTokens.regular)

                HSLiquidGlassCard(style: .primary) {
                    HSButton(
                        card.ctaTitle,
                        style: .primary,
                        icon: "sparkles"
                    ) {
                        handleAllDoneCTA()
                    }
                    .accessibilityHint(String(localized: "permissions.allDone.subtitle"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.large)
            }
            .accessibilityElement(children: .contain)

            // Конфетти-эффект (через эмодзи-частицы, без сторонних либ)
            if !reduceMotion {
                ConfettiBurstView(isActive: celebrationActive)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            celebrationActive = true
        }
    }

    // MARK: Progress dots

    @ViewBuilder
    private var stepProgressIndicator: some View {
        if !display.isSingleMode && display.steps.count > 1 {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<display.steps.count, id: \.self) { idx in
                    Capsule()
                        .fill(progressDotColor(for: idx))
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

    private func progressDotColor(for index: Int) -> Color {
        if index < display.currentIndex {
            // Уже пройденные шаги — лёгкий зелёный
            return ColorTokens.Semantic.success.opacity(0.65)
        }
        if index == display.currentIndex {
            return ColorTokens.Brand.primary
        }
        return ColorTokens.Kid.line
    }

    // MARK: Mascot block

    @ViewBuilder
    private func mascotBlock(_ step: PermissionStepCard) -> some View {
        LyalyaMascotView(state: step.lyalyaState, size: 96)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(
                step.state == .granted
                    ? String(localized: "permissions.lyalya.a11y.celebrating")
                    : String(localized: "permissions.lyalya.a11y.explaining")
            )
    }

    // MARK: Icon

    private func iconBlock(_ step: PermissionStepCard) -> some View {
        ZStack {
            // Внешнее мягкое свечение
            Circle()
                .fill(step.accentColor.opacity(0.10))
                .frame(width: 144, height: 144)
                .blur(radius: 14)

            // Основной круг с градиентом
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            step.accentColor.opacity(0.28),
                            step.accentColor.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 124, height: 124)
                .overlay(
                    Circle()
                        .strokeBorder(step.accentColor.opacity(0.30), lineWidth: 1)
                )

            Image(systemName: step.icon)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(step.accentColor)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Granted badge

    @ViewBuilder
    private func grantedBadge(_ step: PermissionStepCard) -> some View {
        if step.state == .granted {
            HStack(spacing: SpacingTokens.micro) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .accessibilityHidden(true)
                Text(String(localized: "permissions.granted.badge"))
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Semantic.success)
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.micro)
            .background(
                Capsule().fill(ColorTokens.Semantic.success.opacity(0.12))
            )
            .scaleEffect(grantedPulse ? 1.10 : 1.0)
            .padding(.top, SpacingTokens.small)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "permissions.granted.badge"))
        }
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
                .accessibilityAddTraits(.isHeader)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(step.accessibilityLabel)
    }

    // MARK: Actions card (Liquid Glass)

    @ViewBuilder
    private func actionsCard(_ step: PermissionStepCard) -> some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
            VStack(spacing: SpacingTokens.small) {
                if let note = step.privacyNote {
                    privacyRow(note: note)
                        .padding(.bottom, SpacingTokens.tiny)
                }

                if step.state == .denied || step.state == .restricted {
                    deniedSection(step)
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
        }
    }

    // MARK: Privacy row (внутри Liquid Glass карточки)

    private func privacyRow(note: String) -> some View {
        HStack(spacing: SpacingTokens.regular) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(ColorTokens.Brand.mint)
                .font(.system(size: 22, weight: .regular))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(note)
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: String(localized: "permissions.a11y.privacy"),
            note
        ))
    }

    // MARK: Denied section

    private func deniedSection(_ step: PermissionStepCard) -> some View {
        VStack(spacing: SpacingTokens.small) {
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
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Semantic.errorBg)
            )

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

    private func handleAllDoneCTA() {
        logger.info("all-done CTA tapped — finishing")
        router?.routeFinished()
    }

    private func handleFinishedChange(_ finished: Bool) {
        guard finished else { return }
        if display.isSingleMode {
            // Single-mode: закрыть сразу.
            handleFinishedSingle()
        }
        // Sequential-mode: показать allDoneContent (через body),
        // финальный CTA вызовет routeFinished.
    }

    private func handleFinishedSingle() {
        logger.info("single permission flow finished — popping")
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

        // Single = старая семантика Coordinator (один permission по deep-link).
        interactor.start(.init(single: sequential ? nil : type))
    }
}

// MARK: - ConfettiBurstView
//
// Простая SwiftUI-конфетти без сторонних либ. Используется только
// на финальном экране с `reduceMotion == false`.

private struct ConfettiBurstView: View {

    let isActive: Bool

    @State private var animateParticles: Bool = false

    private let particles: [(emoji: String, x: CGFloat, delay: Double, duration: Double)] = [
        ("🎉", 0.10, 0.00, 2.6),
        ("⭐️", 0.25, 0.20, 2.4),
        ("✨", 0.40, 0.10, 2.8),
        ("🌟", 0.55, 0.30, 2.5),
        ("💫", 0.70, 0.05, 2.7),
        ("🎊", 0.85, 0.25, 2.6),
        ("⭐️", 0.18, 0.35, 2.5),
        ("✨", 0.62, 0.15, 2.7)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles.indices, id: \.self) { idx in
                    let item = particles[idx]
                    Text(item.emoji)
                        .font(.system(size: 28))
                        .position(
                            x: proxy.size.width * item.x,
                            y: animateParticles ? proxy.size.height + 40 : -40
                        )
                        .opacity(animateParticles ? 0.0 : 1.0)
                        .animation(
                            .easeIn(duration: item.duration).delay(item.delay),
                            value: animateParticles
                        )
                }
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            animateParticles = true
        }
        .onAppear {
            if isActive {
                animateParticles = true
            }
        }
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
