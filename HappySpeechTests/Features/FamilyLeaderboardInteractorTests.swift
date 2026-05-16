@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyFamilyLeaderboardPresenter: FamilyLeaderboardPresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var lastResponse: FamilyLeaderboardModels.Load.Response?

    func presentLoad(response: FamilyLeaderboardModels.Load.Response) async {
        loadCallCount += 1
        lastResponse = response
    }
}

// MARK: - Tests

@MainActor
final class FamilyLeaderboardInteractorTests: XCTestCase {

    private func makeSUT(
        children: [ChildProfileDTO],
        sessions: [SessionDTO]
    ) -> (FamilyLeaderboardInteractor, SpyFamilyLeaderboardPresenter, SpyChildRepository, SpySessionRepository) {
        let childRepo = SpyChildRepository(children: children)
        let sessionRepo = SpySessionRepository(sessions: sessions)
        let sut = FamilyLeaderboardInteractor(
            childRepository: childRepo,
            sessionRepository: sessionRepo
        )
        let spy = SpyFamilyLeaderboardPresenter()
        sut.presenter = spy
        return (sut, spy, childRepo, sessionRepo)
    }

    // MARK: - load

    func test_load_emptyFamily_emptyEntries() async {
        let (sut, spy, _, _) = makeSUT(children: [], sessions: [])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertTrue(spy.lastResponse?.entries.isEmpty ?? false)
        XCTAssertEqual(spy.lastResponse?.totalSessionsAcrossFamily, 0)
    }

    func test_load_singleChild_buildsEntry() async {
        let child = TestDataBuilder.childProfile(id: "c1", name: "Маша", parentId: "p1")
        let session = TestDataBuilder.session(
            childId: "c1", date: Date(), totalAttempts: 10, correctAttempts: 8
        )
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [session])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.count, 1)
        XCTAssertEqual(spy.lastResponse?.entries.first?.childName, "Маша")
        XCTAssertEqual(spy.lastResponse?.entries.first?.sessionCount, 1)
    }

    func test_load_filtersByParentId() async {
        let child1 = TestDataBuilder.childProfile(id: "c1", name: "Маша", parentId: "p1")
        let child2 = TestDataBuilder.childProfile(id: "c2", name: "Ваня", parentId: "p2")
        let (sut, spy, _, _) = makeSUT(children: [child1, child2], sessions: [])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.count, 1)
        XCTAssertEqual(spy.lastResponse?.entries.first?.id, "c1")
    }

    func test_load_emptyParentId_includesAllChildren() async {
        let child1 = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let child2 = TestDataBuilder.childProfile(id: "c2", parentId: "p2")
        let (sut, spy, _, _) = makeSUT(children: [child1, child2], sessions: [])
        await sut.load(request: .init(parentId: "", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.count, 2)
    }

    func test_load_sortsEntriesByScoreDescending() async {
        let weak = TestDataBuilder.childProfile(id: "weak", name: "Слабый", parentId: "p1")
        let strong = TestDataBuilder.childProfile(id: "strong", name: "Сильный", parentId: "p1")
        let weakSession = TestDataBuilder.session(
            id: "s1", childId: "weak", date: Date(), totalAttempts: 10, correctAttempts: 2
        )
        let strongSession = TestDataBuilder.session(
            id: "s2", childId: "strong", date: Date(), totalAttempts: 10, correctAttempts: 10
        )
        let (sut, spy, _, _) = makeSUT(
            children: [weak, strong],
            sessions: [weakSession, strongSession]
        )
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.first?.id, "strong")
        XCTAssertEqual(spy.lastResponse?.entries.last?.id, "weak")
    }

    func test_load_computesAvgAccuracy() async {
        let child = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let session = TestDataBuilder.session(
            childId: "c1", date: Date(), totalAttempts: 10, correctAttempts: 7
        )
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [session])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.first?.avgAccuracy ?? -1, 0.7, accuracy: 0.0001)
    }

    func test_load_zeroAttempts_avgAccuracyZero() async {
        let child = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let session = TestDataBuilder.session(
            childId: "c1", date: Date(), totalAttempts: 0, correctAttempts: 0
        )
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [session])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.first?.avgAccuracy, 0)
    }

    func test_load_oldSessionsFilteredOutForWeek() async {
        let child = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let oldSession = TestDataBuilder.session(childId: "c1", date: oldDate)
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [oldSession])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.entries.first?.sessionCount, 0)
    }

    func test_load_allTimeIncludesOldSessions() async {
        let child = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let oldDate = Calendar.current.date(byAdding: .day, value: -300, to: Date())!
        let oldSession = TestDataBuilder.session(childId: "c1", date: oldDate)
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [oldSession])
        await sut.load(request: .init(parentId: "p1", period: .allTime))
        XCTAssertEqual(spy.lastResponse?.entries.first?.sessionCount, 1)
    }

    func test_load_repositoryFailure_emitsEmptyResponse() async {
        let childRepo = SpyChildRepository(children: [])
        childRepo.shouldFail = true
        let sut = FamilyLeaderboardInteractor(
            childRepository: childRepo,
            sessionRepository: SpySessionRepository(sessions: [])
        )
        let spy = SpyFamilyLeaderboardPresenter()
        sut.presenter = spy
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertTrue(spy.lastResponse?.entries.isEmpty ?? false)
    }

    func test_load_totalSessionsAggregated() async {
        let child = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let s1 = TestDataBuilder.session(id: "s1", childId: "c1", date: Date())
        let s2 = TestDataBuilder.session(id: "s2", childId: "c1", date: Date())
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [s1, s2])
        await sut.load(request: .init(parentId: "p1", period: .week))
        XCTAssertEqual(spy.lastResponse?.totalSessionsAcrossFamily, 2)
    }

    func test_load_passesPeriodThrough() async {
        let (sut, spy, _, _) = makeSUT(children: [], sessions: [])
        await sut.load(request: .init(parentId: "p1", period: .month))
        XCTAssertEqual(spy.lastResponse?.period, .month)
    }

    // MARK: - changePeriod

    func test_changePeriod_reloadsWithNewPeriod() async {
        let child = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let (sut, spy, _, _) = makeSUT(children: [child], sessions: [])
        await sut.load(request: .init(parentId: "p1", period: .week))
        await sut.changePeriod(request: .init(period: .allTime))
        XCTAssertEqual(spy.loadCallCount, 2)
        XCTAssertEqual(spy.lastResponse?.period, .allTime)
    }

    func test_changePeriod_keepsLastParentId() async {
        let child1 = TestDataBuilder.childProfile(id: "c1", parentId: "p1")
        let child2 = TestDataBuilder.childProfile(id: "c2", parentId: "p2")
        let (sut, spy, _, _) = makeSUT(children: [child1, child2], sessions: [])
        await sut.load(request: .init(parentId: "p1", period: .week))
        await sut.changePeriod(request: .init(period: .month))
        // Должен остаться скоуп p1
        XCTAssertEqual(spy.lastResponse?.entries.count, 1)
        XCTAssertEqual(spy.lastResponse?.entries.first?.id, "c1")
    }

    // MARK: - LeaderboardPeriod model

    func test_leaderboardPeriod_titlesNotEmpty() {
        for period in LeaderboardPeriod.allCases {
            XCTAssertFalse(period.localizedTitle.isEmpty)
        }
    }

    func test_medal_symbolNames() {
        XCTAssertEqual(FamilyLeaderboardModels.Load.ViewModel.Medal.gold.symbolName, "1.circle.fill")
        XCTAssertEqual(FamilyLeaderboardModels.Load.ViewModel.Medal.silver.symbolName, "2.circle.fill")
        XCTAssertEqual(FamilyLeaderboardModels.Load.ViewModel.Medal.bronze.symbolName, "3.circle.fill")
        XCTAssertEqual(
            FamilyLeaderboardModels.Load.ViewModel.Medal.gold.emoji,
            FamilyLeaderboardModels.Load.ViewModel.Medal.gold.symbolName
        )
    }
}
