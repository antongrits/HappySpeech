@testable import HappySpeech
import XCTest

// MARK: - SessionCompleteInteractorTests
//
// M10.1 — 8 тестов для SessionCompleteInteractor.
// Покрывает: loadResult, advancePhase, shareResult (с/без result),
// playAgain, proceedToNext (hasNext/noNext).

@MainActor
final class SessionCompleteInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SessionCompletePresentationLogic {
        var loadResultCalled = false
        var advancePhaseCalled = false
        var shareResultCalled = false
        var playAgainCalled = false
        var proceedToNextCalled = false
        var failureCalled = false

        var lastLoadResult: SessionCompleteModels.LoadResult.Response?
        var lastAdvancePhase: SessionCompleteModels.AdvancePhase.Response?
        var lastShareResult: SessionCompleteModels.ShareResult.Response?
        var lastPlayAgain: SessionCompleteModels.PlayAgain.Response?
        var lastProceedToNext: SessionCompleteModels.ProceedToNext.Response?

        func presentLoadResult(_ response: SessionCompleteModels.LoadResult.Response) {
            loadResultCalled = true
            lastLoadResult = response
        }
        func presentAdvancePhase(_ response: SessionCompleteModels.AdvancePhase.Response) {
            advancePhaseCalled = true
            lastAdvancePhase = response
        }
        func presentShareResult(_ response: SessionCompleteModels.ShareResult.Response) {
            shareResultCalled = true
            lastShareResult = response
        }
        func presentPlayAgain(_ response: SessionCompleteModels.PlayAgain.Response) {
            playAgainCalled = true
            lastPlayAgain = response
        }
        func presentProceedToNext(_ response: SessionCompleteModels.ProceedToNext.Response) {
            proceedToNextCalled = true
            lastProceedToNext = response
        }
        func presentFailure(_ response: SessionCompleteModels.Failure.Response) {
            failureCalled = true
        }

        var achievementUnlockedCalled = false
        var stickerRevealCalled = false
        var streakUpdateCalled = false
        var lastStickerReveal: SessionCompleteModels.StickerReveal.Response?
        var lastStreakUpdate: SessionCompleteModels.StreakUpdate.Response?

        func presentAchievementUnlocked(_ response: SessionCompleteModels.AchievementUnlocked.Response) {
            achievementUnlockedCalled = true
        }
        func presentStickerReveal(_ response: SessionCompleteModels.StickerReveal.Response) {
            stickerRevealCalled = true
            lastStickerReveal = response
        }
        func presentStreakUpdate(_ response: SessionCompleteModels.StreakUpdate.Response) {
            streakUpdateCalled = true
            lastStreakUpdate = response
        }
    }

    private var sampleResult: SessionResult {
        SessionResult(
            score: 0.85,
            starsEarned: 3,
            gameTitle: "Слушай и выбирай",
            soundTarget: "С",
            attempts: 8,
            durationSec: 180,
            nextLessonTitle: "Звук Ш"
        )
    }

    private func makeSUT() -> (SessionCompleteInteractor, SpyPresenter) {
        let sut = SessionCompleteInteractor(
            realmActor: RealmActor(),
            sessionRepository: MockSessionRepository(),
            childRepository: MockChildRepository()
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Детерминированно ждёт выполнения условия (вместо фиксированного sleep).
    /// Persistence pipeline диспатчится в Task — polling устраняет гонку с планировщиком.
    private func waitUntil(
        timeout: TimeInterval = 5.0,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("waitUntil: условие не выполнено за \(timeout) с")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - 1. loadResult вызывает presentLoadResult

    func test_loadResult_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadResult(.init(result: sampleResult))
        XCTAssertTrue(spy.loadResultCalled)
        XCTAssertEqual(spy.lastLoadResult?.result.starsEarned, 3)
    }

    // MARK: - 2. advancePhase вызывает presentAdvancePhase

    func test_advancePhase_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.advancePhase(.init(to: .nextPreview))
        XCTAssertTrue(spy.advancePhaseCalled)
        XCTAssertEqual(spy.lastAdvancePhase?.phase, .nextPreview)
    }

    // MARK: - 3. shareResult после loadResult → presenter получает shareText

    func test_shareResult_afterLoad_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadResult(.init(result: sampleResult))
        sut.shareResult(.init())
        XCTAssertTrue(spy.shareResultCalled)
        XCTAssertFalse(spy.lastShareResult?.shareText.isEmpty ?? true)
    }

    // MARK: - 4. shareResult без loadResult → failure

    func test_shareResult_beforeLoad_callsFailure() {
        let (sut, spy) = makeSUT()
        sut.shareResult(.init())
        XCTAssertFalse(spy.shareResultCalled)
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 5. playAgain вызывает presentPlayAgain

    func test_playAgain_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.playAgain(.init())
        XCTAssertTrue(spy.playAgainCalled)
    }

    // MARK: - 6. proceedToNext с nextLessonTitle → hasNext = true

    func test_proceedToNext_withNext_hasNextTrue() {
        let (sut, spy) = makeSUT()
        sut.loadResult(.init(result: sampleResult)) // nextLessonTitle = "Звук Ш"
        sut.proceedToNext(.init())
        XCTAssertTrue(spy.proceedToNextCalled)
        XCTAssertTrue(spy.lastProceedToNext?.hasNext ?? false)
    }

    // MARK: - 7. proceedToNext без nextLessonTitle → hasNext = false

    func test_proceedToNext_noNext_hasNextFalse() {
        let (sut, spy) = makeSUT()
        let resultNoNext = SessionResult(
            score: 0.6,
            starsEarned: 2,
            gameTitle: "Сортировка",
            soundTarget: "Ш",
            attempts: 5,
            durationSec: 90,
            nextLessonTitle: nil
        )
        sut.loadResult(.init(result: resultNoNext))
        sut.proceedToNext(.init())
        XCTAssertFalse(spy.lastProceedToNext?.hasNext ?? true)
    }

    // MARK: - 8. shareText содержит название игры и звука

    func test_shareText_containsGameAndSound() {
        let (sut, spy) = makeSUT()
        sut.loadResult(.init(result: sampleResult))
        sut.shareResult(.init())
        let text = spy.lastShareResult?.shareText ?? ""
        XCTAssertTrue(
            text.contains("С") || text.contains("Слушай"),
            "shareText должен содержать информацию об игре/звуке"
        )
    }

    // MARK: - 9. computeStars: правила начисления звёзд

    func test_computeStars_threeStars_highAccuracyNoHints() {
        XCTAssertEqual(SessionCompleteInteractor.computeStars(accuracy: 0.9, noHints: true), 3)
    }

    func test_computeStars_twoStars_highAccuracyWithHints() {
        // ≥85% но с подсказками → только 2 звезды
        XCTAssertEqual(SessionCompleteInteractor.computeStars(accuracy: 0.9, noHints: false), 2)
    }

    func test_computeStars_twoStars_mediumAccuracy() {
        XCTAssertEqual(SessionCompleteInteractor.computeStars(accuracy: 0.65, noHints: true), 2)
    }

    func test_computeStars_oneStar_lowAccuracy() {
        XCTAssertEqual(SessionCompleteInteractor.computeStars(accuracy: 0.3, noHints: true), 1)
    }

    func test_computeStars_boundaryAtTwoStarsThreshold() {
        // ровно 0.60 → 2 звезды
        XCTAssertEqual(SessionCompleteInteractor.computeStars(accuracy: 0.60, noHints: false), 2)
    }

    // MARK: - 10. breakdown — расчёт счёта

    func test_breakdown_noHints_hasStreakBonus() {
        let result = SessionResult(
            score: 0.8, starsEarned: 3, gameTitle: "Игра", soundTarget: "Р",
            attempts: 10, hintsUsed: 0, durationSec: 120, nextLessonTitle: nil
        )
        XCTAssertEqual(result.breakdown.streakBonus, 15)
        XCTAssertTrue(result.breakdown.noHints)
    }

    func test_breakdown_withHints_hasPenalty() {
        let result = SessionResult(
            score: 0.8, starsEarned: 2, gameTitle: "Игра", soundTarget: "Р",
            attempts: 10, hintsUsed: 3, durationSec: 120, nextLessonTitle: nil
        )
        XCTAssertEqual(result.breakdown.streakBonus, 0)
        XCTAssertLessThan(result.breakdown.hintPenalty, 0)
        XCTAssertFalse(result.breakdown.noHints)
    }

    // MARK: - 11. loadResult с childId → persistence pipeline вызывает презентер

    func test_loadResult_withChildId_runsPersistencePipeline() async throws {
        let childRepo = MockChildRepository(children: [TestDataBuilder.childProfile(id: "c-1")])
        let sut = SessionCompleteInteractor(
            realmActor: RealmActor(),
            sessionRepository: MockSessionRepository(),
            childRepository: childRepo
        )
        let spy = SpyPresenter()
        sut.presenter = spy
        let result = SessionResult(
            score: 0.9, starsEarned: 3, gameTitle: "Игра", soundTarget: "С",
            attempts: 10, correctAttempts: 9, hintsUsed: 0, durationSec: 150,
            nextLessonTitle: nil, childId: "c-1", sessionId: "sess-x"
        )
        sut.loadResult(.init(result: result))
        // persistence pipeline async — ждём детерминированно завершения обоих этапов
        try await waitUntil { spy.stickerRevealCalled && spy.streakUpdateCalled }
        XCTAssertTrue(spy.stickerRevealCalled, "Persistence pipeline должен раскрыть стикер")
        XCTAssertTrue(spy.streakUpdateCalled)
    }

    // MARK: - 12. loadResult без childId (preview mode) не крашит

    func test_loadResult_emptyChildId_previewMode_doesNotCrash() async throws {
        let (sut, spy) = makeSUT()
        // sampleResult имеет childId по умолчанию ""
        sut.loadResult(.init(result: sampleResult))
        try await waitUntil { spy.loadResultCalled }
        XCTAssertTrue(spy.loadResultCalled)
    }

    // MARK: - 13. makePreview создаёт валидный Interactor

    func test_makePreview_createsInteractor() {
        let sut = SessionCompleteInteractor.makePreview()
        let spy = SpyPresenter()
        sut.presenter = spy
        sut.advancePhase(.init(to: .celebration))
        XCTAssertTrue(spy.advancePhaseCalled)
    }
}
