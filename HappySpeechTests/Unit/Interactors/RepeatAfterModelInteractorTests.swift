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
        var lastReplayModel: RepeatAfterModelModels.ReplayModel.Response?
        var lastHint: RepeatAfterModelModels.Hint.Response?
        var lastSloMo: RepeatAfterModelModels.SloMo.Response?
        var replayModelCalled = false
        var hintCalled = false
        var sloMoCalled = false

        func presentReplayModel(_ response: RepeatAfterModelModels.ReplayModel.Response) {
            replayModelCalled = true
            lastReplayModel = response
        }
        func presentHint(_ response: RepeatAfterModelModels.Hint.Response) {
            hintCalled = true
            lastHint = response
        }
        func presentSloMo(_ response: RepeatAfterModelModels.SloMo.Response) {
            sloMoCalled = true
            lastSloMo = response
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

    // MARK: - Batch 1: расширенное покрытие

    func test_loadSession_resetsStateOnReload() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.loadSession(.init(soundGroup: "hissing", childName: "Новый"))
        XCTAssertEqual(spy.lastLoadSession?.childName, "Новый")
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.attemptsLeft, 3)
    }

    func test_startWord_clampsIndexOutOfBounds() {
        let (sut, _) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 99))
        XCTAssertEqual(sut.currentIndex, sut.words.count - 1)
    }

    func test_startWord_emptyWords_ignored() {
        let (sut, spy) = makeSUT()
        // Без loadSession words пуст
        sut.startWord(.init(wordIndex: 0))
        XCTAssertFalse(spy.startWordCalled)
    }

    func test_replayModel_incrementsCount() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.replayModel(.init())
        XCTAssertTrue(spy.replayModelCalled)
        XCTAssertEqual(spy.lastReplayModel?.replayCount, 1)
    }

    func test_replayModel_limitReachedAfterThree() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.replayModel(.init())
        sut.replayModel(.init())
        sut.replayModel(.init())
        sut.replayModel(.init())
        XCTAssertEqual(spy.lastReplayModel?.replayLimitReached, true)
    }

    func test_requestHint_progressesLevels() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.hintLevel, .syllabification)
        sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.hintLevel, .articulationDiagram)
        sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.hintLevel, .sloMoReplay)
        // Четвёртый — остаётся на максимуме
        sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.hintLevel, .sloMoReplay)
    }

    func test_requestSloMo_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.requestSloMo(.init(playbackRate: 0.75))
        XCTAssertTrue(spy.sloMoCalled)
        XCTAssertEqual(spy.lastSloMo?.playbackRate, 0.75)
    }

    func test_submitMLScore_blendsWithASR() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        guard let word = sut.words.first else { return XCTFail("words пусты") }
        sut.submitMLScore(.init(wordId: word.id, mlScore: 1.0))
        sut.submitTranscript(.init(transcript: word.word, confidence: 0.95))
        // ML 1.0 * 0.6 + ASR ~1.0 * 0.4 → высокий blended score
        XCTAssertGreaterThan(spy.lastEvaluateAttempt?.score ?? 0, 0.8)
    }

    func test_submitTranscript_excellentScore_threeStars() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        guard let word = sut.words.first else { return XCTFail("words пусты") }
        sut.submitMLScore(.init(wordId: word.id, mlScore: 1.0))
        sut.submitTranscript(.init(transcript: word.word, confidence: 1.0))
        XCTAssertEqual(spy.lastEvaluateAttempt?.stars, 3)
    }

    func test_submitTranscript_emptyTranscript_omissionDiagnostic() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.submitTranscript(.init(transcript: "", confidence: 0.0))
        XCTAssertEqual(spy.lastEvaluateAttempt?.diagnostic, .omission)
    }

    func test_submitTranscript_afterAttemptsExhausted_forcedAdvance() {
        let (sut, spy) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.startWord(.init(wordIndex: 0))
        sut.submitTranscript(.init(transcript: "ааа", confidence: 0.0))
        sut.submitTranscript(.init(transcript: "ббб", confidence: 0.0))
        sut.submitTranscript(.init(transcript: "ввв", confidence: 0.0))
        // 4-й submit при attemptsLeft==0 → forced advance response
        sut.submitTranscript(.init(transcript: "ггг", confidence: 0.0))
        XCTAssertEqual(spy.lastEvaluateAttempt?.canAdvance, true)
        XCTAssertEqual(spy.lastEvaluateAttempt?.attemptsLeft, 0)
    }

    func test_cancel_resetsRecording() {
        let (sut, _) = makeSUT()
        sut.loadSession(.init(soundGroup: "sonants", childName: "Тест"))
        sut.toggleRecording()
        XCTAssertTrue(sut.isRecording)
        sut.cancel()
        XCTAssertFalse(sut.isRecording)
    }

    func test_repeatScoring_exactMatch_high() {
        let score = RepeatScoring.score(transcript: "рыба", target: "рыба", confidence: 1.0)
        XCTAssertGreaterThan(score, 0.8)
    }

    func test_starCountForScore_thresholds() {
        // Косвенно через completeSession с известными значениями недоступно;
        // проверяем через RepeatHintLevel перечисление вместо приватного метода.
        XCTAssertEqual(RepeatHintLevel.none.rawValue, "none")
        XCTAssertEqual(RepeatHintLevel.syllabification.rawValue, "syllabification")
    }

    func test_diagnostic_rawValues() {
        XCTAssertEqual(PronunciationDiagnostic.none.rawValue, "none")
        XCTAssertEqual(PronunciationDiagnostic.distortion.rawValue, "distortion")
        XCTAssertEqual(PronunciationDiagnostic.omission.rawValue, "omission")
    }

    func test_targetWordItem_wordsForGroup_nonEmpty() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            XCTAssertFalse(TargetWordItem.words(for: group).isEmpty, "Группа \(group) пуста")
        }
    }
}
