import SwiftUI

// MARK: - AuthForgotPasswordView

struct AuthForgotPasswordView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    @State private var scene: AuthScene?
    @State private var email: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            topDecoration

            VStack(spacing: 0) {
                navBar

                VStack(spacing: SpacingTokens.sp6) {
                    header

                    if let success = scene?.state.forgotPasswordViewModel {
                        successState(message: success.successMessage)
                    } else {
                        form
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp5)
            }
        }
        .loadingOverlay(scene?.state.isLoading ?? false)
        .alert(
            scene?.state.error?.title ?? String(localized: "Ошибка"),
            isPresented: Binding(
                get: { scene?.state.error != nil },
                set: { if !$0 { scene?.state.dismissError() } }
            ),
            actions: { Button(String(localized: "Понятно"), role: .cancel) {} },
            message: { Text(scene?.state.error?.message ?? "") }
        )
        .task {
            if scene == nil {
                scene = AuthScene(authService: container.authService)
            }
        }
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(SpacingTokens.sp2)
                    .background(.white.opacity(0.15), in: Circle())
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
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTokens.Brand.primary.opacity(0.9),
                            ColorTokens.Brand.primaryLo.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: geo.size.width * 1.3, height: 220)
                .offset(x: -geo.size.width * 0.15, y: -120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSMascotView(mood: .thinking, size: 96)

            Text(String(localized: "Забыли пароль?"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(String(localized: "Введите почту — мы пришлём ссылку для восстановления"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
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
        VStack(spacing: SpacingTokens.sp5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Semantic.success)

            Text(message)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            HSButton(String(localized: "Вернуться ко входу"), style: .secondary) {
                coordinator.navigate(to: .auth)
            }
        }
        .padding(SpacingTokens.sp6)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
    }
}

// MARK: - Preview

#Preview("Auth Forgot Password") {
    AuthForgotPasswordView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
