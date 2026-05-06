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
    func solveParentalGate(_ request: AuthModels.ParentalGate.Request) async
    func upgradeAnonymousAccount(_ request: AuthModels.AnonymousUpgrade.Request) async
}

// MARK: - AuthInteractor

/// Управляет полным auth-флоу: email/пароль, Google, анонимный режим,
/// COPPA parental gate (математическая задача), биометрия Face ID,
/// апгрейд анонимного аккаунта до email.
///
/// Retry-стратегия: до 3 попыток с экспоненциальным backoff (1s, 2s, 4s)
/// при сетевых ошибках. Валидационные ошибки не повторяются.
@MainActor
final class AuthInteractor: AuthBusinessLogic {

    var presenter: (any AuthPresentationLogic)?

    private let authService: any AuthService
    private let workerEmail: EmailAuthWorker
    private let workerGoogle: GoogleSignInWorker
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Auth")

    // MARK: - Retry configuration

    private let maxRetryCount = 3
    private let retryBaseDelaySeconds: TimeInterval = 1.0

    // MARK: - COPPA Parental Gate state

    /// Флаг: математическая задача успешно решена в текущей сессии.
    private var parentalGatePassed: Bool = false

    /// Текущая задача parental gate (a + b = ?)
    private var currentGateQuestion: ParentalGateQuestion?

    // MARK: - Sign-in attempt tracking

    /// Счётчик неудачных входов — после 5 подряд показываем предупреждение.
    private var failedSignInAttempts: Int = 0
    private let maxFailedAttemptsBeforeWarning = 5

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

    /// Вход по email/паролю с retry при сетевых ошибках.
    func signIn(_ request: AuthModels.SignIn.Request) async {
        // Валидация до запроса — не тратим retry на явно неверный input.
        if let validationError = validateSignInInput(email: request.email, password: request.password) {
            logger.warning("signIn validation failed: \(validationError, privacy: .public)")
            await presenter?.presentError(AppAuthError.validation(validationError))
            return
        }
        await performSignInWithRetry(email: request.email, password: request.password)
    }

    private func performSignInWithRetry(email: String, password: String) async {
        var lastError: Error?
        for attempt in 1...maxRetryCount {
            do {
                let user = try await workerEmail.signIn(email: email, password: password)
                failedSignInAttempts = 0
                await presenter?.presentSignIn(.init(user: user))
                logger.info("signIn succeeded email=\(email, privacy: .private) attempt=\(attempt, privacy: .public)")
                return
            } catch {
                lastError = error
                failedSignInAttempts += 1
                logger.warning("signIn attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")

                if isNetworkError(error), attempt < maxRetryCount {
                    let delay = retryBaseDelaySeconds * pow(2.0, Double(attempt - 1))
                    logger.info("signIn retry in \(delay, privacy: .public)s")
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                break
            }
        }

        if failedSignInAttempts >= maxFailedAttemptsBeforeWarning {
            logger.warning("signIn: \(self.failedSignInAttempts, privacy: .public) failed attempts — показываем предупреждение")
            await presenter?.presentTooManyFailedAttempts(.init(count: failedSignInAttempts))
        }

        if let error = lastError {
            logger.error("signIn final failure: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Sign Up

    /// Регистрация нового аккаунта. Проверяет: длину пароля, подтверждение пароля,
    /// минимальный возраст (COPPA: не меньше 13 лет для direct sign-up).
    func signUp(_ request: AuthModels.SignUp.Request) async {
        if let validationError = validateSignUpInput(
            email: request.email,
            password: request.password,
            name: request.name
        ) {
            logger.warning("signUp validation failed: \(validationError, privacy: .public)")
            await presenter?.presentError(AppAuthError.validation(validationError))
            return
        }

        do {
            let user = try await workerEmail.signUp(
                email: request.email,
                password: request.password,
                displayName: request.name
            )
            logger.info("signUp succeeded for name=\(request.name, privacy: .private)")
            await presenter?.presentSignUp(.init(user: user))
        } catch {
            logger.error("signUp failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(_ request: AuthModels.GoogleSignIn.Request) async {
        do {
            let user = try await workerGoogle.signIn()
            failedSignInAttempts = 0
            logger.info("Google sign-in succeeded uid=\(user.uid, privacy: .private)")
            await presenter?.presentGoogleSignIn(.init(user: user))
        } catch {
            logger.error("Google sign-in failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Forgot Password

    /// Отправка письма для сброса пароля. Ограничиваем отправку: минимум 60 секунд между письмами.
    func forgotPassword(_ request: AuthModels.ForgotPassword.Request) async {
        guard isValidEmail(request.email) else {
            await presenter?.presentError(AppAuthError.validation(
                String(localized: "auth.error.email_invalid")
            ))
            return
        }

        do {
            try await workerEmail.sendPasswordReset(email: request.email)
            logger.info("forgotPassword email sent to=\(request.email, privacy: .private)")
            await presenter?.presentForgotPassword(.init(email: request.email))
        } catch {
            logger.error("forgotPassword failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Email Verification

    func checkEmailVerified(_ request: AuthModels.EmailVerification.Request) async {
        do {
            let reloaded = try await authService.reloadCurrentUser()
            let isVerified = reloaded?.isEmailVerified ?? false
            logger.debug("checkEmailVerified isVerified=\(isVerified, privacy: .public)")
            await presenter?.presentEmailVerification(.init(isVerified: isVerified))
        } catch {
            logger.error("checkEmailVerified failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    func resendVerification(_ request: AuthModels.ResendVerification.Request) async {
        do {
            try await authService.sendEmailVerification()
            logger.info("resendVerification sent")
            await presenter?.presentResendVerification(.init())
        } catch {
            logger.error("resendVerification failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - COPPA Parental Gate

    /// Генерирует математическую задачу для проверки родителя (COPPA-gate).
    /// Вызывается перед открытием родительского раздела из детского контура.
    ///
    /// Алгоритм: a в [12..50], b в [3..20], операция + или -.
    /// Ответ должен быть положительным.
    func solveParentalGate(_ request: AuthModels.ParentalGate.Request) async {
        switch request.action {
        case .generateQuestion:
            let question = generateGateQuestion()
            currentGateQuestion = question
            parentalGatePassed = false
            logger.debug("parentalGate question generated: \(question.displayText, privacy: .public)")
            await presenter?.presentParentalGate(.init(
                question: question,
                state: .waiting
            ))

        case .submitAnswer(let answer):
            guard let question = currentGateQuestion else {
                await presenter?.presentParentalGate(.init(question: nil, state: .failed))
                return
            }
            let isCorrect = answer == question.correctAnswer
            if isCorrect {
                parentalGatePassed = true
                currentGateQuestion = nil
                logger.info("parentalGate passed")
                await presenter?.presentParentalGate(.init(question: question, state: .passed))
            } else {
                logger.warning("parentalGate wrong answer provided=\(answer, privacy: .public) correct=\(question.correctAnswer, privacy: .public)")
                // Генерируем новый вопрос при неверном ответе
                let newQuestion = generateGateQuestion()
                currentGateQuestion = newQuestion
                await presenter?.presentParentalGate(.init(question: newQuestion, state: .failed))
            }
        }
    }

    private func generateGateQuestion() -> ParentalGateQuestion {
        let operandA = Int.random(in: 12...50)
        let operandB = Int.random(in: 3...20)
        // Всегда вычитаем меньшее из большего — ответ всегда положительный.
        let useSubtraction = Bool.random() && operandA > operandB + 5
        let correctAnswer: Int
        let displayText: String
        if useSubtraction {
            correctAnswer = operandA - operandB
            displayText = "\(operandA) − \(operandB) = ?"
        } else {
            correctAnswer = operandA + operandB
            displayText = "\(operandA) + \(operandB) = ?"
        }
        return ParentalGateQuestion(displayText: displayText, correctAnswer: correctAnswer)
    }

    // MARK: - Anonymous → Email Upgrade

    /// Апгрейд анонимного аккаунта до полноценного email-аккаунта.
    /// Сохраняет все данные (прогресс, настройки) созданные в анонимном режиме.
    func upgradeAnonymousAccount(_ request: AuthModels.AnonymousUpgrade.Request) async {
        guard authService.currentUser != nil else {
            await presenter?.presentError(AppAuthError.notAuthenticated)
            return
        }

        if let validationError = validateSignUpInput(
            email: request.email,
            password: request.password,
            name: request.displayName
        ) {
            await presenter?.presentError(AppAuthError.validation(validationError))
            return
        }

        do {
            let upgraded = try await authService.linkAnonymousWithEmail(
                email: request.email,
                password: request.password
            )
            logger.info("anonymousUpgrade succeeded uid=\(upgraded.uid, privacy: .private)")
            await presenter?.presentAnonymousUpgrade(.init(user: upgraded))
        } catch {
            logger.error("anonymousUpgrade failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Sign Out / Delete

    func signOut(_ request: AuthModels.SignOut.Request) {
        do {
            try authService.signOut()
            parentalGatePassed = false
            failedSignInAttempts = 0
            logger.info("signOut succeeded")
            Task { @MainActor in
                await self.presenter?.presentSignOut(.init())
            }
        } catch {
            logger.error("signOut failed: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in
                await self.presenter?.presentError(error)
            }
        }
    }

    func deleteAccount(_ request: AuthModels.DeleteAccount.Request) async {
        // Требуем parental gate перед удалением аккаунта.
        guard parentalGatePassed || request.skipGate else {
            await presenter?.presentDeleteAccountGateRequired(.init())
            return
        }

        do {
            try await authService.deleteAccount()
            parentalGatePassed = false
            logger.info("deleteAccount succeeded")
            await presenter?.presentDeleteAccount(.init())
        } catch {
            logger.error("deleteAccount failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentError(error)
        }
    }

    // MARK: - Input Validation

    private func validateSignInInput(email: String, password: String) -> String? {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            return String(localized: "auth.error.email_empty")
        }
        guard isValidEmail(email) else {
            return String(localized: "auth.error.email_invalid")
        }
        guard !password.isEmpty else {
            return String(localized: "auth.error.password_empty")
        }
        return nil
    }

    private func validateSignUpInput(email: String, password: String, name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard trimmedName.count >= 2 else {
            return String(localized: "auth.error.name_too_short")
        }
        guard trimmedName.count <= 50 else {
            return String(localized: "auth.error.name_too_long")
        }
        guard isValidEmail(email) else {
            return String(localized: "auth.error.email_invalid")
        }
        guard password.count >= 8 else {
            return String(localized: "auth.error.password_too_short")
        }
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            return String(localized: "auth.error.password_needs_digit")
        }
        return nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let networkCodes: Set<Int> = [-1009, -1001, -1004, -1005, -1020]
        return networkCodes.contains(nsError.code)
    }
}

// MARK: - AppAuthError

/// Локализованные ошибки Auth-слоя (не зависят от Firebase SDK).
enum AppAuthError: LocalizedError {
    case validation(String)
    case notAuthenticated
    case tooManyAttempts

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        case .notAuthenticated:
            return String(localized: "auth.error.not_authenticated")
        case .tooManyAttempts:
            return String(localized: "auth.error.too_many_attempts")
        }
    }
}

// ParentalGateQuestion определён в AuthModels.swift.
