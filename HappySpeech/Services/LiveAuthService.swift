import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

// MARK: - LiveAuthService

/// FirebaseAuth + GoogleSignIn backed implementation of `AuthService`.
/// Thread-safe via `@unchecked Sendable` + `nonisolated(unsafe)` mutable state, mirroring
/// the pattern used by `LiveAudioService`. All Firebase SDK calls are internally thread-safe.
public final class LiveAuthService: AuthService, @unchecked Sendable {

    // MARK: - Init

    public init() {
        Self.configureGoogleSignIn()
    }

    // MARK: - AuthService

    public var currentUser: AuthUser? {
        Self.mapUser(Auth.auth().currentUser)
    }

    // MARK: Email + Password

    public func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            HSLogger.auth.info("Email sign-in success uid=\(result.user.uid, privacy: .private)")
            return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func signUp(email: String, password: String, displayName: String) async throws -> AuthUser {
        do {
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

            HSLogger.auth.info("Email sign-up success uid=\(result.user.uid, privacy: .private)")
            return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            HSLogger.auth.info("Password reset email sent")
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AppError.authUserNotFound
        }
        do {
            try await user.sendEmailVerification()
            HSLogger.auth.info("Verification email sent")
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func reloadCurrentUser() async throws -> AuthUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        do {
            try await user.reload()
            return Self.mapUser(Auth.auth().currentUser)
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

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )

        do {
            let result = try await Auth.auth().signIn(with: credential)
            HSLogger.auth.info("Google sign-in success uid=\(result.user.uid, privacy: .private)")
            return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    // MARK: Anonymous

    public func signInAnonymously() async throws -> AuthUser {
        do {
            let result = try await Auth.auth().signInAnonymously()
            HSLogger.auth.info("Anonymous sign-in success uid=\(result.user.uid, privacy: .private)")
            return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
        } catch {
            throw Self.mapFirebaseError(error, fallback: .authSignInFailed(error.localizedDescription))
        }
    }

    public func linkAnonymousWithEmail(email: String, password: String) async throws -> AuthUser {
        guard let user = Auth.auth().currentUser, user.isAnonymous else {
            throw AppError.authUserNotFound
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            let result = try await user.link(with: credential)
            HSLogger.auth.info("Anonymous→Email link success uid=\(result.user.uid, privacy: .private)")
            return Self.mapUser(result.user) ?? Self.fallback(result.user.uid)
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

    public func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AppError.authUserNotFound
        }
        do {
            try await user.delete()
            GIDSignIn.sharedInstance.signOut()
            HSLogger.auth.info("Account deleted")
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
