import SwiftUI

// MARK: - AuthSignInView

struct AuthSignInView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    @State private var scene: AuthScene?
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password }

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            topDecoration

            VStack(spacing: 0) {
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: SpacingTokens.sp5) {
                        welcomeSection
                        formSection
                        authButtonsSection
                        footerLinks
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp6)
                    .padding(.bottom, SpacingTokens.sp12)
                }
            }
        }
        .loadingOverlay(scene?.state.isLoading ?? false)
        .alert(
            scene?.state.error?.title ?? String(localized: "Ошибка"),
            isPresented: Binding(
                get: { scene?.state.error != nil },
                set: { if !$0 { scene?.state.dismissError() } }
            ),
            actions: {
                Button(String(localized: "Понятно"), role: .cancel) {}
            },
            message: {
                Text(scene?.state.error?.message ?? "")
            }
        )
        .task {
            if scene == nil {
                scene = AuthScene(authService: container.authService)
            }
        }
        .onChange(of: scene?.state.signInViewModel != nil) { _, didSignIn in
            if didSignIn, let vm = scene?.state.signInViewModel {
                handleAuthenticationSuccess(requiresVerification: vm.requiresEmailVerification)
            }
        }
        .onChange(of: scene?.state.googleSignInViewModel != nil) { _, didSignIn in
            if didSignIn {
                handleAuthenticationSuccess(requiresVerification: false)
            }
        }
    }

    // MARK: - Actions

    private func handleAuthenticationSuccess(requiresVerification: Bool) {
        if requiresVerification {
            coordinator.navigate(to: .verifyEmail)
        } else {
            coordinator.navigate(to: .roleSelect)
        }
    }

    private func signIn() {
        guard let scene else { return }
        focusedField = nil
        scene.state.beginLoading()
        Task {
            await scene.interactor.signIn(.init(email: email, password: password))
        }
    }

    private func signInWithGoogle() {
        guard let scene else { return }
        focusedField = nil
        scene.state.beginLoading()
        Task {
            await scene.interactor.signInWithGoogle(.init())
        }
    }

    // MARK: - Layout

    private var topDecoration: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
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
                    .frame(width: geo.size.width * 1.3, height: 320)
                    .offset(x: -geo.size.width * 0.15, y: -100)
            }
        }
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSMascotView(mood: .happy, size: 110)
                .padding(.top, SpacingTokens.sp16)

            Text("HappySpeech")
                .font(TypographyTokens.kidDisplay(30))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }

    private var welcomeSection: some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(String(localized: "С возвращением!"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(String(localized: "Войдите, чтобы следить за прогрессом ребёнка"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var formSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            authTextField(
                title: String(localized: "Эл. почта"),
                text: $email,
                icon: "envelope",
                keyboard: .emailAddress,
                contentType: .emailAddress,
                isSecure: false,
                field: .email
            )
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            authTextField(
                title: String(localized: "Пароль"),
                text: $password,
                icon: "lock",
                keyboard: .default,
                contentType: .password,
                isSecure: true,
                field: .password
            )
            .submitLabel(.go)
            .onSubmit(signIn)
        }
    }

    private var authButtonsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(String(localized: "Войти"), style: .primary, icon: "arrow.right") {
                signIn()
            }
            .disabled(email.isEmpty || password.isEmpty)
            .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)

            HStack {
                Rectangle().fill(ColorTokens.Kid.line).frame(height: 1)
                Text(String(localized: "или"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                Rectangle().fill(ColorTokens.Kid.line).frame(height: 1)
            }
            .padding(.vertical, SpacingTokens.sp1)

            HSButton(String(localized: "Войти через Google"), style: .secondary, icon: "globe") {
                signInWithGoogle()
            }
        }
    }

    private var footerLinks: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Button {
                coordinator.navigate(to: .forgotPassword)
            } label: {
                Text(String(localized: "Забыли пароль?"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }

            Button {
                coordinator.navigate(to: .signUp)
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "Нет аккаунта?"))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Text(String(localized: "Зарегистрироваться"))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .fontWeight(.semibold)
                }
                .font(TypographyTokens.body(14))
            }

            Button {
                coordinator.navigate(to: .demoMode)
            } label: {
                Text(String(localized: "Попробовать без входа"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .underline()
            }
            .padding(.top, SpacingTokens.sp1)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func authTextField(
        title: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        isSecure: Bool,
        field: Field
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .frame(width: 24)

            Group {
                if isSecure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(TypographyTokens.body(16))
            .foregroundStyle(ColorTokens.Kid.ink)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(
                    focusedField == field ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                    lineWidth: focusedField == field ? 1.5 : 1
                )
        )
        .accessibilityLabel(title)
    }
}

// MARK: - Preview

#Preview("Auth Sign In") {
    AuthSignInView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
