import SwiftUI

// MARK: - AuthSignInView

struct AuthSignInView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: AuthScene?
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password }

    // Block C v19 — hero decoration opacity снижается в dark mode чтобы
    // убрать яркую оранжевую шапку на тёмном фоне.
    private var heroDecorationOpacity: Double {
        colorScheme == .dark ? 0.35 : 1.0
    }

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            topDecoration

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp4) {
                    gateBadge
                    headerSection
                    welcomeSection
                    formSection
                    authButtonsSection
                    footerLinks
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.sp4)
        }
        .accessibilityIdentifier("AuthSignInRoot")
        .loadingOverlay(scene?.state.isLoading ?? false)
        // Block J v18 — заменён системный .alert на HSCustomAlert
        // (kavsoft-style branded overlay с blur backdrop).
        .hsAlert(item: Binding(
            get: { authAlertItem },
            set: { newValue in if newValue == nil { scene?.state.dismissError() } }
        ))
        .onAppear {
            // AA v18 — eager init on appear (before .task) so form is ready on first render.
            if scene == nil {
                scene = AuthScene(authService: container.authService)
            }
        }
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

    // MARK: - Block J v18 HSCustomAlert mapping
    //
    // Преобразует scene?.state.error в HSAlertItem для брендированного
    // алерта. Возврашает nil если ошибки нет.
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

    // v27 visual modernization (#7): hero-зона Auth переведена с плоского
    // эллипса на HSMeshGradientBackground(palette: .kidWarm, animated: false).
    // Mesh подрезается эллиптической формой — мягкий «купол» вверху экрана.
    private var topDecoration: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .frame(width: geo.size.width * 1.3, height: 320)
                    .clipShape(Ellipse())
                    .opacity(heroDecorationOpacity)
                    .offset(x: -geo.size.width * 0.15, y: -100)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // Родитель-гейт: pill «Вход для взрослых» — подсказывает, что вход
    // предназначен для взрослых (COPPA-канон эталона), оставаясь декоративным.
    private var gateBadge: some View {
        HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "lock.fill")
                .font(TypographyTokens.caption(11))
            Text(String(localized: "auth.gate.adults"))
                .font(TypographyTokens.caption(12).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(ColorTokens.Kid.inkMuted)
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp1 + 2)
        .background(
            Capsule().fill(ColorTokens.Kid.surfaceAlt)
        )
        .overlay(
            Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .padding(.top, SpacingTokens.sp4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "auth.gate.adults"))
    }

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.sp2) {
            // E v21: 3D Ляля в header AuthSignIn (требование «3D героев на каждом экране»).
            LyalyaHeroView(state: .happy, size: 108)
                .accessibilityHidden(true)

            // Fix #1 — wordmark must read on cream Kid.bg. Двухцветный канон:
            // «Happy» — ink, «Speech» — коралл (повторяет эталон auth.html).
            (
                Text("Happy").foregroundStyle(ColorTokens.Kid.ink)
                + Text("Speech").foregroundStyle(ColorTokens.Brand.primary)
            )
            .font(TypographyTokens.kidDisplay(30))
            .tracking(-0.6)
            .shadow(
                color: ColorTokens.Brand.primary.opacity(0.14),
                radius: 6, x: 0, y: 2
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel("HappySpeech")
            .accessibilityAddTraits(.isHeader)

            Text(String(localized: "auth.tagline"))
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
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
        HSLiquidGlassCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp4) {
                labeledField(label: String(localized: "auth.email.label")) {
                    authTextField(
                        config: AuthFieldConfig(
                            title: String(localized: "auth.email.placeholder"),
                            icon: "envelope",
                            keyboard: .emailAddress,
                            contentType: .emailAddress,
                            isSecure: false,
                            field: .email
                        ),
                        text: $email
                    )
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityLabel(String(localized: "accessibility.email_field"))
                    .accessibilityHint(String(localized: "accessibility.email_field.hint"))
                }

                labeledField(label: String(localized: "auth.password.label")) {
                    authTextField(
                        config: AuthFieldConfig(
                            title: String(localized: "auth.password.label"),
                            icon: "lock",
                            keyboard: .default,
                            contentType: .password,
                            isSecure: true,
                            field: .password
                        ),
                        text: $password
                    )
                    .submitLabel(.go)
                    .onSubmit(signIn)
                    .accessibilityLabel(String(localized: "accessibility.password_field"))
                    .accessibilityHint(String(localized: "accessibility.password_field.hint"))
                }
            }
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1 + 2) {
            Text(label)
                .font(TypographyTokens.caption(13).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .padding(.leading, SpacingTokens.sp1)
                .accessibilityHidden(true)
            content()
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
                HStack(spacing: SpacingTokens.micro) {
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
            .accessibilityIdentifier("authSignUpLink")

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

    private struct AuthFieldConfig {
        let title: String
        let icon: String
        let keyboard: UIKeyboardType
        let contentType: UITextContentType?
        let isSecure: Bool
        let field: Field
    }

    @ViewBuilder
    private func authTextField(
        config: AuthFieldConfig,
        text: Binding<String>
    ) -> some View {
        let title = config.title
        let icon = config.icon
        let keyboard = config.keyboard
        let contentType = config.contentType
        let isSecure = config.isSecure
        let field = config.field
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: icon)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .frame(width: 24)
                .hsSymbolEffect(.bounce, value: focusedField == field)

            Group {
                if isSecure && !isPasswordVisible {
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

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .frame(width: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isPasswordVisible
                        ? String(localized: "auth.password.hide")
                        : String(localized: "auth.password.show")
                )
            }
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
