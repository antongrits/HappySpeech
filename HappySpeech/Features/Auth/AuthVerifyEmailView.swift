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

    // Унифицировано с остальными auth-экранами: тёплый mesh-«купол».
    private var topDecoration: some View {
        GeometryReader { geo in
            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .frame(width: geo.size.width * 1.3, height: 260)
                .clipShape(Ellipse())
                .opacity(heroDecorationOpacity)
                .offset(x: -geo.size.width * 0.15, y: -140)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp3) {
                // Email header
                HStack(spacing: SpacingTokens.sp3) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "envelope.badge.fill")
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(String(localized: "Мы отправили письмо на"))
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        Text(displayEmail)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider().background(ColorTokens.Kid.line)

                // Numbered steps
                VStack(spacing: SpacingTokens.sp2) {
                    verifyStep(
                        number: 1,
                        icon: "envelope.open.fill",
                        color: ColorTokens.Brand.primary,
                        text: String(localized: "Откройте письмо в почтовом приложении")
                    )
                    verifyStep(
                        number: 2,
                        icon: "link.circle.fill",
                        color: ColorTokens.Brand.lilac,
                        text: String(localized: "Нажмите на ссылку подтверждения в письме")
                    )
                    verifyStep(
                        number: 3,
                        icon: "arrow.uturn.left.circle.fill",
                        color: ColorTokens.Brand.rose,
                        text: String(localized: "Вернитесь в приложение и нажмите «Я подтвердил»")
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Письмо отправлено на") + " " +
            displayEmail + ". " +
            String(localized: "Откройте письмо, нажмите ссылку, вернитесь в приложение.")
        )
    }

    private func verifyStep(
        number: Int,
        icon: String,
        color: Color,
        text: String
    ) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(String(localized: "Шаг") + " \(number)")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(color.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(text)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpacingTokens.sp2)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(color.opacity(0.06))
        )
    }

    /// Email текущего пользователя, либо нейтральный плейсхолдер,
    /// чтобы фраза «Мы отправили письмо на …» никогда не обрывалась.
    private var displayEmail: String {
        let email = container.authService.currentUser?.email ?? ""
        return email.isEmpty ? String(localized: "вашу электронную почту") : email
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
                .fixedSize(horizontal: false, vertical: true)
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
