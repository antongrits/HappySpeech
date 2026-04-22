import SwiftUI

// MARK: - AuthVerifyEmailView

struct AuthVerifyEmailView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    @State private var scene: AuthScene?
    @State private var toastMessage: String?

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            topDecoration

            VStack(spacing: SpacingTokens.sp6) {
                Spacer(minLength: SpacingTokens.sp16)

                header

                actionsSection

                if let toast = toastMessage {
                    toastView(toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                signOutLink
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
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
                .frame(width: geo.size.width * 1.3, height: 260)
                .offset(x: -geo.size.width * 0.15, y: -140)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.sp4) {
            HSMascotView(mood: .thinking, size: 110)

            Text(String(localized: "Подтвердите почту"))
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)

            VStack(spacing: SpacingTokens.sp1) {
                Text(String(localized: "Мы отправили письмо на"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                Text(container.authService.currentUser?.email ?? "")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Brand.primary)

                Text(String(localized: "Перейдите по ссылке в письме, затем вернитесь сюда."))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, SpacingTokens.sp2)
            }
        }
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
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(TypographyTokens.body(13))
            .foregroundStyle(.white)
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
