import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import UIKit

// MARK: - LiveAuthService

/// FirebaseAuth + GoogleSignIn backed implementation of `AuthService`.
/// Thread-safe via `@unchecked Sendable` + `nonisolated(unsafe)` mutable state, mirroring
/// the pattern used by `LiveAudioService`. All Firebase SDK calls are internally thread-safe.
public final class LiveAuthService: AuthService, @unchecked Sendable {

    // MARK: - Account-deletion collaborators

    /// Облачный каскад удаления (Cloud Function `deleteUserData`): чистит Firestore,
    /// Storage и сам Firebase Auth-аккаунт. Вызывается ДО локальной очистки и signOut,
    /// пока пользователь ещё аутентифицирован. `nil` в тестах/preview без сети.
    private let cloudDataDeleter: (@Sendable (_ userId: String) async throws -> Void)?

    /// Полная очистка локального Realm. Вызывается после успешного облачного каскада,
    /// чтобы данные ребёнка не осиротели на устройстве. `nil` — пропускается.
    private let localDataWiper: (@Sendable () async throws -> Void)?

    // MARK: - Init

    /// - Parameters:
    ///   - cloudDataDeleter: Облачный каскад (`CloudFunctionsServiceProtocol.deleteUserData`).
    ///   - localDataWiper: Полная очистка локального Realm (`RealmActor.deleteAllData`).
    public init(
        cloudDataDeleter: (@Sendable (_ userId: String) async throws -> Void)? = nil,
        localDataWiper: (@Sendable () async throws -> Void)? = nil
    ) {
        self.cloudDataDeleter = cloudDataDeleter
        self.localDataWiper = localDataWiper
        Self.configureGoogleSignIn()
    }

    // MARK: - AuthService

    public var currentUser: AuthUser? {
        Self.mapUser(Auth.auth().currentUser)
    }

    // MARK: Email + Password

    public func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            // Маппинг в Sendable-AuthUser выполняется внутри замысла-операции:
            // через границу task group уходит только Sendable-значение, а не
            // несендабельный FirebaseAuth.AuthDataResult.
            let user = try await Self.withAuthTimeout {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
            }
            HSLogger.auth.info("Email sign-in success uid=\(user.uid, privacy: .private)")
            return user
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func signUp(email: String, password: String, displayName: String) async throws -> AuthUser {
        do {
            // Весь многошаговый сетевой sign-up выполняется под единым тайм-аутом;
            // наружу отдаём только Sendable-AuthUser.
            let user = try await Self.withAuthTimeout {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)

                // Update displayName
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()

                // Send verification email (non-fatal if it fails)
                do {
                    try await result.user.sendEmailVerification()
                } catch {
                    HSLogger.auth.error("sendEmailVerification after signUp failed: \(error)")
                }

                return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
            }

            HSLogger.auth.info("Email sign-up success uid=\(user.uid, privacy: .private)")
            return user
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func sendPasswordReset(email: String) async throws {
        do {
            try await Self.withAuthTimeout {
                try await Auth.auth().sendPasswordReset(withEmail: email)
            }
            HSLogger.auth.info("Password reset email sent")
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func sendEmailVerification() async throws {
        guard Auth.auth().currentUser != nil else {
            throw AppError.authUserNotFound
        }
        do {
            try await Self.withAuthTimeout {
                guard let user = Auth.auth().currentUser else {
                    throw AppError.authUserNotFound
                }
                try await user.sendEmailVerification()
            }
            HSLogger.auth.info("Verification email sent")
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func reloadCurrentUser() async throws -> AuthUser? {
        guard Auth.auth().currentUser != nil else { return nil }
        do {
            return try await Self.withAuthTimeout {
                guard let user = Auth.auth().currentUser else { return nil }
                try await user.reload()
                return Self.mapUser(Auth.auth().currentUser)
            }
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    // MARK: Google Sign-In

    @MainActor
    public func signInWithGoogle() async throws -> AuthUser {
        guard FirebaseApp.app() != nil,
              let clientID = FirebaseApp.app()?.options.clientID else {
            throw AppError.authConfigurationMissing
        }

        // Ensure GoogleSignIn configuration is applied.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenting = UIApplication.topViewController() else {
            throw AppError.authConfigurationMissing
        }

        let gidResult: GIDSignInResult
        do {
            gidResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        } catch {
            if Self.isGoogleCancellation(error) {
                throw AppError.authGoogleCancelled
            }
            throw AppError.authSignInFailed(error.localizedDescription)
        }

        guard let idToken = gidResult.user.idToken?.tokenString else {
            throw AppError.authInvalidCredential
        }
        let accessToken = gidResult.user.accessToken.tokenString

        do {
            // Credential строится внутри операции из Sendable-строк (idToken/accessToken),
            // чтобы не протаскивать несендабельный AuthCredential в @Sendable-замысел.
            let user = try await Self.withAuthTimeout {
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: accessToken
                )
                let result = try await Auth.auth().signIn(with: credential)
                return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
            }
            HSLogger.auth.info("Google sign-in success uid=\(user.uid, privacy: .private)")
            return user
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    // MARK: Anonymous

    public func signInAnonymously() async throws -> AuthUser {
        do {
            let user = try await Self.withAuthTimeout {
                let result = try await Auth.auth().signInAnonymously()
                return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
            }
            HSLogger.auth.info("Anonymous sign-in success uid=\(user.uid, privacy: .private)")
            return user
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func linkAnonymousWithEmail(email: String, password: String) async throws -> AuthUser {
        guard let current = Auth.auth().currentUser, current.isAnonymous else {
            throw AppError.authUserNotFound
        }
        do {
            // Текущий пользователь и credential разрешаются внутри операции —
            // несендабельные FirebaseAuth-объекты не пересекают границу task group.
            let user = try await Self.withAuthTimeout {
                guard let user = Auth.auth().currentUser, user.isAnonymous else {
                    throw AppError.authUserNotFound
                }
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                let result = try await user.link(with: credential)
                return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
            }
            HSLogger.auth.info("Anonymous→Email link success uid=\(user.uid, privacy: .private)")
            return user
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    // MARK: Account management

    public func signOut() throws {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
            HSLogger.auth.info("Signed out")
        } catch {
            HSLogger.auth.error("signOut failed: \(error)")
            throw AppError.authSignOutFailed
        }
    }

    /// Удаляет аккаунт целиком (COPPA / GDPR right-to-erasure).
    ///
    /// Порядок критичен и выполняется, пока пользователь ещё аутентифицирован:
    ///   1. Облачный каскад `deleteUserData` — Firestore + Storage + Firebase Auth-аккаунт.
    ///      Должен пройти первым: после удаления Auth облако уже не очистить.
    ///   2. Полная очистка локального Realm — чтобы данные ребёнка не осиротели на устройстве.
    ///   3. Локальный `signOut` — очистка сессии Firebase Auth и GoogleSignIn.
    ///
    /// Если каскад упал — прерываемся с ошибкой, НЕ удаляя ничего молча: пользователь
    /// останется в аккаунте и сможет повторить (целостность важнее «частичного» удаления).
    ///
    /// Когда облачный каскад не сконфигурирован (legacy / preview без сети), падаем
    /// на прямой `user.delete()` Firebase Auth, чтобы аккаунт всё же был удалён.
    public func deleteAccount() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AppError.authUserNotFound
        }

        do {
            if let cloudDataDeleter {
                // (1) Облачный каскад — пока ещё аутентифицированы. Каскад удаляет
                // и сам Auth-аккаунт, поэтому отдельный user.delete() далее не нужен.
                try await cloudDataDeleter(userId)

                // (2) Локальная очистка Realm.
                if let localDataWiper {
                    try await localDataWiper()
                }

                // (3) Сброс локальной (уже устаревшей) сессии.
                GIDSignIn.sharedInstance.signOut()
                try? Auth.auth().signOut()
                HSLogger.auth.info("Account deleted (cloud cascade + local wipe + signOut)")
            } else {
                // Fallback без облачного каскада: удаляем только Auth-аккаунт.
                // Текущий пользователь резолвится внутри операции, чтобы несендабельный
                // FirebaseAuth.User не захватывался @Sendable-замыслом task group.
                try await Self.withAuthTimeout {
                    guard let user = Auth.auth().currentUser else {
                        throw AppError.authUserNotFound
                    }
                    try await user.delete()
                }
                if let localDataWiper {
                    try await localDataWiper()
                }
                GIDSignIn.sharedInstance.signOut()
                HSLogger.auth.info("Account deleted (Auth-only fallback + local wipe)")
            }
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    // MARK: State

    @discardableResult
    public func addAuthStateListener(_ listener: @escaping @Sendable (AuthUser?) -> Void) -> Any {
        let handle = Auth.auth().addStateDidChangeListener { _, user in
            listener(Self.mapUser(user))
        }
        return handle
    }

    public func removeAuthStateListener(_ handle: Any) {
        if let handle = handle as? AuthStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Private helpers

    /// Максимальное время ожидания сетевого вызова Firebase Auth.
    /// Офлайн / неотвечающий App Check может «подвесить» SDK-вызов навсегда —
    /// этот предел гарантирует, что UI не зависнет, а пользователь получит
    /// понятную ошибку (и сможет уйти в демо-режим).
    private static let authTimeout: Duration = .seconds(20)

    /// Запускает сетевую Firebase-операцию с жёстким тайм-аутом.
    ///
    /// Гонка двух задач: сам вызов и `Task.sleep`. Если первым завершается сон —
    /// бросаем `AppError.networkTimeout` и отменяем операцию. Иначе возвращаем
    /// результат вызова и снимаем таймер.
    private static func withAuthTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: authTimeout)
                throw AppError.networkTimeout
            }
            // Первый завершившийся результат — победитель; остальное отменяем.
            guard let result = try await group.next() else {
                throw AppError.networkTimeout
            }
            group.cancelAll()
            return result
        }
    }

    private static func configureGoogleSignIn() {
        guard let app = FirebaseApp.app() else {
            HSLogger.auth.error("FirebaseApp not configured before LiveAuthService init — GoogleSignIn left unconfigured.")
            return
        }
        guard let clientID = app.options.clientID else {
            HSLogger.auth.error("FirebaseApp options.clientID is missing — GoogleSignIn left unconfigured.")
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    private static func mapUser(_ user: User?) -> AuthUser? {
        guard let user else { return nil }
        return AuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            isAnonymous: user.isAnonymous,
            isEmailVerified: user.isEmailVerified
        )
    }

    private static func fallback(_ uid: String) -> AuthUser {
        AuthUser(uid: uid)
    }

    private static func isGoogleCancellation(_ error: any Error) -> Bool {
        let nsErr = error as NSError
        if nsErr.domain == "com.google.GIDSignIn" || nsErr.domain.contains("GoogleSignIn") {
            // GIDSignInErrorCode.canceled.rawValue == -5
            return nsErr.code == -5
        }
        return false
    }

    private static func mapFirebaseError(_ error: any Error, fallback: AppError) -> AppError {
        // Уже доменная ошибка приложения (например, тайм-аут из withAuthTimeout) —
        // пробрасываем без перезаписи, чтобы пользователь увидел корректное сообщение.
        if let appError = error as? AppError {
            return appError
        }
        let nsErr = error as NSError
        guard nsErr.domain == AuthErrorDomain else {
            return fallback
        }
        guard let code = AuthErrorCode(rawValue: nsErr.code) else {
            return fallback
        }
        switch code {
        case .emailAlreadyInUse:
            return .authEmailAlreadyInUse
        case .weakPassword:
            return .authWeakPassword
        case .networkError:
            return .authNetworkError
        case .userNotFound:
            return .authUserNotFound
        case .wrongPassword, .invalidCredential, .invalidEmail:
            return .authInvalidCredential
        case .userTokenExpired, .requiresRecentLogin:
            return .authTokenExpired
        default:
            return fallback
        }
    }
}
