import XCTest
@testable import HappySpeech

// MARK: - LetterTracingPresenterTests
//
// Phase 2.6 batch 3 — покрытие LetterTracingPresenter (0% → цель ≥90%).

@MainActor
final class LetterTracingPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: LetterTracingDisplayLogic {
        var loadExerciseVM: LetterTracingModels.LoadExercise.ViewModel?
        var submitDrawingVM: LetterTracingModels.SubmitDrawing.ViewModel?
        var resetCanvasVMCalled = false
        var requestHintVM: LetterTracingModels.RequestHint.ViewModel?
        var completeSessionVM: LetterTracingModels.CompleteSession.ViewModel?

        func displayLoadExercise(_ viewModel: LetterTracingModels.LoadExercise.ViewModel) { loadExerciseVM = viewModel }
        func displaySubmitDrawing(_ viewModel: LetterTracingModels.SubmitDrawing.ViewModel) { submitDrawingVM = viewModel }
        func displayResetCanvas(_ viewModel: LetterTracingModels.ResetCanvas.ViewModel) { resetCanvasVMCalled = true }
        func displayRequestHint(_ viewModel: LetterTracingModels.RequestHint.ViewModel) { requestHintVM = viewModel }
        func displayCompleteSession(_ viewModel: LetterTracingModels.CompleteSession.ViewModel) { completeSessionVM = viewModel }
    }

    private func makeSUT() -> (LetterTracingPresenter, DisplaySpy) {
        let sut = LetterTracingPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    // MARK: - presentLoadExercise

    func test_presentLoadExercise_propagatesLetter() {
        let (sut, spy) = makeSUT()
        sut.presentLoadExercise(.init(
            targetLetter: "С",
            promptText: "Скажи: С-С-С",
            roundIndex: 0,
            totalRounds: 5,
            tracingLevel: .overTemplate,
            hintState: .none,
            strokeCount: 2,
            phonemeWord: "солнце"
        ))
        XCTAssertNotNil(spy.loadExerciseVM)
        XCTAssertEqual(spy.loadExerciseVM?.targetLetter, "С")
        XCTAssertEqual(spy.loadExerciseVM?.roundIndex, 0)
        XCTAssertEqual(spy.loadExerciseVM?.totalRounds, 5)
        XCTAssertEqual(spy.loadExerciseVM?.tracingLevel, .overTemplate)
        XCTAssertEqual(spy.loadExerciseVM?.hintState, LetterTracingModels.HintState.none)
    }

    func test_presentLoadExercise_instructionTextNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadExercise(.init(
            targetLetter: "Р",
            promptText: "prompt",
            roundIndex: 1,
            totalRounds: 3,
            tracingLevel: .dotsOnly,
            hintState: .startPoint,
            strokeCount: 1,
            phonemeWord: "рыба"
        ))
        XCTAssertFalse(spy.loadExerciseVM?.instructionText.isEmpty ?? true)
        XCTAssertFalse(spy.loadExerciseVM?.progressText.isEmpty ?? true)
    }

    func test_presentLoadExercise_voicePromptPropagated() {
        let (sut, spy) = makeSUT()
        sut.presentLoadExercise(.init(
            targetLetter: "Л",
            promptText: "Скажи: Л-Л-Л",
            roundIndex: 0,
            totalRounds: 5,
            tracingLevel: .freeWrite,
            hintState: .fullTemplate,
            strokeCount: 3,
            phonemeWord: "лампа"
        ))
        XCTAssertEqual(spy.loadExerciseVM?.voicePrompt, "Скажи: Л-Л-Л")
        XCTAssertEqual(spy.loadExerciseVM?.phonemeWord, "лампа")
        XCTAssertEqual(spy.loadExerciseVM?.strokeCount, 3)
    }

    // MARK: - presentSubmitDrawing

    func test_presentSubmitDrawing_excellentScore_isCorrectTrue() {
        let (sut, spy) = makeSUT()
        sut.presentSubmitDrawing(.init(
            recognizedLetter: "С",
            targetLetter: "С",
            recognitionScore: 0.9,
            coverageScore: 0.9,
            speedScore: 0.9,
            finalScore: 0.9,
            isCorrect: true,
            attemptNumber: 1,
            bestScore: 0.9
        ))
        XCTAssertNotNil(spy.submitDrawingVM)
        XCTAssertTrue(spy.submitDrawingVM?.isCorrect == true)
        XCTAssertFalse(spy.submitDrawingVM?.feedbackText.isEmpty ?? true)
        XCTAssertEqual(spy.submitDrawingVM?.scorePercent, 90)
        XCTAssertFalse(spy.submitDrawingVM?.canRetry ?? true)
    }

    func test_presentSubmitDrawing_goodScore_between65and85() {
        let (sut, spy) = makeSUT()
        sut.presentSubmitDrawing(.init(
            recognizedLetter: nil,
            targetLetter: "С",
            recognitionScore: 0.7,
            coverageScore: 0.7,
            speedScore: 0.7,
            finalScore: 0.7,
            isCorrect: false,
            attemptNumber: 2,
            bestScore: 0.7
        ))
        XCTAssertFalse(spy.submitDrawingVM?.isCorrect ?? true)
        XCTAssertFalse(spy.submitDrawingVM?.feedbackText.isEmpty ?? true)
        XCTAssertTrue(spy.submitDrawingVM?.canRetry == true)
        XCTAssertNil(spy.submitDrawingVM?.recognizedText)
    }

    func test_presentSubmitDrawing_tryAgainScore_between40and65() {
        let (sut, spy) = makeSUT()
        sut.presentSubmitDrawing(.init(
            recognizedLetter: "Г",
            targetLetter: "С",
            recognitionScore: 0.5,
            coverageScore: 0.5,
            speedScore: 0.5,
            finalScore: 0.5,
            isCorrect: false,
            attemptNumber: 1,
            bestScore: 0.5
        ))
        XCTAssertFalse(spy.submitDrawingVM?.feedbackText.isEmpty ?? true)
        XCTAssertFalse(spy.submitDrawingVM?.voiceFeedback.isEmpty ?? true)
        XCTAssertNotNil(spy.submitDrawingVM?.recognizedText)
    }

    func test_presentSubmitDrawing_belowThreshold_encourageVoice() {
        let (sut, spy) = makeSUT()
        sut.presentSubmitDrawing(.init(
            recognizedLetter: nil,
            targetLetter: "С",
            recognitionScore: 0.1,
            coverageScore: 0.1,
            speedScore: 0.1,
            finalScore: 0.2,
            isCorrect: false,
            attemptNumber: 3,
            bestScore: 0.2
        ))
        XCTAssertFalse(spy.submitDrawingVM?.feedbackText.isEmpty ?? true)
        XCTAssertFalse(spy.submitDrawingVM?.voiceFeedback.isEmpty ?? true)
    }

    func test_presentSubmitDrawing_scorePercentCalculated() {
        let (sut, spy) = makeSUT()
        sut.presentSubmitDrawing(.init(
            recognizedLetter: nil,
            targetLetter: "Р",
            recognitionScore: 0.85,
            coverageScore: 0.85,
            speedScore: 0.85,
            finalScore: 0.85,
            isCorrect: true,
            attemptNumber: 1,
            bestScore: 0.85
        ))
        XCTAssertEqual(spy.submitDrawingVM?.scorePercent, 85)
        XCTAssertEqual(spy.submitDrawingVM?.bestScorePercent, 85)
    }

    // MARK: - presentResetCanvas

    func test_presentResetCanvas_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentResetCanvas(.init())
        XCTAssertTrue(spy.resetCanvasVMCalled)
    }

    // MARK: - presentRequestHint

    func test_presentRequestHint_none_allFlagsOff() {
        let (sut, spy) = makeSUT()
        sut.presentRequestHint(.init(hintState: .none, hintDescription: ""))
        XCTAssertEqual(spy.requestHintVM?.hintState, LetterTracingModels.HintState.none)
        XCTAssertFalse(spy.requestHintVM?.showStartDot ?? true)
        XCTAssertFalse(spy.requestHintVM?.showDirectionArrow ?? true)
        XCTAssertFalse(spy.requestHintVM?.showFullTemplate ?? true)
        XCTAssertTrue(spy.requestHintVM?.hintText.isEmpty == true)
    }

    func test_presentRequestHint_startPoint_showStartDotTrue() {
        let (sut, spy) = makeSUT()
        sut.presentRequestHint(.init(hintState: .startPoint, hintDescription: ""))
        XCTAssertEqual(spy.requestHintVM?.hintState, .startPoint)
        XCTAssertTrue(spy.requestHintVM?.showStartDot == true)
        XCTAssertFalse(spy.requestHintVM?.showDirectionArrow ?? true)
        XCTAssertFalse(spy.requestHintVM?.showFullTemplate ?? true)
        XCTAssertFalse(spy.requestHintVM?.hintText.isEmpty ?? true)
    }

    func test_presentRequestHint_direction_showArrowTrue() {
        let (sut, spy) = makeSUT()
        sut.presentRequestHint(.init(hintState: .direction, hintDescription: ""))
        XCTAssertTrue(spy.requestHintVM?.showDirectionArrow == true)
        XCTAssertFalse(spy.requestHintVM?.showStartDot ?? true)
        XCTAssertFalse(spy.requestHintVM?.showFullTemplate ?? true)
    }

    func test_presentRequestHint_fullTemplate_showTemplateTrue() {
        let (sut, spy) = makeSUT()
        sut.presentRequestHint(.init(hintState: .fullTemplate, hintDescription: ""))
        XCTAssertTrue(spy.requestHintVM?.showFullTemplate == true)
        XCTAssertFalse(spy.requestHintVM?.showStartDot ?? true)
        XCTAssertFalse(spy.requestHintVM?.showDirectionArrow ?? true)
        XCTAssertFalse(spy.requestHintVM?.hintText.isEmpty ?? true)
    }

    // MARK: - presentCompleteSession

    func test_presentCompleteSession_highScore_celebrationGreat() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(.init(
            averageScore: 0.9,
            correctCount: 9,
            totalRounds: 10,
            achievedLetters: ["С", "Р"],
            improvedLetters: []
        ))
        XCTAssertNotNil(spy.completeSessionVM)
        XCTAssertFalse(spy.completeSessionVM?.celebrationText.isEmpty ?? true)
        XCTAssertFalse(spy.completeSessionVM?.achievedText.isEmpty ?? true)
        XCTAssertEqual(spy.completeSessionVM?.finalScore ?? 0, 0.9, accuracy: 0.01)
    }

    func test_presentCompleteSession_mediumScore_celebrationGood() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(.init(
            averageScore: 0.6,
            correctCount: 6,
            totalRounds: 10,
            achievedLetters: [],
            improvedLetters: []
        ))
        XCTAssertFalse(spy.completeSessionVM?.celebrationText.isEmpty ?? true)
        // Без achieved letters → achievedText пустой
        XCTAssertTrue(spy.completeSessionVM?.achievedText.isEmpty == true)
    }

    func test_presentCompleteSession_lowScore_keepGoing() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(.init(
            averageScore: 0.3,
            correctCount: 3,
            totalRounds: 10,
            achievedLetters: [],
            improvedLetters: []
        ))
        XCTAssertFalse(spy.completeSessionVM?.celebrationText.isEmpty ?? true)
    }

    func test_presentCompleteSession_summaryTextNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentCompleteSession(.init(
            averageScore: 0.8,
            correctCount: 8,
            totalRounds: 10,
            achievedLetters: ["Л"],
            improvedLetters: ["С"]
        ))
        XCTAssertFalse(spy.completeSessionVM?.summaryText.isEmpty ?? true)
    }
}
