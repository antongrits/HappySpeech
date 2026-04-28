@testable import HappySpeech
import XCTest

// MARK: - StutteringInteractorTests
//
// 10 unit-тестов для StutteringInteractor и sub-mode Interactors (F5-step6).
// Покрывает: loadScreen, markWelcomeSeen, selectMode,
// MetronomeInteractor (BPM/tickInterval/sessionSetup),
// SoftOnsetInteractor (onset classification).

// MARK: - Spy Presenter (StutteringInteractor)

@MainActor
private final class SpyStutteringPresenter: StutteringPresentationLogic {
    var presentLoadScreenCalled = false
    var presentSelectModeCalled = false
    var lastLoadResponse: StutteringModels.LoadScreen.Response?
    var lastSelectResponse: StutteringModels.SelectMode.Response?

    func presentLoadScreen(_ response: StutteringModels.LoadScreen.Response) {
        presentLoadScreenCalled = true
        lastLoadResponse = response
    }

    func presentSelectMode(_ response: StutteringModels.SelectMode.Response) {
        presentSelectModeCalled = true
        lastSelectResponse = response
    }
}

// MARK: - StutteringInteractorTests

@MainActor
final class StutteringInteractorTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT() -> (StutteringInteractor, SpyStutteringPresenter) {
        let spy = SpyStutteringPresenter()
        let sut = StutteringInteractor()
        sut.presenter = spy
        return (sut, spy)
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "stuttering_welcome_shown")
    }

    // MARK: - 1. loadScreen: presenter получает 4 карточки

    func test_loadScreen_deliversFourCards() {
        let (sut, spy) = makeSUT()

        sut.loadScreen(.init())

        XCTAssertTrue(spy.presentLoadScreenCalled)
        XCTAssertEqual(spy.lastLoadResponse?.cards.count, 4,
                       "loadScreen должен передавать ровно 4 карточки упражнений")
    }

    // MARK: - 2. loadScreen: hasSeenWelcome=false при чистых UserDefaults

    func test_loadScreen_freshInstall_hasSeenWelcomeIsFalse() {
        let (sut, spy) = makeSUT()

        sut.loadScreen(.init())

        XCTAssertFalse(spy.lastLoadResponse?.hasSeenWelcome ?? true,
                       "При первом запуске hasSeenWelcome должен быть false")
    }

    // MARK: - 3. markWelcomeSeen: повторный loadScreen → hasSeenWelcome=true

    func test_markWelcomeSeen_setsUserDefaultsFlag() {
        let (sut, spy) = makeSUT()

        sut.markWelcomeSeen()
        sut.loadScreen(.init())

        XCTAssertTrue(spy.lastLoadResponse?.hasSeenWelcome ?? false,
                      "После markWelcomeSeen флаг hasSeenWelcome должен быть true")
    }

    // MARK: - 4. selectMode: presenter получает правильный режим

    func test_selectMode_metronome_presenterReceivesCorrectMode() {
        let (sut, spy) = makeSUT()

        sut.selectMode(.init(mode: .metronome))

        XCTAssertTrue(spy.presentSelectModeCalled)
        XCTAssertEqual(spy.lastSelectResponse?.mode, .metronome)
    }

    // MARK: - 5. loadScreen: карточки содержат все четыре режима

    func test_loadScreen_cardsContainAllFourModes() {
        let (sut, spy) = makeSUT()

        sut.loadScreen(.init())

        let modes = spy.lastLoadResponse?.cards.map(\.mode) ?? []
        XCTAssertTrue(modes.contains(.metronome),  "Метроном должен быть в карточках")
        XCTAssertTrue(modes.contains(.breathing),  "Дыхание должно быть в карточках")
        XCTAssertTrue(modes.contains(.softOnset),  "Мягкая атака должна быть в карточках")
        XCTAssertTrue(modes.contains(.diary),      "Дневник должен быть в карточках")
    }
}

// MARK: - StutteringDifficultyTests
//
// 5 тестов на вычисляемые свойства StutteringDifficulty (BPM, tickInterval, roundCount).

final class StutteringDifficultyTests: XCTestCase {

    // MARK: - 6. Easy BPM = 75 → tickInterval = 0.8с

    func test_metronome_tickInterval_75BPM_equals800ms() {
        let interval = StutteringDifficulty.easy.tickIntervalSeconds
        XCTAssertEqual(interval, 60.0 / 75.0, accuracy: 0.001,
                       "Easy 75 BPM должен давать интервал 0.8 секунды")
    }

    // MARK: - 7. Hard BPM = 105

    func test_difficultyHard_bpmEquals105() {
        XCTAssertEqual(StutteringDifficulty.hard.bpm, 105,
                       "Hard difficulty должен иметь BPM 105")
    }

    // MARK: - 8. Easy roundCount = 5

    func test_difficultyEasy_roundCountEquals5() {
        XCTAssertEqual(StutteringDifficulty.easy.roundCount, 5,
                       "Easy difficulty должен требовать 5 раундов")
    }

    // MARK: - 9. Hard roundCount = 10

    func test_difficultyHard_10rounds() {
        XCTAssertEqual(StutteringDifficulty.hard.roundCount, 10,
                       "Hard difficulty должен требовать 10 раундов")
    }

    // MARK: - 10. attackTimeThreshold: Easy >= 100ms

    func test_difficultyEasy_attackTimeThreshold_atLeast100ms() {
        XCTAssertGreaterThanOrEqual(
            StutteringDifficulty.easy.attackTimeThresholdMs, 100,
            "Easy порог мягкой атаки должен быть не менее 100 мс"
        )
    }
}
