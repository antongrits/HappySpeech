import Foundation

// MARK: - AuthUser

/// Minimal, Sendable representation of an authenticated user.
/// Features never hold a reference to Firebase types — only this value type.
public struct AuthUser: Sendable, Equatable {
    public let uid: String
    public let email: String?
    public let displayName: String?
    public let isAnonymous: Bool
    public let isEmailVerified: Bool

    public init(
        uid: String,
        email: String? = nil,
        displayName: String? = nil,
        isAnonymous: Bool = false,
        isEmailVerified: Bool = false
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isAnonymous = isAnonymous
        self.isEmailVerified = isEmailVerified
    }
}

// MARK: - AuthService

/// Abstracts FirebaseAuth + Google Sign-In for the rest of the app.
/// Kid circuit MUST NOT receive an `AuthService` reference directly — auth operations
/// are parent/specialist circuit only.
public protocol AuthService: AnyObject, Sendable {

    /// Currently signed-in user, or `nil` if unauthenticated.
    var currentUser: AuthUser? { get }

    // MARK: Email + Password

    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(email: String, password: String, displayName: String) async throws -> AuthUser
    func sendPasswordReset(email: String) async throws
    func sendEmailVerification() async throws
    /// Reloads the current user from the server so that `isEmailVerified` reflects the latest state.
    func reloadCurrentUser() async throws -> AuthUser?

    // MARK: Google Sign-In

    /// Resolves a presenting view controller internally via `UIApplication.topViewController()`.
    func signInWithGoogle() async throws -> AuthUser

    // MARK: Anonymous

    func signInAnonymously() async throws -> AuthUser
    func linkAnonymousWithEmail(email: String, password: String) async throws -> AuthUser

    // MARK: Account management

    func signOut() throws
    func deleteAccount() async throws

    // MARK: State

    /// Returns an opaque Firebase listener handle which must be kept alive by the caller.
    /// Pass the same handle back to `removeAuthStateListener(_:)` for removal.
    @discardableResult
    func addAuthStateListener(_ listener: @escaping @Sendable (AuthUser?) -> Void) -> Any

    func removeAuthStateListener(_ handle: Any)
}
