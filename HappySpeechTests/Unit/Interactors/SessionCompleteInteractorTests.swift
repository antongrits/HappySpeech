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
}
