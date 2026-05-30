@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyFamilyChallengePresenter: FamilyChallengePresentationLogic {
    var challengeCallCount = 0
    var claimCallCount = 0
    var shareCallCount = 0

    var lastChallengeResponse: FamilyChallengeModels.LoadChallenge.Response?
    var lastClaimResponse: FamilyChallengeModels.ClaimReward.Response?
    var lastShareResponse: FamilyChallengeModels.ShareProgress.Response?

    func presentChallenge(response: FamilyChallengeModels.LoadChallenge.Response) async {
        challengeCallCount += 1
        lastChallengeResponse = response
    }

    func presentClaimedReward(response: FamilyChallengeModels.ClaimReward.Response) async {
        claimCallCount += 1
        lastClaimResponse = response
    }

    func presentShareProgress(response: FamilyChallengeModels.ShareProgress.Response) async {
        shareCallCount += 1
        lastShareResponse = response
    }
}

// MARK: - FamilyChallengeInteractorTests

@MainActor
final class FamilyChallengeInteractorTests: XCTestCase {

    private var spy: SpyFamilyChallengePresenter!
    private var childRepo: SpyChildRepository!

    override func setUp() async throws {
        try await super.setUp()
        spy = SpyFamilyChallengePresenter()
        childRepo = SpyChildRepository(children: [
            TestDataBuilder.childProfile(id: "child-1", name: "Миша", parentId: "parent-1"),
            TestDataBuilder.childProfile(id: "child-2", name: "Соня", parentId: "parent-1")
        ])
    }

    override func tearDown() async throws {
        spy = nil
        childRepo = nil
        try await super.tearDown()
    }

    private func makeSUT(isKidContext: Bool = false) -> FamilyChallengeInteractor {
        let sut = FamilyChallengeInteractor(
            realmActor: RealmActor(),
            childRepository: childRepo,
            isKidContext: isKidContext
        )
        sut.presenter = spy
        return sut
    }

    // MARK: - loadChallenge

    func test_loadChallenge_callsPresenter() async {
        let sut = makeSUT()
        await sut.loadChallenge(.init(parentId: "parent-1"))
        XCTAssertEqual(spy.challengeCallCount, 1)
    }

    func test_loadChallenge_parentContext_isKidContextFalse() async {
        let sut = makeSUT(isKidContext: false)
        await sut.loadChallenge(.init(parentId: "parent-1"))
        XCTAssertFalse(spy.lastChallengeResponse?.isKidContext ?? true)
    }

    func test_loadChallenge_kidContext_isKidContextTrue() async {
        let sut = makeSUT(isKidContext: true)
        await sut.loadChallenge(.init(parentId: "parent-1"))
        XCTAssertTrue(spy.lastChallengeResponse?.isKidContext ?? false)
    }

    func test_loadChallenge_challengeHasTotalMinutesType() async {
        let sut = makeSUT()
        await sut.loadChallenge(.init(parentId: "parent-1"))
        XCTAssertEqual(spy.lastChallengeResponse?.challenge.type, .totalMinutes)
    }

    func test_loadChallenge_challengeGoalIs300() async {
        let sut = makeSUT()
        await sut.loadChallenge(.init(parentId: "parent-1"))
        XCTAssertEqual(spy.lastChallengeResponse?.challenge.goal, 300)
    }

    func test_loadChallenge_challengeHasContributions() async {
        let sut = makeSUT()
        await sut.loadChallenge(.init(parentId: "parent-1"))
        let contribs = spy.lastChallengeResponse?.challenge.contributions ?? []
        XCTAssertFalse(contribs.isEmpty)
    }

    func test_loadChallenge_streakWeeksIsThree() async {
        let sut = makeSUT()
        await sut.loadChallenge(.init(parentId: "parent-1"))
        XCTAssertEqual(spy.lastChallengeResponse?.challenge.streakWeeks, 3)
    }

    // MARK: - claimReward

    func test_claimReward_callsPresenter() async {
        let sut = makeSUT()
        await sut.claimReward(.init(challengeId: "challenge-1"))
        XCTAssertEqual(spy.claimCallCount, 1)
    }

    func test_claimReward_confettiShown() async {
        let sut = makeSUT()
        await sut.claimReward(.init(challengeId: "challenge-1"))
        XCTAssertTrue(spy.lastClaimResponse?.confettiShown ?? false)
    }

    func test_claimReward_challengeIdPassedThrough() async {
        let sut = makeSUT()
        await sut.claimReward(.init(challengeId: "challenge-xyz"))
        XCTAssertEqual(spy.lastClaimResponse?.challengeId, "challenge-xyz")
    }

    // MARK: - shareProgress

    func test_shareProgress_callsPresenter() async {
        let sut = makeSUT()
        await sut.shareProgress(.init(challengeId: "challenge-1"))
        XCTAssertEqual(spy.shareCallCount, 1)
    }

    func test_shareProgress_shareTextIsNonEmpty() async {
        let sut = makeSUT()
        await sut.shareProgress(.init(challengeId: "challenge-1"))
        XCTAssertFalse(spy.lastShareResponse?.shareText.isEmpty ?? true)
    }
}
