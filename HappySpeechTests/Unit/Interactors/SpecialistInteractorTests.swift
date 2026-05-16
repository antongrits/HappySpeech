@testable import HappySpeech
import XCTest

// MARK: - SpecialistInteractorTests
//
// M10.1 — базовое покрытие (5 тестов).
// Plan v25 2.8.2 — расширено до 90%+: fetch (сортировки, поиск, ошибка),
// fetchChildDashboard, saveNote/fetchNotes/deleteNote, requestExport (PDF/CSV/ошибка),
// sendParentMessage, диагностические хелперы.

@MainActor
final class SpecialistInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SpecialistPresentationLogic {
        var fetchCalled = false
        var updateCalled = false
        var childDashboardCalled = false
        var saveNoteCalled = false
        var fetchNotesCalled = false
        var exportCalled = false
        var sendMessageCalled = false
        var deleteNoteCalled = false
        var errorCalled = false

        var lastFetch: SpecialistModels.Fetch.Response?
        var lastDashboard: SpecialistModels.FetchChildDashboard.Response?
        var lastSaveNote: SpecialistModels.SaveNote.Response?
        var lastFetchNotes: SpecialistModels.FetchNotes.Response?
        var lastExport: SpecialistModels.RequestExport.Response?
        var lastSendMessage: SpecialistModels.SendParentMessage.Response?
        var lastDeleteNote: SpecialistModels.DeleteNote.Response?
        var lastError: String?

        func presentFetch(_ response: SpecialistModels.Fetch.Response) {
            fetchCalled = true
            lastFetch = response
        }
        func presentUpdate(_ response: SpecialistModels.Update.Response) {
            updateCalled = true
        }
        func presentChildDashboard(_ response: SpecialistModels.FetchChildDashboard.Response) {
            childDashboardCalled = true
            lastDashboard = response
        }
        func presentSaveNote(_ response: SpecialistModels.SaveNote.Response) {
            saveNoteCalled = true
            lastSaveNote = response
        }
        func presentFetchNotes(_ response: SpecialistModels.FetchNotes.Response) {
            fetchNotesCalled = true
            lastFetchNotes = response
        }
        func presentExport(_ response: SpecialistModels.RequestExport.Response) {
            exportCalled = true
            lastExport = response
        }
        func presentSendMessage(_ response: SpecialistModels.SendParentMessage.Response) {
            sendMessageCalled = true
            lastSendMessage = response
        }
        func presentDeleteNote(_ response: SpecialistModels.DeleteNote.Response) {
            deleteNoteCalled = true
            lastDeleteNote = response
        }
        func presentError(_ message: String) {
            errorCalled = true
            lastError = message
        }
    }

    // MARK: - Stubs

    private final class StubExportService: SpecialistExportService, @unchecked Sendable {
        var shouldFail = false
        func generatePDF(childId: String, sessions: [SessionDTO]) async throws -> URL {
            if shouldFail { throw AppError.realmReadFailed("forced") }
            return URL(fileURLWithPath: "/tmp/test.pdf")
        }
        func generateCSV(childId: String, sessions: [SessionDTO]) async throws -> URL {
            if shouldFail { throw AppError.realmReadFailed("forced") }
            return URL(fileURLWithPath: "/tmp/test.csv")
        }
    }

    private final class StubFCMService: FCMService, @unchecked Sendable {
        func requestPermission() async -> Bool { false }
        func registerForRemoteNotifications() async {}
        func syncTokenToFirestore(userId: String) async throws {}
        func unregisterToken(userId: String) async throws {}
    }

    // MARK: - Helpers

    private func makeSUT(
        children: [ChildProfileDTO] = [],
        sessions: [SessionDTO] = [],
        exportService: StubExportService = StubExportService(),
        childRepoFails: Bool = false
    ) -> (SpecialistInteractor, SpyPresenter) {
        let childRepo = SpyChildRepository(children: children)
        childRepo.shouldFail = childRepoFails
        let sut = SpecialistInteractor(
            childRepository: childRepo,
            sessionRepository: SpySessionRepository(sessions: sessions),
            exportService: exportService,
            llmDecisionService: MockLLMDecisionService(),
            fcmService: StubFCMService()
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    private func makeChildren() -> [ChildProfileDTO] {
        [
            TestDataBuilder.childProfile(
                id: "c-anya", name: "Аня", age: 6,
                progressSummary: ["Р": 0.9], lastSessionAt: Date()
            ),
            TestDataBuilder.childProfile(
                id: "c-boris", name: "Борис", age: 7,
                progressSummary: ["Ш": 0.4],
                lastSessionAt: Date().addingTimeInterval(-86_400)
            ),
            TestDataBuilder.childProfile(
                id: "c-vera", name: "Вера", age: 5,
                progressSummary: ["С": 0.7], lastSessionAt: nil
            )
        ]
    }

    private func waitTick() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    // MARK: - 1. fetch вызывает presentFetch

    func test_fetch_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.fetch(.init())
        try await waitTick()
        XCTAssertTrue(spy.fetchCalled)
    }

    // MARK: - 2. update вызывает presentUpdate

    func test_update_callsPresenter() async throws {
        let (sut, spy) = makeSUT()
        sut.update(.init())
        try await waitTick()
        XCTAssertTrue(spy.updateCalled)
    }

    // MARK: - 3. openSessionReview с пустым id пропускает роутер

    func test_openSessionReview_emptyId_doesNotCallRouter() {
        let (sut, _) = makeSUT()
        let router = SpecialistRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.router = router
        sut.openSessionReview(sessionId: "")
        XCTAssertNil(routedId)
    }

    // MARK: - 4. openSessionReview с корректным id → колбэк

    func test_openSessionReview_validId_callsRouterCallback() {
        let (sut, _) = makeSUT()
        let router = SpecialistRouter()
        var routedId: String?
        router.onOpenSessionReview = { id in routedId = id }
        sut.router = router
        sut.openSessionReview(sessionId: "session-42")
        XCTAssertEqual(routedId, "session-42")
    }

    // MARK: - 5. presenter nil не крашит fetch

    func test_init_presenterNil_fetchDoesNotCrash() async throws {
        let (sut, _) = makeSUT()
        sut.presenter = nil
        sut.fetch(.init())
        try await waitTick()
        XCTAssertTrue(true)
    }

    // MARK: - 6. fetch загружает caseload и маппит entries

    func test_fetch_withChildren_mapsEntries() async throws {
        let (sut, spy) = makeSUT(children: makeChildren())
        sut.fetch(.init())
        try await waitTick()
        XCTAssertEqual(spy.lastFetch?.children.count, 3)
    }

    // MARK: - 7. fetch сортировка по имени

    func test_fetch_sortByName_sortsAlphabetically() async throws {
        let (sut, spy) = makeSUT(children: makeChildren())
        sut.fetch(.init(sortOrder: .byName, searchQuery: ""))
        try await waitTick()
        let names = spy.lastFetch?.children.map(\.name) ?? []
        XCTAssertEqual(names, names.sorted())
    }

    // MARK: - 8. fetch сортировка по прогрессу

    func test_fetch_sortByProgress_sortsDescending() async throws {
        let (sut, spy) = makeSUT(children: makeChildren())
        sut.fetch(.init(sortOrder: .byProgress, searchQuery: ""))
        try await waitTick()
        let rates = spy.lastFetch?.children.map(\.overallSuccessRate) ?? []
        XCTAssertEqual(rates, rates.sorted(by: >))
    }

    // MARK: - 9. fetch сортировка по активности

    func test_fetch_sortByLastActivity_recentFirst() async throws {
        let (sut, spy) = makeSUT(children: makeChildren())
        sut.fetch(.init(sortOrder: .byLastActivity, searchQuery: ""))
        try await waitTick()
        let first = spy.lastFetch?.children.first
        XCTAssertEqual(first?.id, "c-anya")
    }

    // MARK: - 10. fetch с поисковым запросом фильтрует

    func test_fetch_searchQuery_filtersByName() async throws {
        let (sut, spy) = makeSUT(children: makeChildren())
        sut.fetch(.init(sortOrder: .byName, searchQuery: "бор"))
        try await waitTick()
        XCTAssertEqual(spy.lastFetch?.children.count, 1)
        XCTAssertEqual(spy.lastFetch?.children.first?.name, "Борис")
    }

    // MARK: - 11. fetch при ошибке репозитория → presentError

    func test_fetch_repositoryFails_callsError() async throws {
        let (sut, spy) = makeSUT(children: makeChildren(), childRepoFails: true)
        sut.fetch(.init())
        try await waitTick()
        XCTAssertTrue(spy.errorCalled)
        XCTAssertFalse(spy.lastError?.isEmpty ?? true)
    }

    // MARK: - 12. fetchChildDashboard happy path

    func test_fetchChildDashboard_buildsResponse() async {
        let children = makeChildren()
        let sessions = [
            TestDataBuilder.session(childId: "c-anya", targetSound: "Р"),
            TestDataBuilder.session(childId: "c-anya", targetSound: "Ш")
        ]
        let (sut, spy) = makeSUT(children: children, sessions: sessions)
        await sut.fetchChildDashboard(.init(childId: "c-anya"))
        XCTAssertTrue(spy.childDashboardCalled)
        XCTAssertEqual(spy.lastDashboard?.child.id, "c-anya")
    }

    // MARK: - 13. fetchChildDashboard несуществующий ребёнок → presentError

    func test_fetchChildDashboard_unknownChild_callsError() async {
        let (sut, spy) = makeSUT(children: makeChildren())
        await sut.fetchChildDashboard(.init(childId: "nonexistent"))
        XCTAssertTrue(spy.errorCalled)
    }

    // MARK: - 14. saveNote happy path

    func test_saveNote_validText_savesAndPresents() async {
        let (sut, spy) = makeSUT()
        await sut.saveNote(.init(childId: "c-anya", text: "  Хороший прогресс  "))
        XCTAssertTrue(spy.saveNoteCalled)
        XCTAssertEqual(spy.lastSaveNote?.success, true)
        XCTAssertEqual(spy.lastSaveNote?.note.text, "Хороший прогресс")
    }

    // MARK: - 15. saveNote пустой текст → presentError

    func test_saveNote_emptyText_callsError() async {
        let (sut, spy) = makeSUT()
        await sut.saveNote(.init(childId: "c-anya", text: "   \n  "))
        XCTAssertTrue(spy.errorCalled)
        XCTAssertFalse(spy.saveNoteCalled)
    }

    // MARK: - 16. fetchNotes возвращает сохранённые заметки

    func test_fetchNotes_afterSave_returnsNote() async {
        let (sut, spy) = makeSUT()
        await sut.saveNote(.init(childId: "c-anya", text: "Заметка 1"))
        await sut.fetchNotes(.init(childId: "c-anya"))
        XCTAssertTrue(spy.fetchNotesCalled)
        XCTAssertEqual(spy.lastFetchNotes?.notes.count, 1)
    }

    func test_fetchNotes_noNotes_returnsEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.fetchNotes(.init(childId: "c-unknown"))
        XCTAssertEqual(spy.lastFetchNotes?.notes.count, 0)
    }

    // MARK: - 17. deleteNote удаляет существующую заметку

    func test_deleteNote_existingNote_succeeds() async {
        let (sut, spy) = makeSUT()
        await sut.saveNote(.init(childId: "c-anya", text: "Заметка для удаления"))
        let noteId = spy.lastSaveNote?.note.id ?? ""
        await sut.deleteNote(.init(noteId: noteId, childId: "c-anya"))
        XCTAssertTrue(spy.deleteNoteCalled)
        XCTAssertEqual(spy.lastDeleteNote?.success, true)
    }

    // MARK: - 18. deleteNote несуществующая заметка → success=false

    func test_deleteNote_unknownNote_failsGracefully() async {
        let (sut, spy) = makeSUT()
        await sut.saveNote(.init(childId: "c-anya", text: "Заметка"))
        await sut.deleteNote(.init(noteId: "no-such-id", childId: "c-anya"))
        XCTAssertEqual(spy.lastDeleteNote?.success, false)
    }

    // MARK: - 19. requestExport PDF

    func test_requestExport_pdf_returnsFile() async {
        let sessions = [TestDataBuilder.session(childId: "c-anya", date: Date())]
        let (sut, spy) = makeSUT(sessions: sessions)
        let range = DateRange(
            start: Date().addingTimeInterval(-86_400),
            end: Date().addingTimeInterval(86_400)
        )
        await sut.requestExport(.init(childId: "c-anya", format: .pdf, range: range))
        XCTAssertTrue(spy.exportCalled)
        XCTAssertEqual(spy.lastExport?.format, .pdf)
    }

    // MARK: - 20. requestExport CSV

    func test_requestExport_csv_returnsFile() async {
        let sessions = [TestDataBuilder.session(childId: "c-anya", date: Date())]
        let (sut, spy) = makeSUT(sessions: sessions)
        let range = DateRange(
            start: Date().addingTimeInterval(-86_400),
            end: Date().addingTimeInterval(86_400)
        )
        await sut.requestExport(.init(childId: "c-anya", format: .csv, range: range))
        XCTAssertEqual(spy.lastExport?.format, .csv)
    }

    // MARK: - 21. requestExport при ошибке сервиса → presentError

    func test_requestExport_serviceFails_callsError() async {
        let exportService = StubExportService()
        exportService.shouldFail = true
        let sessions = [TestDataBuilder.session(childId: "c-anya", date: Date())]
        let (sut, spy) = makeSUT(sessions: sessions, exportService: exportService)
        let range = DateRange(
            start: Date().addingTimeInterval(-86_400),
            end: Date().addingTimeInterval(86_400)
        )
        await sut.requestExport(.init(childId: "c-anya", format: .pdf, range: range))
        XCTAssertTrue(spy.errorCalled)
    }

    // MARK: - 22. sendParentMessage happy path

    func test_sendParentMessage_validMessage_delivers() async {
        let (sut, spy) = makeSUT()
        await sut.sendParentMessage(.init(
            childId: "c-anya", parentId: "p-1", message: "Здравствуйте"
        ))
        XCTAssertTrue(spy.sendMessageCalled)
        XCTAssertEqual(spy.lastSendMessage?.delivered, true)
    }

    // MARK: - 23. sendParentMessage пустое сообщение → presentError

    func test_sendParentMessage_emptyMessage_callsError() async {
        let (sut, spy) = makeSUT()
        await sut.sendParentMessage(.init(
            childId: "c-anya", parentId: "p-1", message: "   "
        ))
        XCTAssertTrue(spy.errorCalled)
        XCTAssertFalse(spy.sendMessageCalled)
    }

    // MARK: - 24. strugglingSounds выявляет слабые звуки

    func test_strugglingSounds_returnsLowConfidenceSounds() async {
        let weakAttempts = (0..<10).map { _ in
            TestDataBuilder.attempt(isCorrect: false)
        }
        let sessions = [
            TestDataBuilder.session(
                childId: "c-anya", targetSound: "Р",
                totalAttempts: 10, correctAttempts: 1, attempts: weakAttempts
            )
        ]
        let (sut, _) = makeSUT(children: makeChildren(), sessions: sessions)
        let sounds = await sut.strugglingSounds(for: "c-anya")
        XCTAssertTrue(sounds.contains("Р"))
    }

    // MARK: - 25. recommendExercises возвращает рекомендации при слабых звуках

    func test_recommendExercises_withWeakSounds_returnsTips() async {
        let weakAttempts = (0..<10).map { _ in
            TestDataBuilder.attempt(isCorrect: false)
        }
        let sessions = [
            TestDataBuilder.session(
                childId: "c-anya", targetSound: "Р",
                totalAttempts: 10, correctAttempts: 1, attempts: weakAttempts
            )
        ]
        let (sut, _) = makeSUT(children: makeChildren(), sessions: sessions)
        let tips = await sut.recommendExercises(for: "c-anya")
        XCTAssertFalse(tips.isEmpty)
    }

    func test_recommendExercises_unknownChild_returnsEmpty() async {
        let (sut, _) = makeSUT(children: makeChildren())
        let tips = await sut.recommendExercises(for: "nonexistent")
        XCTAssertTrue(tips.isEmpty)
    }

    // MARK: - 26. predictGoalAdjustment

    func test_predictGoalAdjustment_returnsOutcome() async {
        let sessions = (0..<6).map { i in
            TestDataBuilder.session(
                childId: "c-anya",
                date: Date().addingTimeInterval(Double(-i) * 86_400),
                targetSound: "Р"
            )
        }
        let (sut, _) = makeSUT(children: makeChildren(), sessions: sessions)
        let outcome = await sut.predictGoalAdjustment(for: "c-anya")
        XCTAssertNotNil(outcome)
    }

    func test_predictGoalAdjustment_unknownChild_returnsNil() async {
        let (sut, _) = makeSUT(children: makeChildren())
        let outcome = await sut.predictGoalAdjustment(for: "nonexistent")
        XCTAssertNil(outcome)
    }

    // MARK: - 27. prepareSpecialistASR без asrService не крашит

    func test_prepareSpecialistASR_noService_doesNotCrash() {
        let (sut, _) = makeSUT()
        sut.prepareSpecialistASR()
        XCTAssertTrue(true)
    }
}
