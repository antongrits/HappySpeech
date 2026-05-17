@testable import HappySpeech
import XCTest

// MARK: - GoogleSignInWorkerTests
//
// Phase 2.7 v25 — покрытие GoogleSignInWorker.
//
// GoogleSignInWorker — тонкая обёртка над AuthService.signInWithGoogle().
// Тестируется: успешный проброс результата и проброс ошибки сервиса.

@MainActor
final class GoogleSignInWorkerTests: XCTestCase {

    private var authService: SpyAuthService!
    private var sut: GoogleSignInWorker!

    override func setUp() {
        super.setUp()
        authService = SpyAuthService()
        sut = GoogleSignInWorker(authService: authService)
    }

    override func tearDown() {
        sut = nil
        authService = nil
        super.tearDown()
    }

    // MARK: - Успех

    func test_signIn_success_returnsUser() async throws {
        let user = try await sut.signIn()
        XCTAssertEqual(user.uid, authService.stubbedUser?.uid)
    }

    func test_signIn_success_returnsCustomStubbedUser() async throws {
        let custom = TestDataBuilder.authUser(uid: "google-uid-42", email: "g@example.com")
        authService.stubbedUser = custom
        let user = try await sut.signIn()
        XCTAssertEqual(user.uid, "google-uid-42")
        XCTAssertEqual(user.email, "g@example.com")
    }

    // MARK: - Ошибка

    func test_signIn_serviceFailure_throwsGoogleCancelled() async {
        authService.shouldFail = true
        do {
            _ = try await sut.signIn()
            XCTFail("Ожидалась ошибка отмены входа через Google")
        } catch let error as AppError {
            XCTAssertEqual(error, .authGoogleCancelled)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }
}
