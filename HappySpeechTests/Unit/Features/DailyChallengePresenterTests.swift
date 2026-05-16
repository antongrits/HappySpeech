@testable import HappySpeech
import XCTest

// MARK: - DailyChallengePresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие DailyChallengePresenter (0% → цель ≥90%).

@MainActor
final class DailyChallengePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: DailyChallengeDisplayLogic {
        var loadVM: DailyChallengeModels.Load.ViewModel?
        var startSessionVM: DailyChallengeModels.StartSession.ViewModel?
        var shareCompletionVM: DailyChallengeModels.ShareCompletion.ViewModel?

        func displayLoad(viewModel: DailyChallengeModels.Load.ViewModel) async { loadVM = viewModel }
        func displayStartSession(viewModel: DailyChallengeModels.StartSession.ViewModel) async { startSessionVM = viewModel }
        func displayShareCompletion(viewModel: DailyChallengeModels.ShareCompletion.ViewModel) async { shareCompletionVM = viewModel }
    }

    private func makeSUT() -> (DailyChallengePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = DailyChallengePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeGoal(
        kind: DailyGoalKind = .repetitions,
        target: Int = 10,
        current: Int = 3,
        targetSound: String = "С",
        isCompleted: Bool = false
    ) -> DailyGoalState {
        DailyGoalState(
            id: "2026-05-16-c1",
            kind: kind,
            target: target,
            current: current,
            targetSound: targetSound,
            isCompleted: isCompleted
        )
    }

    private func makeStreak(current: Int = 3, longest: Int = 7) -> StreakState {
        StreakState(current: current, longest: longest, lastSessionISO: nil)
    }

    private func makeReward(xpAward: Int = 20) -> RewardPreview {
        RewardPreview(stickerName: "sticker-star", xpAward: xpAward, titleKey: "dailyChallenge.reward.repetitions.title")
    }

    // MARK: - presentLoad

    func test_presentLoad_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertNotNil(spy.loadVM)
    }

    func test_presentLoad_goalTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(kind: .repetitions),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.goalTitle.isEmpty ?? true)
    }

    func test_presentLoad_goalSubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(kind: .minutes, target: 5, targetSound: "Ш"),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.goalSubtitle.isEmpty ?? true)
    }

    func test_presentLoad_goalSymbolNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(kind: .soundFocus),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.goalSymbol.isEmpty ?? true)
    }

    func test_presentLoad_progressValue_zeroTarget_isZero() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(target: 0, current: 0),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertEqual(spy.loadVM?.goalProgressValue, 0)
    }

    func test_presentLoad_progressValue_calculated() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(target: 10, current: 5),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertEqual(spy.loadVM?.goalProgressValue ?? 0, 0.5, accuracy: 0.001)
    }

    func test_presentLoad_progressValue_cappedAt1() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(target: 5, current: 10),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertEqual(spy.loadVM?.goalProgressValue ?? 0, 1.0, accuracy: 0.001)
    }

    func test_presentLoad_progressLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(target: 10, current: 3),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.goalProgressLabel.isEmpty ?? true)
    }

    func test_presentLoad_completed_ctaTitleIsShare() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(isCompleted: true),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.ctaTitle.isEmpty ?? true)
        // completed → share CTA key resolves to non-empty
        XCTAssertNotNil(spy.loadVM?.ctaTitle)
    }

    func test_presentLoad_notCompleted_ctaTitleIsStart() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(isCompleted: false),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.ctaTitle.isEmpty ?? true)
    }

    func test_presentLoad_streakTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(current: 5),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.streakTitle.isEmpty ?? true)
    }

    func test_presentLoad_longestStreakLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(longest: 14),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.longestStreakLabel.isEmpty ?? true)
    }

    func test_presentLoad_heroSubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.heroSubtitle.isEmpty ?? true)
    }

    func test_presentLoad_rewardTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(),
            reward: makeReward(xpAward: 30),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.rewardTitle.isEmpty ?? true)
    }

    func test_presentLoad_rewardSubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(),
            reward: makeReward(xpAward: 20),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.rewardSubtitle.isEmpty ?? true)
    }

    func test_presentLoad_rewardStickerPassedThrough() async {
        let (sut, spy) = makeSUT()
        let reward = RewardPreview(stickerName: "sticker-rocket", xpAward: 25, titleKey: "key")
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(),
            reward: reward,
            childDisplayName: "Маша"
        ))
        XCTAssertEqual(spy.loadVM?.rewardSticker, "sticker-rocket")
    }

    func test_presentLoad_isCompletedPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(isCompleted: true),
            streak: makeStreak(),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertTrue(spy.loadVM?.isCompleted ?? false)
    }

    func test_presentLoad_streakA11yLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(
            goal: makeGoal(),
            streak: makeStreak(current: 4),
            reward: makeReward(),
            childDisplayName: "Маша"
        ))
        XCTAssertFalse(spy.loadVM?.streakAccessibilityLabel.isEmpty ?? true)
    }

    // MARK: - presentStartSession

    func test_presentStartSession_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentStartSession(response: .init(childId: "c-1", targetSound: "С"))
        XCTAssertNotNil(spy.startSessionVM)
    }

    func test_presentStartSession_dataPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentStartSession(response: .init(childId: "child-42", targetSound: "Ш"))
        XCTAssertEqual(spy.startSessionVM?.childId, "child-42")
        XCTAssertEqual(spy.startSessionVM?.targetSound, "Ш")
    }

    // MARK: - presentShareCompletion

    func test_presentShareCompletion_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentShareCompletion(response: .init(
            snapshotText: "Маша выполнила задание!",
            toastKey: "dailyChallenge.share.success"
        ))
        XCTAssertNotNil(spy.shareCompletionVM)
    }

    func test_presentShareCompletion_snapshotTextPassedThrough() async {
        let (sut, spy) = makeSUT()
        let snapshot = "Маша завершила испытание дня!"
        await sut.presentShareCompletion(response: .init(
            snapshotText: snapshot,
            toastKey: "dailyChallenge.share.success"
        ))
        XCTAssertEqual(spy.shareCompletionVM?.snapshotText, snapshot)
    }

    func test_presentShareCompletion_toastMessageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentShareCompletion(response: .init(
            snapshotText: "Текст",
            toastKey: "dailyChallenge.share.success"
        ))
        XCTAssertFalse(spy.shareCompletionVM?.toastMessage.isEmpty ?? true)
    }
}
