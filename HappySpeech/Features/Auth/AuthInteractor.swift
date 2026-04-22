import Foundation
import OSLog

// MARK: - AuthBusinessLogic

@MainActor
protocol AuthBusinessLogic: AnyObject {
    func checkAuthState(_ request: AuthModels.AuthState.Request) async
    func signIn(_ request: AuthModels.SignIn.Request) async
    func signUp(_ request: AuthModels.SignUp.Request) async
    func signInWithGoogle(_ request: AuthModels.GoogleSignIn.Request) async
    func forgotPassword(_ request: AuthModels.ForgotPassword.Request) async
    func checkEmailVerified(_ request: AuthModels.EmailVerification.Request) async
    func resendVerification(_ request: AuthModels.ResendVerification.Request) async
    func signOut(_ request: AuthModels.SignOut.Request)
    func deleteAccount(_ request: AuthModels.DeleteAccount.Request) async
}

// MARK: - AuthInteractor

@MainActor
final class AuthInteractor: AuthBusinessLogic {

    var presenter: (any AuthPresentationLogic)?

    private let authService: any AuthService
    private let workerEmail: EmailAuthWorker
    private let workerGoogle: GoogleSignInWorker
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Auth")

    // MARK: - Init

    init(authService: any AuthService) {
        self.authService = authService
        self.workerEmail = EmailAuthWorker(authService: authService)
        self.workerGoogle = GoogleSignInWorker(authService: authService)
    }

    // MARK: - AuthState

    func checkAuthState(_ request: AuthModels.AuthState.Request) async {
        let user = authService.currentUser
        let response: AuthModels.AuthState.Response = user.map { .authenticated($0) } ?? .unauthenticated
        await presenter?.presentAuthState(response)
    }

    // MARK: - Sign In

    func signIn(_ request: AuthModels.SignIn.Request) async {
        do {
            let user = try await workerEmail.signIn(email: request.email, password: request.password)
            await presenter?.presentSignIn(.init(user: user))
        } catch {
            logger.error("signIn failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Sign Up

    func signUp(_ request: AuthModels.SignUp.Request) async {
        do {
            let user = try await workerEmail.signUp(
                email: request.email,
                password: request.password,
                displayName: request.name
            )
            await presenter?.presentSignUp(.init(user: user))
        } catch {
            logger.error("signUp failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Google

    func signInWithGoogle(_ request: AuthModels.GoogleSignIn.Request) async {
        do {
            let user = try await workerGoogle.signIn()
            await presenter?.presentGoogleSignIn(.init(user: user))
        } catch {
            logger.error("Google sign-in failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Forgot Password

    func forgotPassword(_ request: AuthModels.ForgotPassword.Request) async {
        do {
            try await workerEmail.sendPasswordReset(email: request.email)
            await presenter?.presentForgotPassword(.init(email: request.email))
        } catch {
            logger.error("forgotPassword failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Verify email

    func checkEmailVerified(_ request: AuthModels.EmailVerification.Request) async {
        do {
            let reloaded = try await authService.reloadCurrentUser()
            let isVerified = reloaded?.isEmailVerified ?? false
            await presenter?.presentEmailVerification(.init(isVerified: isVerified))
        } catch {
            logger.error("checkEmailVerified failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    func resendVerification(_ request: AuthModels.ResendVerification.Request) async {
        do {
            try await authService.sendEmailVerification()
            await presenter?.presentResendVerification(.init())
        } catch {
            logger.error("resendVerification failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Sign Out / Delete

    func signOut(_ request: AuthModels.SignOut.Request) {
        do {
            try authService.signOut()
            Task { @MainActor in
                await presenter?.presentSignOut(.init())
            }
        } catch {
            logger.error("signOut failed: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in
                await presenter?.presentError(error)
            }
        }
    }

    func deleteAccount(_ request: AuthModels.DeleteAccount.Request) async {
        do {
            try await authService.deleteAccount()
            await presenter?.presentDeleteAccount(.init())
        } catch {
            logger.error("deleteAccount failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }
}
