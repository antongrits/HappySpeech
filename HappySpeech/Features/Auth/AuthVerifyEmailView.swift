import SwiftUI

// MARK: - AuthVerifyEmailView

struct AuthVerifyEmailView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    @State private var scene: AuthScene?
    @State private var toastMessage: String?
    @State private var appeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // Block C v19 — hero decoration opacity снижается в dark mode.
    private var heroDecorationOpacity: Double {
        colorScheme == .dark ? 0.35 : 1.0
    }

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            topDecoration

            VStack(spacing: SpacingTokens.sp6) {
                Spacer(minLength: SpacingTokens.sp16)

                header
                    .offset(y: appeared ? 0 : (reduceMotion ? 0 : -20))
                    .opacity(appeared ? 1 : 0)

                instructionCard
                    .offset(y: appeared ? 0 : (reduceMotion ? 0 : 16))
                    .opacity(appeared ? 1 : 0)

                actionsSection
                    .offset(y: appeared ? 0 : (reduceMotion ? 0 : 24))
                    .opacity(appeared ? 1 : 0)

                if let toast = toastMessage {
                    toastView(toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                signOutLink
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
        .loadingOverlay(scene?.state.isLoading ?? false)
        // Block J v18 — заменён системный .alert на HSCustomAlert.
        .hsAlert(item: Binding(
            get: { authAlertItem },
            set: { newValue in if newValue == nil { scene?.state.dismissError() } }
        ))
        .onAppear {
            guard !appeared else { return }
            withAnimation(reduceMotion ? .easeIn(duration: 0.1) : MotionTokens.spring.delay(0.1)) {
                appeared = true
            }
        }
        .task {
            if scene == nil {
                scene = AuthScene(authService: container.authService)
            }
        }
        .onChange(of: scene?.state.emailVerificationViewModel) { _, newValue in
            guard let vm = newValue else { return }
            if vm.isVerified {
                coordinator.navigate(to: .roleSelect)
            } else {
                showToast(vm.message)
            }
        }
        .onChange(of: scene?.state.resendVerificationViewModel) { _, newValue in
            if let vm = newValue { showToast(vm.message) }
        }
        .onChange(of: scene?.state.signOutViewModel) { _, newValue in
            if newValue != nil { coordinator.navigate(to: .auth) }
        }
    }

    // MARK: - Block J v18 HSCustomAlert mapping

    private var authAlertItem: HSAlertItem? {
        guard let error = scene?.state.error else { return nil }
        return HSAlertItem(
            title: LocalizedStringKey(error.title),
            message: LocalizedStringKey(error.message),
            symbol: "exclamationmark.triangle.fill",
            primary: HSAlertAction(
                title: String(localized: "Понятно"),
                role: .cancel,
                action: { scene?.state.dismissError() }
            )
        )
    }

    // MARK: - Actions

    private func checkVerified() {
        guard let scene else { return }
        scene.state.beginLoading()
        Task { await scene.interactor.checkEmailVerified(.init()) }
    }

    private func resendEmail() {
        guard let scene else { return }
        scene.state.beginLoading()
        Task { await scene.interactor.resendVerification(.init()) }
    }

    private func signOut() {
        guard let scene else { return }
        scene.interactor.signOut(.init())
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toastMessage == message { toastMessage = nil }
        }
    }

    // MARK: - Sections

    private var topDecoration: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(GradientTokens.kidHeroDecoration)
                .opacity(heroDecorationOpacity)
                .frame(width: geo.size.width * 1.3, height: 260)
                .offset(x: -geo.size.width * 0.15, y: -140)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.sp4) {
            LyalyaMascotView(state: .thinking, size: 110)
                .accessibilityHidden(true)

            Text(String(localized: "Подтвердите почту"))
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
        }
    }

    private var instructionCard: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "envelope.badge.fill")
                        .font(TypographyTokens.title(28))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(String(localized: "Мы отправили письмо на"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        Text(container.authService.currentUser?.email ?? "")
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                    .background(ColorTokens.Kid.line)
                Text(String(localized: "Перейдите по ссылке в письме, затем вернитесь сюда."))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Письмо отправлено на") + " " +
            (container.authService.currentUser?.email ?? "") + ". " +
            String(localized: "Перейдите по ссылке в письме, затем вернитесь сюда.")
        )
    }

    private var actionsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(String(localized: "Я подтвердил — продолжить"), style: .primary, icon: "checkmark.seal") {
                checkVerified()
            }

            HSButton(String(localized: "Отправить письмо ещё раз"), style: .secondary, icon: "arrow.clockwise") {
                resendEmail()
            }
        }
    }

    private var signOutLink: some View {
        Button {
            signOut()
        } label: {
            Text(String(localized: "Выйти и войти под другим аккаунтом"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .underline()
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.medium)
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(TypographyTokens.body(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp3)
            .background(
                Capsule().fill(ColorTokens.Kid.ink.opacity(0.9))
            )
    }
}

// MARK: - Preview

#Preview("Auth Verify Email") {
    AuthVerifyEmailView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
