import Foundation

// MARK: - AuthPresenter

@MainActor
final class AuthPresenter: AuthPresentationLogic {

    weak var viewModel: (any AuthDisplayLogic)?

    func presentAuthState(_ response: AuthModels.AuthState.Response) async {
        switch response {
        case .authenticated(let user):
            viewModel?.displayAuthState(.init(
                isAuthenticated: true,
                isAnonymous: user.isAnonymous,
                isEmailVerified: user.isEmailVerified,
                displayName: user.displayName
            ))
        case .unauthenticated:
            viewModel?.displayAuthState(.init(
                isAuthenticated: false,
                isAnonymous: false,
                isEmailVerified: false,
                displayName: nil
            ))
        }
    }

    func presentSignIn(_ response: AuthModels.SignIn.Response) async {
        let welcome: String = {
            if let name = response.user.displayName, !name.isEmpty {
                return String(localized: "С возвращением, \(name)!")
            }
            return String(localized: "С возвращением!")
        }()

        viewModel?.displaySignIn(.init(
            welcomeMessage: welcome,
            requiresEmailVerification: !response.user.isEmailVerified && response.user.email != nil
        ))
    }

    func presentSignUp(_ response: AuthModels.SignUp.Response) async {
        viewModel?.displaySignUp(.init(
            successMessage: String(localized: "Аккаунт создан. Мы отправили письмо для подтверждения почты."),
            email: response.user.email ?? ""
        ))
    }

    func presentGoogleSignIn(_ response: AuthModels.GoogleSignIn.Response) async {
        let name = response.user.displayName ?? String(localized: "друг")
        viewModel?.displayGoogleSignIn(.init(welcomeMessage: String(localized: "Добро пожаловать, \(name)!")))
    }

    func presentForgotPassword(_ response: AuthModels.ForgotPassword.Response) async {
        viewModel?.displayForgotPassword(.init(
            successMessage: String(localized: "Письмо со ссылкой для восстановления отправлено на \(response.email).")
        ))
    }

    func presentEmailVerification(_ response: AuthModels.EmailVerification.Response) async {
        let message = response.isVerified
            ? String(localized: "Почта подтверждена.")
            : String(localized: "Пока не видим подтверждения. Проверьте почту ещё раз.")

        viewModel?.displayEmailVerification(.init(
            message: message,
            isVerified: response.isVerified
        ))
    }

    func presentResendVerification(_ response: AuthModels.ResendVerification.Response) async {
        viewModel?.displayResendVerification(.init(
            message: String(localized: "Письмо отправлено. Проверьте входящие.")
        ))
    }

    func presentSignOut(_ response: AuthModels.SignOut.Response) async {
        viewModel?.displaySignOut(.init())
    }

    func presentDeleteAccount(_ response: AuthModels.DeleteAccount.Response) async {
        viewModel?.displayDeleteAccount(.init())
    }

    func presentError(_ error: any Error) async {
        let title: String = String(localized: "Ошибка")
        let message: String
        if let appError = error as? AppError {
            message = appError.errorDescription ?? appError.localizedDescription
        } else {
            message = error.localizedDescription
        }
        viewModel?.displayError(.init(title: title, message: message))
    }

    // MARK: - D.1 v15 — новые методы

    func presentParentalGate(_ response: AuthModels.ParentalGate.Response) async {
        let stateString: String
        switch response.state {
        case .waiting: stateString = "waiting"
        case .passed:  stateString = "passed"
        case .failed:  stateString = "failed"
        }
        let questionText = response.question?.displayText ?? String(localized: "auth.parental_gate.question.default")
        viewModel?.displayParentalGate(.init(questionText: questionText, state: stateString))
    }

    func presentAnonymousUpgrade(_ response: AuthModels.AnonymousUpgrade.Response) async {
        let name = response.user.displayName ?? String(localized: "auth.anonymous_upgrade.default_name")
        viewModel?.displayAnonymousUpgrade(.init(
            successMessage: String(localized: "auth.anonymous_upgrade.success")
        ))
        _ = name
    }

    func presentTooManyFailedAttempts(_ response: AuthModels.TooManyFailedAttempts.Response) async {
        let message = String(
            format: String(localized: "auth.error.too_many_attempts.format"),
            response.count
        )
        viewModel?.displayTooManyFailedAttempts(.init(message: message))
    }

    func presentDeleteAccountGateRequired(_ response: AuthModels.DeleteAccountGateRequired.Response) async {
        viewModel?.displayDeleteAccountGateRequired(.init(
            message: String(localized: "auth.delete_account.gate_required")
        ))
    }
}
