import SwiftUI

// MARK: - AuthSignUpView

struct AuthSignUpView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    @State private var scene: AuthScene?
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, email, password, confirm }

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            topDecoration

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: SpacingTokens.sp5) {
                        header
                        formSection
                        submitButton
                        footerLink
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp5)
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
            actions: { Button(String(localized: "Понятно"), role: .cancel) {} },
            message: { Text(scene?.state.error?.message ?? "") }
        )
        .task {
            if scene == nil {
                scene = AuthScene(authService: container.authService)
            }
        }
        .onChange(of: scene?.state.signUpViewModel != nil) { _, done in
            if done {
                coordinator.navigate(to: .verifyEmail)
            }
        }
    }

    // MARK: - Actions

    private func signUp() {
        guard let scene else { return }
        guard password == confirmPassword else {
            let state: AuthViewState = scene.state
            state.error = AuthModels.ErrorViewModel(
                title: String(localized: "Пароли не совпадают"),
                message: String(localized: "Повторите пароль в обоих полях.")
            )
            return
        }
        focusedField = nil
        scene.state.beginLoading()
        Task {
            await scene.interactor.signUp(.init(email: email, password: password, name: name))
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
                .frame(width: geo.size.width * 1.3, height: 260)
                .offset(x: -geo.size.width * 0.15, y: -120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSMascotView(mood: .celebrating, size: 96)
                .padding(.top, SpacingTokens.sp2)

            Text(String(localized: "Создать аккаунт"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.sp3)

            Text(String(localized: "Создайте аккаунт, чтобы сохранить прогресс ребёнка"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var formSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            AuthInputField(
                title: String(localized: "Имя"),
                text: $name,
                icon: "person",
                keyboard: .default,
                contentType: .name,
                isSecure: false,
                isFocused: focusedField == .name
            )
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .onSubmit { focusedField = .email }

            AuthInputField(
                title: String(localized: "Эл. почта"),
                text: $email,
                icon: "envelope",
                keyboard: .emailAddress,
                contentType: .emailAddress,
                isSecure: false,
                isFocused: focusedField == .email
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            AuthInputField(
                title: String(localized: "Пароль (мин. 6 символов)"),
                text: $password,
                icon: "lock",
                keyboard: .default,
                contentType: .newPassword,
                isSecure: true,
                isFocused: focusedField == .password
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.next)
            .onSubmit { focusedField = .confirm }

            AuthInputField(
                title: String(localized: "Повторите пароль"),
                text: $confirmPassword,
                icon: "lock.shield",
                keyboard: .default,
                contentType: .newPassword,
                isSecure: true,
                isFocused: focusedField == .confirm
            )
            .focused($focusedField, equals: .confirm)
            .submitLabel(.go)
            .onSubmit(signUp)
        }
    }

    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && !confirmPassword.isEmpty
    }

    private var submitButton: some View {
        HSButton(String(localized: "Создать аккаунт"), style: .primary, icon: "person.crop.circle.badge.plus") {
            signUp()
        }
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.6)
    }

    private var footerLink: some View {
        Button {
            coordinator.navigate(to: .auth)
        } label: {
            HStack(spacing: 4) {
                Text(String(localized: "Уже есть аккаунт?"))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text(String(localized: "Войти"))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .fontWeight(.semibold)
            }
            .font(TypographyTokens.body(14))
        }
    }
}

// MARK: - AuthInputField

struct AuthInputField: View {

    let title: String
    @Binding var text: String
    let icon: String
    let keyboard: UIKeyboardType
    let contentType: UITextContentType?
    let isSecure: Bool
    let isFocused: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .frame(width: 24)

            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(contentType == .name ? .words : .never)
                        .autocorrectionDisabled()
                }
            }
            .font(TypographyTokens.body(16))
            .foregroundStyle(ColorTokens.Kid.ink)
            .textContentType(contentType)
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
                    isFocused ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .accessibilityLabel(title)
    }
}

// MARK: - Preview

#Preview("Auth Sign Up") {
    AuthSignUpView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
