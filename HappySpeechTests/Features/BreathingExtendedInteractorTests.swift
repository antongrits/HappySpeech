@testable import HappySpeech
import XCTest

// MARK: - BreathingExtendedInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие BreathingExtendedInteractor (Stuttering / Длинный выдох).
//
// UNTESTABLE (документировано): BreathingExtendedInteractor.init() жёстко создаёт
// собственные BreathingAudioWorker + BreathingInteractor — нет inject-seam.
// `startSession` запускает реальную 4-7-8 фазовую последовательность через
// `await phaseTask?.value` (≈11+ секунд блокировки) + AVAudioEngine — это
// integration-путь, не unit. Поэтому здесь покрывается только синхронная логика:
// начальное состояние Display, idempotent-cancel, mapping difficulty → roundCount.
// Реальный аудио/фазовый путь покрыт smoke/integration-тестами StutteringSmokeUITest.

@MainActor
final class BreathingExtendedInteractorTests: XCTestCase {

    private func makeSUT() -> BreathingExtendedInteractor {
        BreathingExtendedInteractor()
    }

    // MARK: - 1. Начальное состояние Display

    func test_display_initialState() {
        let sut = makeSUT()
        XCTAssertEqual(sut.display.treeProgress, 0)
        XCTAssertFalse(sut.display.isPlaying)
        XCTAssertEqual(sut.display.roundsComplete, 0)
        XCTAssertFalse(sut.display.showSuccess)
        XCTAssertEqual(sut.display.sessionScore, 0)
        XCTAssertTrue(sut.display.roundScores.isEmpty)
    }

    // MARK: - 2. Display — currentPhase по умолчанию idle

    func test_display_initialPhaseIsIdle() {
        let sut = makeSUT()
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertEqual(sut.display.phaseCountdown, 0)
    }

    // MARK: - 3. cancel — без активной сессии не крашит

    func test_cancel_withoutSession_doesNotCrash() async {
        let sut = makeSUT()
        await sut.cancel()
        XCTAssertFalse(sut.display.isPlaying)
        XCTAssertEqual(sut.display.currentPhase, .idle)
    }

    // MARK: - 4. cancel — идемпотентен

    func test_cancel_idempotent() async {
        let sut = makeSUT()
        await sut.cancel()
        await sut.cancel()
        XCTAssertEqual(sut.display.mascotMood, .idle)
    }

    // MARK: - 5. cancel — сбрасывает мягко waveformLevels не трогая (нет краша)

    func test_cancel_afterInit_safeState() async {
        let sut = makeSUT()
        await sut.cancel()
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertFalse(sut.display.isPlaying)
    }

    // MARK: - 6. StutteringDifficulty.roundCount mapping

    func test_difficulty_roundCountMapping() {
        XCTAssertEqual(StutteringDifficulty.easy.roundCount, 5)
        XCTAssertEqual(StutteringDifficulty.hard.roundCount, 10)
        XCTAssertGreaterThan(
            StutteringDifficulty.medium.roundCount,
            StutteringDifficulty.easy.roundCount - 1
        )
    }

    // MARK: - 7. BreathingPhase — rawValue стабилен

    func test_breathingPhase_rawValues() {
        XCTAssertEqual(BreathingPhase.inhale.rawValue, "inhale")
        XCTAssertEqual(BreathingPhase.hold.rawValue, "hold")
        XCTAssertEqual(BreathingPhase.exhale.rawValue, "exhale")
        XCTAssertEqual(BreathingPhase.idle.rawValue, "idle")
    }

    // MARK: - 8. roundsRequired по умолчанию положителен

    func test_display_roundsRequiredPositive() {
        let sut = makeSUT()
        XCTAssertGreaterThan(sut.display.roundsRequired, 0)
    }
}
