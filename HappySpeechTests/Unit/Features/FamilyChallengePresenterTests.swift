@testable import HappySpeech
import XCTest

// MARK: - FamilyChallengePresenterTests

@MainActor
final class FamilyChallengePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: FamilyChallengeDisplayLogic {
        var lastChallengeVM: FamilyChallengeModels.LoadChallenge.ViewModel?
        var lastClaimVM: FamilyChallengeModels.ClaimReward.ViewModel?
        var lastShareVM: FamilyChallengeModels.ShareProgress.ViewModel?

        func displayChallenge(viewModel: FamilyChallengeModels.LoadChallenge.ViewModel) async {
            lastChallengeVM = viewModel
        }

        func displayClaimedReward(viewModel: FamilyChallengeModels.ClaimReward.ViewModel) async {
            lastClaimVM = viewModel
        }

        func displayShareProgress(viewModel: FamilyChallengeModels.ShareProgress.ViewModel) async {
            lastShareVM = viewModel
        }
    }

    private func makeSUT() -> (FamilyChallengePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = FamilyChallengePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeDTO(
        type: ChallengeType = .totalMinutes,
        goal: Int = 300,
        current: Int = 150,
        streakWeeks: Int = 3,
        contributions: [Contribution] = []
    ) -> FamilyChallengeDTO {
        FamilyChallengeDTO(
            id: UUID(),
            parentId: "parent-1",
            type: type,
            goal: goal,
            current: current,
            weekStart: Date(),
            contributions: contributions,
            streakWeeks: streakWeeks
        )
    }

    private func makeResponse(
        dto: FamilyChallengeDTO? = nil,
        isKidContext: Bool = false
    ) -> FamilyChallengeModels.LoadChallenge.Response {
        FamilyChallengeModels.LoadChallenge.Response(
            challenge: dto ?? makeDTO(),
            isKidContext: isKidContext
        )
    }

    // MARK: - presentChallenge

    func test_presentChallenge_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentChallenge(response: makeResponse())
        XCTAssertNotNil(spy.lastChallengeVM)
    }

    func test_presentChallenge_progressLabelContainsCurrentAndGoal() async {
        let (sut, spy) = makeSUT()
        let dto = makeDTO(goal: 300, current: 150)
        await sut.presentChallenge(response: makeResponse(dto: dto))
        let label = spy.lastChallengeVM?.progressLabel ?? ""
        XCTAssertTrue(label.contains("150"))
        XCTAssertTrue(label.contains("300"))
    }

    func test_presentChallenge_kidContext_canManageFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentChallenge(response: makeResponse(isKidContext: true))
        XCTAssertFalse(spy.lastChallengeVM?.canManage ?? true)
    }

    func test_presentChallenge_parentContext_canManageTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentChallenge(response: makeResponse(isKidContext: false))
        XCTAssertTrue(spy.lastChallengeVM?.canManage ?? false)
    }

    func test_presentChallenge_streakWeeksZero_showsStartMessage() async {
        let (sut, spy) = makeSUT()
        let dto = makeDTO(streakWeeks: 0)
        await sut.presentChallenge(response: makeResponse(dto: dto))
        let streakLabel = spy.lastChallengeVM?.streakLabel ?? ""
        XCTAssertFalse(streakLabel.isEmpty)
    }

    func test_presentChallenge_streakWeeksNonZero_containsWeekCount() async {
        let (sut, spy) = makeSUT()
        let dto = makeDTO(streakWeeks: 5)
        await sut.presentChallenge(response: makeResponse(dto: dto))
        let streakLabel = spy.lastChallengeVM?.streakLabel ?? ""
        XCTAssertTrue(streakLabel.contains("5"))
    }

    func test_presentChallenge_contributionsMapToRows() async {
        let (sut, spy) = makeSUT()
        let contribs = [
            Contribution(id: "k1", memberName: "Миша", memberEmoji: "🌟", value: 95, isChild: true),
            Contribution(id: "k2", memberName: "Папа", memberEmoji: "🎯", value: 30, isChild: false)
        ]
        let dto = makeDTO(contributions: contribs)
        await sut.presentChallenge(response: makeResponse(dto: dto))
        XCTAssertEqual(spy.lastChallengeVM?.contributions.count, 2)
    }

    func test_presentChallenge_contributionProgressFractionNormalisedToMax() async {
        let (sut, spy) = makeSUT()
        let contribs = [
            Contribution(id: "k1", memberName: "Миша", memberEmoji: "🌟", value: 100, isChild: true),
            Contribution(id: "k2", memberName: "Соня", memberEmoji: "🌟", value: 50, isChild: true)
        ]
        let dto = makeDTO(contributions: contribs)
        await sut.presentChallenge(response: makeResponse(dto: dto))
        // Max is 100 → Миша fraction == 1.0, Соня == 0.5
        let fractions = spy.lastChallengeVM?.contributions.map(\.progressFraction) ?? []
        XCTAssertEqual(fractions[0], 1.0, accuracy: 0.001)
        XCTAssertEqual(fractions[1], 0.5, accuracy: 0.001)
    }

    // MARK: - presentClaimedReward

    func test_presentClaimedReward_confettiShown() async {
        let (sut, spy) = makeSUT()
        let response = FamilyChallengeModels.ClaimReward.Response(challengeId: "c1", confettiShown: true)
        await sut.presentClaimedReward(response: response)
        XCTAssertTrue(spy.lastClaimVM?.confettiShown ?? false)
        XCTAssertFalse(spy.lastClaimVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentShareProgress

    func test_presentShareProgress_passesShareText() async {
        let (sut, spy) = makeSUT()
        let response = FamilyChallengeModels.ShareProgress.Response(shareText: "Мы крутые!")
        await sut.presentShareProgress(response: response)
        XCTAssertEqual(spy.lastShareVM?.shareText, "Мы крутые!")
    }
}
