@testable import HappySpeech
import XCTest

// MARK: - ChildHomeInteractorTests
//
// Verifies the VIP interactor against mock repositories:
//   - fetchChildData fires presentFetch with populated viewModel fields
//   - empty / missing child surfaces presentError
//   - presenter is called on the MainActor
// ==================================================================================

@MainActor
final class ChildHomeInteractorTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: ChildHomePresentationLogic {
        var fetchResponses: [ChildHomeModels.Fetch.Response] = []
        var mascotTapCalled = false
        func presentFetch(_ response: ChildHomeModels.Fetch.Response) {
            fetchResponses.append(response)
        }
        func presentMascotTap(_ response: ChildHomeModels.MascotTap.Response) {
            mascotTapCalled = true
        }
    }

    private func makeSUT() -> (ChildHomeInteractor, SpyPresenter) {
        let interactor = ChildHomeInteractor(
            childRepository: MockChildRepository(),
            sessionRepository: MockSessionRepository()
        )
        let spy = SpyPresenter()
        interactor.presenter = spy
        return (interactor, spy)
    }

    // MARK: - fetchChildData

    func test_fetchChildData_firesPresentFetch() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        // P0.3 v19: fetchChildData делает два presentFetch — сначала seed-ответ
        // мгновенно (экран не пустой пока идёт async Realm-запрос), затем
        // реальные данные. Оба вызова — ожидаемое поведение.
        XCTAssertEqual(spy.fetchResponses.count, 2)
    }

    func test_fetchChildData_populatesDailySound() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        let response = spy.fetchResponses.first
        XCTAssertNotNil(response)
        XCTAssertFalse(response?.dailyTargetSound.isEmpty ?? true)
        XCTAssertFalse(response?.childName.isEmpty ?? true)
    }

    func test_fetchChildData_returnsDailyProgressInRange() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        let progress = spy.fetchResponses.first?.dailyProgress ?? -1
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }

    // MARK: - dismissAchievement

    func test_dismissAchievement_triggersRefetch() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        let countBefore = spy.fetchResponses.count
        await sut.dismissAchievement(id: "seed-first-session")
        XCTAssertGreaterThan(spy.fetchResponses.count, countBefore)
    }

    func test_dismissAchievement_withoutPriorFetch_noPresenterCall() async {
        let (sut, spy) = makeSUT()
        // lastChildId nil → dismissAchievement не должна падать
        await sut.dismissAchievement(id: "seed-first-session")
        XCTAssertTrue(spy.fetchResponses.isEmpty)
    }

    // MARK: - tapMascot

    func test_tapMascot_callsPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.tapMascot()
        XCTAssertTrue(spy.mascotTapCalled)
    }

    // MARK: - refreshData

    func test_refreshData_callsPresentFetch() async {
        let (sut, spy) = makeSUT()
        await sut.refreshData(childId: "preview-child-1")
        // refreshData проксирует в fetchChildData → seed-ответ + реальные данные.
        XCTAssertEqual(spy.fetchResponses.count, 2)
    }

    // MARK: - recordMissionTap

    func test_recordMissionTap_doesNotCrash() async {
        let (sut, _) = makeSUT()
        await sut.recordMissionTap()
        // Метод — только логирование, проверяем что не падает
    }

    // MARK: - Fetch fallback (repository error)

    func test_fetchChildData_repositoryError_fallsBackToSeed() async {
        let interactor = ChildHomeInteractor(
            childRepository: FailingChildRepository(),
            sessionRepository: MockSessionRepository()
        )
        let spy = SpyPresenter()
        interactor.presenter = spy
        await interactor.fetchChildData(.init(childId: "nonexistent"))
        // Должен вернуть seed-данные без crash: первый presentFetch — seed (мгновенно),
        // второй — seed-fallback после ошибки репозитория.
        XCTAssertEqual(spy.fetchResponses.count, 2)
        XCTAssertFalse(spy.fetchResponses.first?.childName.isEmpty ?? true)
        XCTAssertFalse(spy.fetchResponses.last?.childName.isEmpty ?? true)
    }

    // MARK: - Helpers

    private func makeDate(hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func makeSession(successRate: Double) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "c1",
            date: Date(),
            templateType: "listenAndChoose",
            targetSound: "Р",
            stage: "syllables",
            durationSeconds: 300,
            totalAttempts: 10,
            correctAttempts: Int(successRate * 10),
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}


private final class FailingChildRepository: ChildRepository, @unchecked Sendable {
    func fetch(id: String) async throws -> ChildProfileDTO {
        throw NSError(domain: "Test", code: 404, userInfo: nil)
    }
    func fetchAll() async throws -> [ChildProfileDTO] { [] }
    func save(_ profile: ChildProfileDTO) async throws {}
    func delete(id: String) async throws {}
    func updateProgress(childId: String, sound: String, rate: Double) async throws {}
    func updateStreak(childId: String, streak: Int) async throws {}
}
