@testable import HappySpeech
import XCTest

// MARK: - SpecialistInteractorTests
//
// M10.1 — 5 тестов для SpecialistInteractor.
// Покрывает: fetch, update, openSessionReview (empty/valid id),
// начальное состояние presenter.

@MainActor
final class SpecialistInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SpecialistPresentationLogic {
        var fetchCalled = false
        var updateCalled = false

        func presentFetch(_ response: SpecialistModels.Fetch.Response) {
            fetchCalled = true
        }
        func presentUpdate(_ response: SpecialistModels.Update.Response) {
            updateCalled = true
        }
        func presentChildDashboard(_ response: SpecialistModels.FetchChildDashboard.Response) {}
        func presentSaveNote(_ response: SpecialistModels.SaveNote.Response) {}
        func presentFetchNotes(_ response: SpecialistModels.FetchNotes.Response) {}
        func presentExport(_ response: SpecialistModels.RequestExport.Response) {}
        func presentSendMessage(_ response: SpecialistModels.SendParentMessage.Response) {}
        func presentDeleteNote(_ response: SpecialistModels.DeleteNote.Response) {}
        func presentError(_ message: String) {}
    }

    // MARK: - Stubs

    private final class StubExportService: SpecialistExportService, @unchecked Sendable {
        func generatePDF(childId: String, sessions: [SessionDTO]) async throws -> URL {
            URL(fileURLWithPath: "/tmp/test.pdf")
        }
        func generateCSV(childId: String, sessions: [SessionDTO]) async throws -> URL {
            URL(fileURLWithPath: "/tmp/test.csv")
        }
    }

    private final class StubFCMService: FCMService, @unchecked Sendable {
        func requestPermission() async -> Bool { false }
        func registerForRemoteNotifications() async {}
        func syncTokenToFirestore(userId: String) async throws {}
        func unregisterToken(userId: String) async throws {}
    }

    // MARK: - Helpers

    private func makeSUT() -> (SpecialistInteractor, SpyPresenter) {
        let sut = SpecialistInteractor(
            childRepository: MockChildRepository(children: []),
            sessionRepository: MockSessionRepository(sessions: []),
            exportService: StubExportService(),
            llmDecisionService: MockLLMDecisionService(),
            fcmService: StubFCMService()
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    private func makeSUTWithRouter() -> (SpecialistInteractor, SpyPresenter, SpecialistRouter) {
        let sut = SpecialistInteractor(
            childRepository: MockChildRepository(children: []),
            sessionRepository: MockSessionRepository(sessions: []),
            exportService: StubExportService(),
            llmDecisionService: MockLLMDecisionService(),
            fcmService: StubFCMService()
        )
        let spy = SpyPresenter()
        let router = SpecialistRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.presenter = spy
        sut.router = router
        return (sut, spy, router)
    }

    // MARK: - 1. fetch вызывает presentFetch

    func test_fetch_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.fetch(.init())
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(spy.fetchCalled)
    }

    // MARK: - 2. update вызывает presentUpdate

    func test_update_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.update(.init())
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(spy.updateCalled)
    }

    // MARK: - 3. openSessionReview с пустым id пропускает роутер

    func test_openSessionReview_emptyId_doesNotCallRouter() {
        let (sut, _, router) = makeSUTWithRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.openSessionReview(sessionId: "")
        XCTAssertNil(routedId)
    }

    // MARK: - 4. openSessionReview с корректным id → колбэк роутера вызывается

    func test_openSessionReview_validId_callsRouterCallback() {
        let (sut, _, router) = makeSUTWithRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.openSessionReview(sessionId: "session-42")
        XCTAssertEqual(routedId, "session-42")
    }

    // MARK: - 5. presenter по умолчанию nil, что не крашит fetch

    func test_init_presenterNil_fetchDoesNotCrash() async throws {
        let (sut, _) = makeSUT()
        sut.presenter = nil
        // presenter не установлен — должен вызываться без краша
        sut.fetch(.init())
        try await Task.sleep(nanoseconds: 200_000_000)
        // если мы здесь — нет краша
        XCTAssertTrue(true)
    }
}
