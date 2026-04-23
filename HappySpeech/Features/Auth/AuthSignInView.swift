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
        .accessibilityHidden(true)
    }

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSMascotView(mood: .happy, size: 110)
                .padding(.top, SpacingTokens.sp16)
                .accessibilityHidden(true)

            Text("HappySpeech")
                .font(TypographyTokens.kidDisplay(30))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var welcomeSection: some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(String(localized: "auth.welcome.back"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "auth.landing.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
    }

    private var formSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            authTextField(
                title: String(localized: "auth.email.label"),
                text: $email,
                icon: "envelope",
                keyboard: .emailAddress,
                contentType: .emailAddress,
                isSecure: false,
                field: .email
            )
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .accessibilityLabel(String(localized: "accessibility.email_field"))
            .accessibilityHint(String(localized: "accessibility.email_field.hint"))

            authTextField(
                title: String(localized: "auth.password.label"),
                text: $password,
                icon: "lock",
                keyboard: .default,
                contentType: .password,
                isSecure: true,
                field: .password
            )
            .submitLabel(.go)
            .onSubmit(signIn)
            .accessibilityLabel(String(localized: "accessibility.password_field"))
            .accessibilityHint(String(localized: "accessibility.password_field.hint"))
        }
    }

    private var authButtonsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(String(localized: "auth.signIn"), style: .primary, icon: "arrow.right") {
                signIn()
            }
            .disabled(email.isEmpty || password.isEmpty)
            .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)
            .accessibilityLabel(String(localized: "accessibility.sign_in_button"))
            .accessibilityHint(String(localized: "accessibility.sign_in_button.hint"))

            HStack {
                Rectangle().fill(ColorTokens.Kid.line).frame(height: 1)
                Text(String(localized: "auth.or"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                Rectangle().fill(ColorTokens.Kid.line).frame(height: 1)
            }
            .padding(.vertical, SpacingTokens.sp1)
            .accessibilityHidden(true)

            HSButton(String(localized: "auth.google.cta"), style: .secondary, icon: "globe") {
                signInWithGoogle()
            }
            .accessibilityLabel(String(localized: "accessibility.google_sign_in"))
        }
    }

    private var footerLinks: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Button {
                coordinator.navigate(to: .forgotPassword)
            } label: {
                Text(String(localized: "auth.forgot.password"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .accessibilityLabel(String(localized: "accessibility.forgot_password"))

            Button {
                coordinator.navigate(to: .signUp)
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "auth.noAccount"))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Text(String(localized: "auth.register.cta"))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .fontWeight(.semibold)
                }
                .font(TypographyTokens.body(14))
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            }
            .accessibilityLabel(String(localized: "accessibility.go_to_signup"))

            Button {
                coordinator.navigate(to: .demoMode)
            } label: {
                Text(String(localized: "auth.tryWithoutLogin"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .underline()
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .padding(.top, SpacingTokens.sp1)
            .accessibilityLabel(String(localized: "accessibility.demo_mode"))
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
