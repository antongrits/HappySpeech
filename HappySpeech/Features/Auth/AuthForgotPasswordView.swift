import SwiftUI

// MARK: - AuthForgotPasswordView

struct AuthForgotPasswordView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    @State private var scene: AuthScene?
    @State private var email: String = ""
    @FocusState private var isFocused: Bool

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

            VStack(spacing: 0) {
                navBar

                VStack(spacing: SpacingTokens.sp6) {
                    header
                        .offset(y: appeared ? 0 : 24)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            reduceMotion ? nil : MotionTokens.spring,
                            value: appeared
                        )

                    if let success = scene?.state.forgotPasswordViewModel {
                        successState(message: success.successMessage)
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                reduceMotion ? nil : MotionTokens.spring.delay(0.1),
                                value: appeared
                            )
                    } else {
                        formGlassSection
                            .offset(y: appeared ? 0 : 28)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                reduceMotion ? nil : MotionTokens.spring.delay(0.1),
                                value: appeared
                            )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp5)
            }
        }
        .onAppear { appeared = true }
        .loadingOverlay(scene?.state.isLoading ?? false)
        // Block J v18 — заменён системный .alert на HSCustomAlert.
        .hsAlert(item: Binding(
            get: { authAlertItem },
            set: { newValue in if newValue == nil { scene?.state.dismissError() } }
        ))
        .task {
            if scene == nil {
                scene = AuthScene(authService: container.authService)
            }
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

    private func sendResetLink() {
        guard let scene else { return }
        isFocused = false
        scene.state.beginLoading()
        Task {
            await scene.interactor.forgotPassword(.init(email: email))
        }
    }

    // MARK: - Sections

    private var navBar: some View {
        HStack {
            Button {
                coordinator.navigate(to: .auth)
            } label: {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(SpacingTokens.sp2)
                    .background(ColorTokens.Kid.surface, in: Circle())
            }
            .accessibilityLabel(String(localized: "Назад"))

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp10)
    }

    private var topDecoration: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(GradientTokens.kidHeroDecoration)
                .opacity(heroDecorationOpacity)
                .frame(width: geo.size.width * 1.3, height: 220)
                .offset(x: -geo.size.width * 0.15, y: -120)
        }
        .ignoresSafeArea()
    }

    private var formGlassSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.sp4) {
            form
        }
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .thinking, size: 96)

            Text(String(localized: "Забыли пароль?"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(String(localized: "Введите почту — мы пришлём ссылку для восстановления"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.medium)
        }
    }

    private var form: some View {
        VStack(spacing: SpacingTokens.sp3) {
            AuthInputField(
                title: String(localized: "Эл. почта"),
                text: $email,
                icon: "envelope",
                keyboard: .emailAddress,
                contentType: .emailAddress,
                isSecure: false,
                isFocused: isFocused
            )
            .focused($isFocused)
            .submitLabel(.go)
            .onSubmit(sendResetLink)

            HSButton(String(localized: "Отправить ссылку"), style: .primary, icon: "paperplane") {
                sendResetLink()
            }
            .disabled(email.isEmpty)
            .opacity(email.isEmpty ? 0.6 : 1)
        }
    }

    private func successState(message: String) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Semantic.success), padding: SpacingTokens.sp6) {
            VStack(spacing: SpacingTokens.sp5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(TypographyTokens.kidDisplay(56))
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .accessibilityHidden(true)

                Text(message)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                HSButton(String(localized: "Вернуться ко входу"), style: .secondary) {
                    coordinator.navigate(to: .auth)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Auth Forgot Password") {
    AuthForgotPasswordView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
