@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyAchievementWallPresenter: AchievementWallPresentationLogic {
    var wallCallCount = 0
    var detailCallCount = 0
    var shareCallCount = 0

    var lastWallResponse: AchievementWallModels.LoadWall.Response?
    var lastDetailResponse: AchievementWallModels.OpenDetail.Response?
    var lastShareResponse: AchievementWallModels.Share.Response?

    func presentWall(response: AchievementWallModels.LoadWall.Response) async {
        wallCallCount += 1
        lastWallResponse = response
    }

    func presentDetail(response: AchievementWallModels.OpenDetail.Response) async {
        detailCallCount += 1
        lastDetailResponse = response
    }

    func presentShare(response: AchievementWallModels.Share.Response) async {
        shareCallCount += 1
        lastShareResponse = response
    }
}

// MARK: - AchievementWallInteractorTests

@MainActor
final class AchievementWallInteractorTests: XCTestCase {

    private var spy: SpyAchievementWallPresenter!
    private var childRepo: SpyChildRepository!

    override func setUp() async throws {
        try await super.setUp()
        spy = SpyAchievementWallPresenter()
        childRepo = SpyChildRepository(children: [
            TestDataBuilder.childProfile(id: "child-1", name: "Маша", age: 7)
        ])
    }

    override func tearDown() async throws {
        spy = nil
        childRepo = nil
        try await super.tearDown()
    }

    private func makeSUT() -> AchievementWallInteractor {
        // RealmActor() with no data → fetchUnlockedAchievements returns [].
        let sut = AchievementWallInteractor(
            realmActor: RealmActor(),
            childRepository: childRepo
        )
        sut.presenter = spy
        return sut
    }

    // MARK: - loadWall

    func test_loadWall_callsPresenter() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        XCTAssertEqual(spy.wallCallCount, 1)
    }

    func test_loadWall_entriesCountEqualsAllAchievements() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        XCTAssertEqual(spy.lastWallResponse?.totalCount, Achievement.allCases.count)
    }

    func test_loadWall_noUnlockedAchievements_totalUnlockedIsZero() async {
        // Empty Realm → no unlocked records.
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        XCTAssertEqual(spy.lastWallResponse?.totalUnlocked, 0)
    }

    func test_loadWall_childProfileFetched_nameAndAge() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        XCTAssertEqual(spy.lastWallResponse?.childName, "Маша")
        XCTAssertEqual(spy.lastWallResponse?.childAge, 7)
    }

    func test_loadWall_unknownChild_usesDefaultNameAndAge() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "unknown-child"))
        // fetch throws → fallback "Мой герой" / 6
        XCTAssertEqual(spy.lastWallResponse?.childName, "Мой герой")
        XCTAssertEqual(spy.lastWallResponse?.childAge, 6)
    }

    func test_loadWall_allEntriesAreLocked_whenRealmEmpty() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        let entries = spy.lastWallResponse?.entries ?? []
        XCTAssertTrue(entries.allSatisfy { !$0.unlocked })
    }

    // MARK: - openDetail

    func test_openDetail_unknownId_doesNotCallPresenter() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        await sut.openDetail(.init(achievementId: "totally-unknown-id"))
        XCTAssertEqual(spy.detailCallCount, 0)
    }

    func test_openDetail_validId_callsPresenter() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        let firstId = Achievement.allCases.first?.rawValue ?? ""
        await sut.openDetail(.init(achievementId: firstId))
        XCTAssertEqual(spy.detailCallCount, 1)
    }

    func test_openDetail_beforeLoad_doesNotCrash() async {
        let sut = makeSUT()
        // cachedEntries is empty before loadWall → silently skips
        await sut.openDetail(.init(achievementId: "any"))
        XCTAssertEqual(spy.detailCallCount, 0)
    }

    // MARK: - share

    func test_share_callsPresenter() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        await sut.share(.init(childName: "Маша"))
        XCTAssertEqual(spy.shareCallCount, 1)
    }

    func test_share_shareTextContainsChildName() async {
        let sut = makeSUT()
        await sut.loadWall(.init(childId: "child-1"))
        await sut.share(.init(childName: "Маша"))
        XCTAssertTrue(spy.lastShareResponse?.shareText.contains("Маша") ?? false)
    }

    func test_share_shareTextIsNonEmpty() async {
        let sut = makeSUT()
        await sut.share(.init(childName: "Тест"))
        XCTAssertFalse(spy.lastShareResponse?.shareText.isEmpty ?? true)
    }
}
