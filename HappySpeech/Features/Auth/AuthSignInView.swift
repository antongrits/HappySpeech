import SwiftUI
import AuthenticationServices

// MARK: - AuthSignInView

struct AuthSignInView: View {
    @State private var viewModel = AuthSignInViewModel()
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background
            ColorTokens.Kid.bg.ignoresSafeArea()

            // Decorative top arc
            topDecoration

            VStack(spacing: 0) {
                // Header
                headerSection

                Spacer()

                // Welcome content
                centerContent

                Spacer()

                // Auth buttons
                authButtonsSection
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp16)
            }
        }
        .loadingOverlay(viewModel.isLoading)
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text(String(localized: "Ошибка входа")),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text(String(localized: "Понятно")))
            )
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuth in
            if isAuth {
                coordinator.navigate(to: .roleSelect)
            }
        }
    }

    // MARK: - Sections

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
                    .frame(width: geo.size.width * 1.3, height: 360)
                    .offset(x: -geo.size.width * 0.15, y: -80)
            }
        }
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSMascotView(mood: .happy, size: 130)
                .padding(.top, SpacingTokens.sp16 + SpacingTokens.sp10)

            Text("HappySpeech")
                .font(TypographyTokens.kidDisplay(32))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }

    private var centerContent: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(localized: "Добро пожаловать!"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(String(localized: "Войдите, чтобы следить за прогрессом ребёнка"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp8)
        }
    }

    private var authButtonsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // Sign in with Apple
            SignInWithAppleButton { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await viewModel.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous))

            // Email sign-in
            HSButton(
                String(localized: "Войти через эл. почту"),
                style: .secondary,
                icon: "envelope"
            ) {
                coordinator.present(sheet: .settings) // TODO: replace with email auth sheet
            }

            // Registration
            Button {
                // Navigate to registration
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "Нет аккаунта?"))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Text(String(localized: "Создать"))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .fontWeight(.semibold)
                }
                .font(TypographyTokens.body(14))
            }
            .padding(.top, SpacingTokens.sp2)

            // Demo mode
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
}

// MARK: - AuthSignInViewModel

@Observable
@MainActor
final class AuthSignInViewModel {
    var isLoading: Bool = false
    var isAuthenticated: Bool = false
    var errorMessage: String?

    func handleAppleSignIn(result: Result<ASAuthorization, any Error>) async {
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = AppError.authSignInFailed("Неверный тип учётных данных").localizedDescription
                return
            }
            HSLogger.auth.info("Apple Sign In: \(credential.user)")
            isAuthenticated = true

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = AppError.authSignInFailed(error.localizedDescription).localizedDescription
        }
    }
}

// MARK: - Preview

#Preview("Auth Sign In") {
    AuthSignInView()
        .environment(AppCoordinator())
}
