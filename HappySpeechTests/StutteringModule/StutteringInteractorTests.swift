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

    var presentLoadProgressCalled = false
    var presentAdaptiveCalled = false
    var lastProgressResponse: StutteringModels.LoadProgress.Response?
    var lastAdaptiveResponse: StutteringModels.LoadAdaptiveRecommendation.Response?

    func presentLoadProgress(_ response: StutteringModels.LoadProgress.Response) {
        presentLoadProgressCalled = true
        lastProgressResponse = response
    }
    func presentAdaptiveRecommendation(_ response: StutteringModels.LoadAdaptiveRecommendation.Response) {
        presentAdaptiveCalled = true
        lastAdaptiveResponse = response
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

    func test_loadScreen_deliversFiveCards() {
        let (sut, spy) = makeSUT()

        sut.loadScreen(.init())

        XCTAssertTrue(spy.presentLoadScreenCalled)
        XCTAssertEqual(spy.lastLoadResponse?.cards.count, 5,
                       "loadScreen должен передавать 5 карточек упражнений")
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

    // MARK: - Batch 2.8.3 v25: расширенное покрытие
    //
    // Note: StutteringInteractor использует UserDefaults.standard напрямую.
    // Тесты очищают ключи в setUp/локально для изоляции.

    private func cleanStutteringDefaults() {
        let defaults = UserDefaults.standard
        for mode in StutteringMode.allCases {
            defaults.removeObject(forKey: "stuttering_streak_\(mode.rawValue)")
            defaults.removeObject(forKey: "stuttering_completed_today_\(mode.rawValue)")
            defaults.removeObject(forKey: "stuttering_streak_last_date_\(mode.rawValue)")
        }
        defaults.removeObject(forKey: "stuttering_session_count_total")
        defaults.removeObject(forKey: "stuttering_fluency_improvement_pct")
    }

    // MARK: - 6. loadProgress: presenter получает прогресс по всем режимам

    func test_loadProgress_deliversProgressForAllModes() {
        cleanStutteringDefaults()
        let (sut, spy) = makeSUT()
        sut.loadProgress(.init())

        XCTAssertTrue(spy.presentLoadProgressCalled)
        XCTAssertEqual(spy.lastProgressResponse?.featureProgress.count, StutteringMode.allCases.count)
    }

    // MARK: - 7. loadProgress: свежие defaults → totalSessions 0

    func test_loadProgress_freshDefaults_zeroSessions() {
        cleanStutteringDefaults()
        let (sut, spy) = makeSUT()
        sut.loadProgress(.init())
        XCTAssertEqual(spy.lastProgressResponse?.totalSessions, 0)
    }

    // MARK: - 8. loadAdaptiveRecommendation: presenter получает режим

    func test_loadAdaptiveRecommendation_deliversRecommendedMode() {
        cleanStutteringDefaults()
        let (sut, spy) = makeSUT()
        sut.loadAdaptiveRecommendation(.init())

        XCTAssertTrue(spy.presentAdaptiveCalled)
        XCTAssertNotNil(spy.lastAdaptiveResponse?.recommendedMode)
        XCTAssertFalse(spy.lastAdaptiveResponse?.voicePromptText.isEmpty ?? true)
        XCTAssertTrue(spy.lastAdaptiveResponse?.shouldShowGlow ?? false)
    }

    // MARK: - 9. recordSessionCompleted: увеличивает totalSessions

    func test_recordSessionCompleted_incrementsTotalSessions() {
        cleanStutteringDefaults()
        let (sut, spy) = makeSUT()
        sut.recordSessionCompleted(.init(mode: .metronome, fluencyScore: 0.8))
        sut.loadProgress(.init())

        XCTAssertEqual(spy.lastProgressResponse?.totalSessions, 1)
    }

    // MARK: - 10. recordSessionCompleted: первый раз → стрик режима = 1

    func test_recordSessionCompleted_setsStreakToOne() {
        cleanStutteringDefaults()
        let (sut, spy) = makeSUT()
        sut.recordSessionCompleted(.init(mode: .breathing, fluencyScore: 0.5))
        sut.loadProgress(.init())

        XCTAssertEqual(spy.lastProgressResponse?.featureProgress[.breathing]?.streak, 1)
        XCTAssertEqual(spy.lastProgressResponse?.featureProgress[.breathing]?.completedToday, true)
    }

    // MARK: - 11. recommendedSessionDuration: по возрасту

    func test_recommendedSessionDuration_byAge() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.recommendedSessionDuration(ageYears: 5), 7...10)
        XCTAssertEqual(sut.recommendedSessionDuration(ageYears: 6), 10...12)
        XCTAssertEqual(sut.recommendedSessionDuration(ageYears: 8), 12...15)
    }

    // MARK: - 12. completedModesTodayCount: после одной сессии = 1

    func test_completedModesTodayCount_afterOneSession() {
        cleanStutteringDefaults()
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.completedModesTodayCount(), 0)
        sut.recordSessionCompleted(.init(mode: .softOnset, fluencyScore: 0.7))
        XCTAssertEqual(sut.completedModesTodayCount(), 1)
    }

    // MARK: - 13. symbol(for:): каждый режим даёт непустой символ

    func test_symbolForMode_nonEmpty() {
        let (sut, _) = makeSUT()
        for mode in StutteringMode.allCases {
            XCTAssertFalse(sut.symbol(for: mode).isEmpty)
        }
    }

    // MARK: - 14. overallStreakDays: свежие defaults → 0

    func test_overallStreakDays_freshIsZero() {
        cleanStutteringDefaults()
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.overallStreakDays(), 0)
    }

    // MARK: - 15. validateAllStreaks: не крашит на свежих defaults

    func test_validateAllStreaks_doesNotCrash() {
        cleanStutteringDefaults()
        let (sut, _) = makeSUT()
        sut.validateAllStreaks()
        XCTAssertTrue(true)
    }

    // MARK: - 16. recordSessionCompleted: нулевой fluencyScore не обновляет improvement

    func test_recordSessionCompleted_zeroScoreNoImprovementUpdate() {
        cleanStutteringDefaults()
        let (sut, spy) = makeSUT()
        sut.recordSessionCompleted(.init(mode: .pacing, fluencyScore: 0))
        sut.loadProgress(.init())
        XCTAssertEqual(spy.lastProgressResponse?.fluencyImprovementPct ?? -1, 0, accuracy: 0.001)
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
