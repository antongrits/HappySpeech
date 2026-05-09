@testable import HappySpeech
import XCTest

// MARK: - WeeklyChallengePresenterTests
//
// Block V v18 — покрытие WeeklyChallengePresenter (6 тестов).
// Тестируются все три метода presentationLogic через DisplaySpy.

@MainActor
final class WeeklyChallengePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: WeeklyChallengeDisplayLogic {
        var loadVM: WeeklyChallengeModels.Load.ViewModel?
        var markDayVM: WeeklyChallengeModels.MarkDay.ViewModel?
        var switchKindVM: WeeklyChallengeModels.SwitchKind.ViewModel?

        func displayLoad(viewModel: WeeklyChallengeModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displayMarkDay(viewModel: WeeklyChallengeModels.MarkDay.ViewModel) async {
            markDayVM = viewModel
        }
        func displaySwitchKind(viewModel: WeeklyChallengeModels.SwitchKind.ViewModel) async {
            switchKindVM = viewModel
        }
    }

    private func makeSUT() -> (WeeklyChallengePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = WeeklyChallengePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeState(
        kind: WeeklyChallengeKind = .soundStreak,
        completed: Int = 3,
        total: Int = 7,
        dayStates: [DayProgress] = Array(repeating: .pending, count: 7)
    ) -> WeeklyChallengeState {
        WeeklyChallengeState(
            kind: kind,
            weekStart: Date(),
            dayStates: dayStates,
            completed: completed,
            totalRequired: total
        )
    }

    private func makeReward(unlocked: Bool = false) -> WeeklyChallengeReward {
        WeeklyChallengeReward(
            id: "reward-1",
            titleKey: "weekly.reward.test.title",
            symbolName: "star.fill",
            isUnlocked: unlocked
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_callsDisplayLoad_with7DayCells() async {
        let (sut, spy) = makeSUT()
        let response = WeeklyChallengeModels.Load.Response(
            state: makeState(),
            reward: makeReward(),
            daysUntilEndOfWeek: 3
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM)
        XCTAssertEqual(spy.loadVM?.dayCells.count, 7)
    }

    func test_presentLoad_progressLabel_isFormattedCorrectly() async {
        let (sut, spy) = makeSUT()
        let response = WeeklyChallengeModels.Load.Response(
            state: makeState(completed: 4, total: 7),
            reward: makeReward(),
            daysUntilEndOfWeek: 2
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.progressLabel, "4/7")
    }

    func test_presentLoad_endOfWeekToday_whenDaysUntilZero() async {
        let (sut, spy) = makeSUT()
        let response = WeeklyChallengeModels.Load.Response(
            state: makeState(),
            reward: makeReward(),
            daysUntilEndOfWeek: 0
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.endOfWeekLabel.isEmpty ?? true)
    }

    // MARK: - presentMarkDay

    func test_presentMarkDay_rewardUnlocked_celebrateIsTrue() async {
        let (sut, spy) = makeSUT()
        let state = makeState(completed: 7, total: 7)
        let response = WeeklyChallengeModels.MarkDay.Response(
            updatedState: state,
            unlockedReward: true
        )
        await sut.presentMarkDay(response: response)
        XCTAssertTrue(spy.markDayVM?.celebrate ?? false)
    }

    func test_presentMarkDay_normalDay_celebrateIsFalse() async {
        let (sut, spy) = makeSUT()
        let state = makeState(completed: 2, total: 7)
        let response = WeeklyChallengeModels.MarkDay.Response(
            updatedState: state,
            unlockedReward: false
        )
        await sut.presentMarkDay(response: response)
        XCTAssertFalse(spy.markDayVM?.celebrate ?? true)
        XCTAssertFalse(spy.markDayVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentSwitchKind

    func test_presentSwitchKind_callsDisplaySwitchKind_withToast() async {
        let (sut, spy) = makeSUT()
        let newState = makeState(kind: .bingo)
        let response = WeeklyChallengeModels.SwitchKind.Response(newState: newState)
        await sut.presentSwitchKind(response: response)
        XCTAssertNotNil(spy.switchKindVM)
        XCTAssertFalse(spy.switchKindVM?.toastMessage.isEmpty ?? true)
    }
}
