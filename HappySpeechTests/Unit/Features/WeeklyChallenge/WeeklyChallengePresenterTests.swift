import XCTest
@testable import HappySpeech

// MARK: - WeeklyChallengePresenterTests
//
// Block AA v21 — Smoke tests для WeeklyChallengePresenter.
// 3 теста: presentLoad (7 cells), presentMarkDay (reward unlocked), presentSwitchKind.

@MainActor
final class WeeklyChallengePresenterTests: XCTestCase {

    private var sut: WeeklyChallengePresenter!
    private var spyDisplay: SpyWeeklyChallengeDisplay!

    override func setUp() {
        super.setUp()
        spyDisplay = SpyWeeklyChallengeDisplay()
        sut = WeeklyChallengePresenter(displayLogic: spyDisplay)
    }

    override func tearDown() {
        sut = nil
        spyDisplay = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_presentLoad_alwaysProduces7DayCells() async {
        // Arrange
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: [.completed, .completed, .pending, .locked, .locked, .locked, .locked],
            completed: 2,
            totalRequired: 7
        )
        let reward = WeeklyChallengeReward(
            id: "reward-1",
            titleKey: "weekly.reward.streak.title",
            symbolName: "flame.fill",
            isUnlocked: false
        )
        let response = WeeklyChallengeModels.Load.Response(
            state: state,
            reward: reward,
            daysUntilEndOfWeek: 4
        )
        // Act
        await sut.presentLoad(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displayLoadCalled)
        XCTAssertEqual(spyDisplay.lastLoadViewModel?.dayCells.count, 7)
    }

    func test_presentMarkDay_rewardUnlocked_setsCelebrateTrue() async {
        // Arrange
        let state = WeeklyChallengeState(
            kind: .lessonCount,
            weekStart: Date(),
            dayStates: Array(repeating: .completed, count: 7),
            completed: 5,
            totalRequired: 5
        )
        let response = WeeklyChallengeModels.MarkDay.Response(
            updatedState: state,
            unlockedReward: true
        )
        // Act
        await sut.presentMarkDay(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displayMarkDayCalled)
        XCTAssertTrue(
            spyDisplay.lastMarkDayViewModel?.celebrate == true,
            "При unlock reward celebrate должен быть true"
        )
    }

    func test_presentSwitchKind_callsDisplay() async {
        // Arrange
        let state = WeeklyChallengeState(
            kind: .bingo,
            weekStart: Date(),
            dayStates: Array(repeating: .locked, count: 7),
            completed: 0,
            totalRequired: 5
        )
        let response = WeeklyChallengeModels.SwitchKind.Response(newState: state)
        // Act
        await sut.presentSwitchKind(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displaySwitchKindCalled)
    }

    // MARK: - Тесты из v18 (уникальное покрытие)

    func test_presentLoad_progressLabel_formattedCorrectly() async {
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: Array(repeating: .pending, count: 7),
            completed: 4,
            totalRequired: 7
        )
        let reward = WeeklyChallengeReward(id: "r1", titleKey: "t", symbolName: "star", isUnlocked: false)
        let response = WeeklyChallengeModels.Load.Response(state: state, reward: reward, daysUntilEndOfWeek: 2)
        await sut.presentLoad(response: response)
        XCTAssertEqual(spyDisplay.lastLoadViewModel?.progressLabel, "4/7",
                       "progressLabel должен быть '4/7'")
    }

    func test_presentLoad_endOfWeekToday_whenDaysUntilZero() async {
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: Array(repeating: .pending, count: 7),
            completed: 3,
            totalRequired: 7
        )
        let reward = WeeklyChallengeReward(id: "r1", titleKey: "t", symbolName: "star", isUnlocked: false)
        let response = WeeklyChallengeModels.Load.Response(state: state, reward: reward, daysUntilEndOfWeek: 0)
        await sut.presentLoad(response: response)
        XCTAssertFalse(spyDisplay.lastLoadViewModel?.endOfWeekLabel.isEmpty ?? true,
                       "endOfWeekLabel должен быть задан при daysUntilEndOfWeek=0")
    }

    func test_presentMarkDay_normalDay_celebrateIsFalse() async {
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: Array(repeating: .pending, count: 7),
            completed: 2,
            totalRequired: 7
        )
        let response = WeeklyChallengeModels.MarkDay.Response(updatedState: state, unlockedReward: false)
        await sut.presentMarkDay(response: response)
        XCTAssertFalse(spyDisplay.lastMarkDayViewModel?.celebrate ?? true,
                       "Без unlock reward celebrate должен быть false")
    }

    func test_presentSwitchKind_callsDisplay_withToastMessage() async {
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: Array(repeating: .locked, count: 7),
            completed: 0,
            totalRequired: 5
        )
        let response = WeeklyChallengeModels.SwitchKind.Response(newState: state)
        await sut.presentSwitchKind(response: response)
        XCTAssertFalse(spyDisplay.lastSwitchKindToastMessage?.isEmpty ?? true,
                       "SwitchKind должен устанавливать toastMessage")
    }
}

// MARK: - SpyWeeklyChallengeDisplay

@MainActor
private final class SpyWeeklyChallengeDisplay: WeeklyChallengeDisplayLogic {

    var displayLoadCalled = false
    var displayMarkDayCalled = false
    var displaySwitchKindCalled = false

    var lastLoadViewModel: WeeklyChallengeModels.Load.ViewModel?
    var lastMarkDayViewModel: WeeklyChallengeModels.MarkDay.ViewModel?
    var lastSwitchKindToastMessage: String?

    func displayLoad(viewModel: WeeklyChallengeModels.Load.ViewModel) async {
        displayLoadCalled = true
        lastLoadViewModel = viewModel
    }

    func displayMarkDay(viewModel: WeeklyChallengeModels.MarkDay.ViewModel) async {
        displayMarkDayCalled = true
        lastMarkDayViewModel = viewModel
    }

    func displaySwitchKind(viewModel: WeeklyChallengeModels.SwitchKind.ViewModel) async {
        displaySwitchKindCalled = true
        lastSwitchKindToastMessage = viewModel.toastMessage
    }
}
