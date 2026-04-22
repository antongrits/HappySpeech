import Foundation
import UIKit

// MARK: - GoogleSignInWorker

/// Thin wrapper around `AuthService.signInWithGoogle()`.
/// The service itself resolves the presenting `UIViewController` via
/// `UIApplication.topViewController()`; this worker exists so that the
/// Interactor is symmetrical with `EmailAuthWorker` and so that future
/// presenting-VC injection (e.g. for UI tests) can happen in one place.
@MainActor
final class GoogleSignInWorker {

    private let authService: any AuthService

    init(authService: any AuthService) {
        self.authService = authService
    }

    func signIn() async throws -> AuthUser {
        try await authService.signInWithGoogle()
    }
}
