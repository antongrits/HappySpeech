@testable import HappySpeech
import XCTest

// MARK: - RepeatAfterModelInteractorTests
//
// M10.1 — покрытие RepeatAfterModelInteractor (8 тестов).
// Проверяет: loadSession, startWord, toggleRecording, submitTranscript,
// advanceWord, completeSession, граничные случаи (0 попыток, форсированный advance).

@MainActor
final class RepeatAfterModelInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: RepeatAfterModelPresentationLogic {
        var loadSessionCalled = false
        var startWordCalled = false
        var evaluateAttemptCalled = false
        var recordAttemptCalled = false
        var completeSessionCalled = false

        var lastLoadSession: RepeatAfterModelModels.LoadSession.Response?
        var lastStartWord: RepeatAfterModelModels.StartWord.Response?
        var lastEvaluateAttempt: RepeatAfterModelModels.EvaluateAttempt.Response?
        var lastRecordAttempt: RepeatAfterModelModels.RecordAttempt.Response?
        var lastCompleteSession: RepeatAfterModelModels.CompleteSession.Response?

        func presentLoadSession(_ response: RepeatAfterModelModels.LoadSession.Response) {
            loadSessionCalled = true
            lastLoadSession = response
        }
        func presentStartWord(_ response: RepeatAfterModelModels.StartWord.Response) {
            startWordCalled = true
            lastStartWord = response
        }
        func presentEvaluateAttempt(_ response: RepeatAfterModelModels.EvaluateAttempt.Response) {
            evaluateAttemptCalled = true
            lastEvaluateAttempt = response
        }
        func presentRecordAttempt(_ response: RepeatAfterModelModels.RecordAttempt.Response) {
            recordAttemptCalled = true
            lastRecordAttempt = response
        }
        func presentCompleteSession(_ response: RepeatAfterModelModels.CompleteSession.Response) {
            completeSessionCalled = true
            lastCompleteSession = response
        }
    }

    private func makeSUT() -> (RepeatAfterModelInteractor, SpyPresenter) {
        let sut = RepeatAfterModelInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadSession вызывает presentLoadSession с правильным childName

    func test_loadSession_callsPresenterWithChildName() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertEqual(spy.lastLoadSession?.childName, "Маша")
    }

    // MARK: - 2. loadSession инициализирует слова для группы

    func test_loadSession_populatesWords() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "whistling", childName: "Тест"))
        XCTAssertFalse(sut.words.isEmpty, "words не должны быть пустыми после loadSession")
        XCTAssertLessThanOrEqual(sut.words.count, 5, "Максимум 5 слов за сессию")
    }

    // MARK: - 3. startWord устанавливает правильный индекс

    func test_startWord_setsIndex() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        XCTAssertTrue(spy.startWordCalled)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(spy.lastStartWord?.wordNumber, 1)
    }

    // MARK: - 4. toggleRecording переключает isRecording

    func test_toggleRecording_flipsFlag() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "hissing", childName: "Тест"))
        XCTAssertFalse(sut.isRecording)
        sut.toggleRecording()
        XCTAssertTrue(sut.isRecording)
        XCTAssertTrue(spy.recordAttemptCalled)
        XCTAssertEqual(spy.lastRecordAttempt?.isRecording, true)
        sut.toggleRecording()
        XCTAssertFalse(sut.isRecording)
    }

    // MARK: - 5. submitTranscript с правильным транскриптом → passed = true

    func test_submitTranscript_correctWord_passed() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        guard let word = sut.words.first else { return XCTFail("words пусты") }
        sut.submitTranscript(.init(transcript: word.word, confidence: 0.95))
        XCTAssertTrue(spy.evaluateAttemptCalled)
        XCTAssertTrue(spy.lastEvaluateAttempt?.passed == true)
    }

    // MARK: - 6. submitTranscript с неверным транскриптом → попытки убывают

    func test_submitTranscript_wrongWord_attemptsDecrease() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.submitTranscript(.init(transcript: "абракадабра", confidence: 0.1))
        XCTAssertFalse(spy.lastEvaluateAttempt?.passed ?? true)
        XCTAssertEqual(spy.lastEvaluateAttempt?.attemptsLeft, 2)
    }

    // MARK: - 7. После 3 неудачных попыток canAdvance = true

    func test_submitTranscript_threeWrong_forcedAdvance() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.submitTranscript(.init(transcript: "xxxxx", confidence: 0.0))
        sut.submitTranscript(.init(transcript: "yyyyy", confidence: 0.0))
        sut.submitTranscript(.init(transcript: "zzzzz", confidence: 0.0))
        XCTAssertTrue(spy.lastEvaluateAttempt?.canAdvance == true)
        XCTAssertEqual(spy.lastEvaluateAttempt?.attemptsLeft, 0)
    }

    // MARK: - 8. completeSession вызывается после advanceWord на последнем слове

    func test_advanceWord_onLastWord_triggersCompleteSession() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "whistling", childName: "Тест"))
        // Advance до последнего слова
        let lastIndex = max(0, sut.words.count - 1)
        sut.startWord(.init(wordIndex: lastIndex))
        sut.advanceWord()
        XCTAssertTrue(spy.completeSessionCalled)
    }

    // MARK: - 9. completeSession нормализует score в [0, 1]

    func test_completeSession_scoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "whistling", childName: "Тест"))
        sut.completeSession()
        XCTAssertTrue(spy.completeSessionCalled)
        let score = spy.lastCompleteSession?.totalScore ?? -1
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }
}
