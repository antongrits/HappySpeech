@testable import HappySpeech
import XCTest

// MARK: - Stub Catalog Worker

@MainActor
private final class StubAwardsCatalogWorker: AwardsCatalogWorkerProtocol {
    var shelves: [FamilyAwardsCabinetModels.Load.ShelfBucket] = []
    private(set) var fetchUnlockedCallCount = 0

    func fetchUnlocked(parentId: String) async -> [FamilyAwardsCabinetModels.Load.ShelfBucket] {
        fetchUnlockedCallCount += 1
        return shelves
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyFamilyAwardsCabinetPresenter: FamilyAwardsCabinetPresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var selectAwardCallCount = 0
    var lastLoad: FamilyAwardsCabinetModels.Load.Response?
    var lastSelect: FamilyAwardsCabinetModels.SelectAward.Response?

    func presentLoad(response: FamilyAwardsCabinetModels.Load.Response) async {
        loadCallCount += 1
        lastLoad = response
    }
    func presentSelectAward(response: FamilyAwardsCabinetModels.SelectAward.Response) async {
        selectAwardCallCount += 1
        lastSelect = response
    }
}

// MARK: - Tests

@MainActor
final class FamilyAwardsCabinetInteractorTests: XCTestCase {

    private func award(id: String, tier: AwardTier = .gold) -> FamilyAward {
        FamilyAward(
            id: id,
            childId: "c1",
            childName: "Маша",
            tier: tier,
            titleKey: "familyAwardsCabinet.award.streak_3",
            unlockedDate: Date(),
            symbolName: "flame.fill"
        )
    }

    private func makeSUT(
        children: [ChildProfileDTO] = [TestDataBuilder.childProfile(id: "c1", parentId: "p1")]
    ) -> (FamilyAwardsCabinetInteractor, SpyFamilyAwardsCabinetPresenter, StubAwardsCatalogWorker, SpyHapticService) {
        let worker = StubAwardsCatalogWorker()
        let childRepo = SpyChildRepository(children: children)
        let haptic = SpyHapticService()
        let sut = FamilyAwardsCabinetInteractor(
            catalogWorker: worker,
            childRepository: childRepo,
            hapticService: haptic
        )
        let spy = SpyFamilyAwardsCabinetPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    // MARK: - load

    func test_load_emptyCabinet_zeroAwards() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.totalAwards, 0)
    }

    func test_load_countsTotalAwardsAcrossShelves() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.shelves = [
            .init(tier: .gold, awards: [award(id: "a1"), award(id: "a2")]),
            .init(tier: .bronze, awards: [award(id: "a3", tier: .bronze)])
        ]
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(spy.lastLoad?.totalAwards, 3)
    }

    func test_load_countsChildren() async {
        let children = [
            TestDataBuilder.childProfile(id: "c1", parentId: "p1"),
            TestDataBuilder.childProfile(id: "c2", parentId: "p1")
        ]
        let (sut, spy, _, _) = makeSUT(children: children)
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(spy.lastLoad?.totalChildren, 2)
    }

    func test_load_childCountIncludesEmptyParentId() async {
        let children = [
            TestDataBuilder.childProfile(id: "c1", parentId: "p1"),
            TestDataBuilder.childProfile(id: "c2", parentId: "")
        ]
        let (sut, spy, _, _) = makeSUT(children: children)
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(spy.lastLoad?.totalChildren, 2)
    }

    func test_load_childCountExcludesOtherParent() async {
        let children = [
            TestDataBuilder.childProfile(id: "c1", parentId: "p1"),
            TestDataBuilder.childProfile(id: "c2", parentId: "p2")
        ]
        let (sut, spy, _, _) = makeSUT(children: children)
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(spy.lastLoad?.totalChildren, 1)
    }

    func test_load_repositoryFailure_zeroChildrenButStillEmits() async {
        let childRepo = SpyChildRepository(children: [])
        childRepo.shouldFail = true
        let worker = StubAwardsCatalogWorker()
        let sut = FamilyAwardsCabinetInteractor(
            catalogWorker: worker,
            childRepository: childRepo,
            hapticService: SpyHapticService()
        )
        let spy = SpyFamilyAwardsCabinetPresenter()
        sut.presenter = spy
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.totalChildren, 0)
    }

    func test_load_storesShelvesInDataStore() async {
        let (sut, _, worker, _) = makeSUT()
        worker.shelves = [.init(tier: .gold, awards: [award(id: "a1")])]
        await sut.load(request: .init(parentId: "p1"))
        XCTAssertEqual(sut.currentShelves.count, 1)
    }

    // MARK: - selectAward

    func test_selectAward_unknownId_ignored() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.shelves = [.init(tier: .gold, awards: [award(id: "a1")])]
        await sut.load(request: .init(parentId: "p1"))
        await sut.selectAward(request: .init(awardId: "missing"))
        XCTAssertEqual(spy.selectAwardCallCount, 0)
    }

    func test_selectAward_validId_emitsAndHaptic() async {
        let (sut, spy, worker, haptic) = makeSUT()
        worker.shelves = [.init(tier: .gold, awards: [award(id: "a1"), award(id: "a2")])]
        await sut.load(request: .init(parentId: "p1"))
        await sut.selectAward(request: .init(awardId: "a2"))
        XCTAssertEqual(spy.selectAwardCallCount, 1)
        XCTAssertEqual(spy.lastSelect?.award.id, "a2")
        XCTAssertGreaterThanOrEqual(haptic.selectionCount, 1)
    }

    func test_selectAward_searchesAcrossShelves() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.shelves = [
            .init(tier: .gold, awards: [award(id: "g1")]),
            .init(tier: .bronze, awards: [award(id: "b1", tier: .bronze)])
        ]
        await sut.load(request: .init(parentId: "p1"))
        await sut.selectAward(request: .init(awardId: "b1"))
        XCTAssertEqual(spy.lastSelect?.award.id, "b1")
    }

    // MARK: - AwardsCabinetSeed pure helpers

    func test_seed_unlocked_emptyForBlankChild() {
        let child = TestDataBuilder.childProfile(
            id: "c1", totalSessionMinutes: 0, currentStreak: 0
        )
        XCTAssertTrue(AwardsCabinetSeed.unlocked(for: [child]).isEmpty)
    }

    func test_seed_unlocked_firstSessionAward() {
        let child = TestDataBuilder.childProfile(id: "c1", totalSessionMinutes: 5)
        let awards = AwardsCabinetSeed.unlocked(for: [child])
        XCTAssertTrue(awards.contains { $0.titleKey == "familyAwardsCabinet.award.first_session" })
    }

    func test_seed_unlocked_streakAwards() {
        let child = TestDataBuilder.childProfile(id: "c1", currentStreak: 30)
        let awards = AwardsCabinetSeed.unlocked(for: [child])
        // streak >= 30 разблокирует все четыре streak-награды
        let streakAwards = awards.filter { $0.titleKey.contains("streak") }
        XCTAssertEqual(streakAwards.count, 4)
    }

    func test_seed_unlocked_minutesPlatinum() {
        let child = TestDataBuilder.childProfile(id: "c1", totalSessionMinutes: 700)
        let awards = AwardsCabinetSeed.unlocked(for: [child])
        XCTAssertTrue(awards.contains { $0.titleKey == "familyAwardsCabinet.award.minutes_600" })
    }

    func test_awardTier_ranksOrdered() {
        XCTAssertGreaterThan(AwardTier.platinum.rank, AwardTier.gold.rank)
        XCTAssertGreaterThan(AwardTier.gold.rank, AwardTier.silver.rank)
        XCTAssertGreaterThan(AwardTier.silver.rank, AwardTier.bronze.rank)
    }

    func test_awardTier_titleKeysNotEmpty() {
        for tier in AwardTier.allCases {
            XCTAssertFalse(tier.titleKey.isEmpty)
        }
    }
}
