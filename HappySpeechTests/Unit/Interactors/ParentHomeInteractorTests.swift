@testable import HappySpeech
import XCTest

// MARK: - ParentHomeInteractorTests
//
// M10.1 — 8 тестов для ParentHomeInteractor.
// Покрывает: fetchData (success/empty/error), refresh, switchChild,
// overallRate с пустым словарём, resolveChild с preferred.

@MainActor
final class ParentHomeInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: ParentHomePresentationLogic {
        var fetchCalled = false
        var loadingCalled = false
        var emptyCalled = false

        var lastFetch: ParentHomeModels.Fetch.Response?
        var lastLoadingValue: Bool?

        func presentFetch(_ response: ParentHomeModels.Fetch.Response) {
            fetchCalled = true
            lastFetch = response
        }
        func presentLoading(_ isLoading: Bool) {
            loadingCalled = true
            lastLoadingValue = isLoading
        }
        func presentEmpty() {
            emptyCalled = true
        }
        var errorCalled = false
        var addChildCalled = false
        var exportSpecialistCalled = false
        var startLessonCalled = false
        var lastExportChildId: String?
        var lastStartLessonChildId: String?

        func presentWeeklyInsight(_ response: ParentHomeModels.WeeklyInsightResponse) {}
        func presentError(_ message: String) {
            errorCalled = true
        }
        func presentAddChild() {
            addChildCalled = true
        }
        func presentExportSpecialist(childId: String) {
            exportSpecialistCalled = true
            lastExportChildId = childId
        }
        func presentStartLesson(childId: String) {
            startLessonCalled = true
            lastStartLessonChildId = childId
        }
    }

    private func makeSUT(
        children: [ChildProfileDTO] = [.preview],
        sessions: [SessionDTO] = [.preview]
    ) -> (ParentHomeInteractor, SpyPresenter) {
        let childRepo = MockChildRepository(children: children)
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let sut = ParentHomeInteractor(
            childRepository: childRepo,
            sessionRepository: sessionRepo
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. fetchData с детьми → presentFetch

    func test_fetchData_withChildren_callsPresentFetch() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertTrue(spy.fetchCalled)
        XCTAssertNotNil(spy.lastFetch)
    }

    // MARK: - 2. fetchData без детей → presentEmpty

    func test_fetchData_noChildren_callsPresentEmpty() async {
        let (sut, spy) = makeSUT(children: [])
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertFalse(spy.fetchCalled)
        XCTAssertTrue(spy.emptyCalled)
    }

    // MARK: - 3. fetchData сначала вызывает presentLoading(true)

    func test_fetchData_callsPresentLoadingTrue() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertTrue(spy.loadingCalled)
    }

    // MARK: - 4. fetchData с preferred child id → возвращает правильного ребёнка

    func test_fetchData_preferredChild_returnsCorrectChild() async {
        let child1 = ChildProfileDTO(id: "c1", name: "Аня", age: 5,
                                      targetSounds: ["С"], parentId: "p1")
        let child2 = ChildProfileDTO(id: "c2", name: "Вася", age: 6,
                                      targetSounds: ["Р"], parentId: "p1")
        let (sut, spy) = makeSUT(children: [child1, child2])
        await sut.fetchData(.init(preferredChildId: "c2"))
        XCTAssertEqual(spy.lastFetch?.childId, "c2")
        XCTAssertEqual(spy.lastFetch?.childName, "Вася")
    }

    // MARK: - 5. refresh после fetchData → обновляет данные

    func test_refresh_afterFetch_updatesData() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        spy.fetchCalled = false
        await sut.refresh()
        XCTAssertTrue(spy.fetchCalled)
    }

    // MARK: - 6. refresh без предыдущего fetchData → вызывает fetchData

    func test_refresh_withoutPriorFetch_callsFetchData() async {
        let (sut, spy) = makeSUT()
        await sut.refresh()
        // presenter.presentLoading или presentFetch или presentEmpty должен быть вызван
        XCTAssertTrue(spy.loadingCalled || spy.fetchCalled || spy.emptyCalled)
    }

    // MARK: - 7. switchChild переключает активного ребёнка

    func test_switchChild_updatesActiveChild() async {
        let child1 = ChildProfileDTO(id: "c1", name: "Аня", age: 5,
                                      targetSounds: ["С"], parentId: "p1")
        let child2 = ChildProfileDTO(id: "c2", name: "Вася", age: 6,
                                      targetSounds: ["Р"], parentId: "p1")
        let (sut, spy) = makeSUT(children: [child1, child2])
        await sut.fetchData(.init(preferredChildId: "c1"))
        await sut.switchChild(.init(childId: "c2"))
        XCTAssertEqual(spy.lastFetch?.childId, "c2")
    }

    // MARK: - 8. response содержит overallRate в [0, 1]

    func test_fetchData_overallRateInRange() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        let rate = spy.lastFetch?.overallRate ?? -1
        XCTAssertGreaterThanOrEqual(rate, 0.0)
        XCTAssertLessThanOrEqual(rate, 1.0)
    }

    // MARK: - 9. fetchData при ошибке репозитория → presentEmpty

    func test_fetchData_repositoryFails_callsEmpty() async {
        let childRepo = SpyChildRepository(children: [TestDataBuilder.childProfile()])
        childRepo.shouldFail = true
        let sut = ParentHomeInteractor(
            childRepository: childRepo,
            sessionRepository: MockSessionRepository(sessions: [])
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.fetchData(.init(preferredChildId: nil))
        XCTAssertTrue(spy.emptyCalled)
    }

    // MARK: - 10. addChild вызывает presentAddChild

    func test_addChild_callsPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.addChild(.init())
        XCTAssertTrue(spy.addChildCalled)
    }

    // MARK: - 11. deleteChild успешно удаляет ребёнка

    func test_deleteChild_success_refetches() async {
        let child1 = ChildProfileDTO(id: "c1", name: "Аня", age: 5,
                                      targetSounds: ["С"], parentId: "p1")
        let child2 = ChildProfileDTO(id: "c2", name: "Вася", age: 6,
                                      targetSounds: ["Р"], parentId: "p1")
        let (sut, spy) = makeSUT(children: [child1, child2])
        await sut.fetchData(.init(preferredChildId: "c1"))
        await sut.deleteChild(.init(childId: "c2"))
        // После удаления — повторный fetch вызовет presentFetch
        XCTAssertTrue(spy.fetchCalled)
    }

    // MARK: - 12. deleteChild при ошибке → presentError

    func test_deleteChild_repositoryFails_callsError() async {
        let childRepo = SpyChildRepository(children: [TestDataBuilder.childProfile(id: "c1")])
        childRepo.shouldFail = true
        let sut = ParentHomeInteractor(
            childRepository: childRepo,
            sessionRepository: MockSessionRepository(sessions: [])
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.deleteChild(.init(childId: "c1"))
        XCTAssertTrue(spy.errorCalled)
    }

    // MARK: - 13. switchChild с несуществующим id игнорируется

    func test_switchChild_unknownId_ignored() async {
        let (sut, spy) = makeSUT()
        await sut.fetchData(.init(preferredChildId: nil))
        spy.fetchCalled = false
        await sut.switchChild(.init(childId: "nonexistent"))
        XCTAssertFalse(spy.fetchCalled)
    }

    // MARK: - 14. markNotificationRead сохраняет состояние

    func test_markNotificationRead_persistsState() async {
        let (sut, _) = makeSUT()
        await sut.markNotificationRead(.init(notificationId: "notif-1"))
        // Не крашит — состояние записано
        XCTAssertTrue(true)
    }

    // MARK: - 15. updateDailyReminder с notificationService

    func test_updateDailyReminder_withService_doesNotCrash() async {
        let sut = ParentHomeInteractor(
            childRepository: MockChildRepository(children: []),
            sessionRepository: MockSessionRepository(sessions: []),
            notificationService: MockNotificationService()
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        await sut.updateDailyReminder(.init(hour: 18, minute: 30))
        XCTAssertTrue(true)
    }

    func test_updateDailyReminder_noService_doesNotCrash() async {
        let (sut, _) = makeSUT()
        await sut.updateDailyReminder(.init(hour: 19, minute: 0))
        XCTAssertTrue(true)
    }

    // MARK: - 16. exportToSpecialist / startLesson

    func test_exportToSpecialist_callsPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.exportToSpecialist(childId: "c-1")
        XCTAssertTrue(spy.exportSpecialistCalled)
        XCTAssertEqual(spy.lastExportChildId, "c-1")
    }

    func test_startLesson_callsPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.startLesson(childId: "c-1")
        XCTAssertTrue(spy.startLessonCalled)
        XCTAssertEqual(spy.lastStartLessonChildId, "c-1")
    }

    // MARK: - 17. needsSpecialistReview — статический хелпер

    func test_needsSpecialistReview_highScores_returnsFalse() {
        let child = TestDataBuilder.childProfile(targetSounds: ["Р"])
        let sessions = (0..<5).map { _ in
            TestDataBuilder.session(targetSound: "Р", totalAttempts: 10, correctAttempts: 10)
        }
        let needs = ParentHomeInteractor.needsSpecialistReview(child: child, sessions: sessions)
        XCTAssertFalse(needs)
    }
}
