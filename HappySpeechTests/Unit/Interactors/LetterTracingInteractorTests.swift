@testable import HappySpeech
import PencilKit
import XCTest

// MARK: - SpyLetterTracingPresenter

@MainActor
private final class SpyLetterTracingPresenter: LetterTracingPresentationLogic {

    var presentLoadCalled: Bool = false
    var presentSubmitCalled: Bool = false
    var presentResetCalled: Bool = false
    var presentHintCalled: Bool = false
    var presentCompleteCalled: Bool = false

    var lastLoadResponse: LetterTracingModels.LoadExercise.Response?
    var lastSubmitResponse: LetterTracingModels.SubmitDrawing.Response?
    var lastHintResponse: LetterTracingModels.RequestHint.Response?
    var lastCompleteResponse: LetterTracingModels.CompleteSession.Response?

    func presentLoadExercise(_ response: LetterTracingModels.LoadExercise.Response) {
        presentLoadCalled = true
        lastLoadResponse = response
    }

    func presentSubmitDrawing(_ response: LetterTracingModels.SubmitDrawing.Response) {
        presentSubmitCalled = true
        lastSubmitResponse = response
    }

    func presentResetCanvas(_ response: LetterTracingModels.ResetCanvas.Response) {
        presentResetCalled = true
    }

    func presentRequestHint(_ response: LetterTracingModels.RequestHint.Response) {
        presentHintCalled = true
        lastHintResponse = response
    }

    func presentCompleteSession(_ response: LetterTracingModels.CompleteSession.Response) {
        presentCompleteCalled = true
        lastCompleteResponse = response
    }
}

@MainActor
private final class SpyLetterTracingRouter: LetterTracingRoutingLogic {
    var routeToCompleteCalled: Bool = false
    var lastScore: Float = 0

    func routeToCompleteWith(score: Float) {
        routeToCompleteCalled = true
        lastScore = score
    }
}

// MARK: - LetterTracingInteractorTests

@MainActor
final class LetterTracingInteractorTests: XCTestCase {

    private func makeSUT() -> (LetterTracingInteractor, SpyLetterTracingPresenter, SpyLetterTracingRouter) {
        let sut = LetterTracingInteractor()
        let spy = SpyLetterTracingPresenter()
        let router = SpyLetterTracingRouter()
        sut.presenter = spy
        sut.router = router
        return (sut, spy, router)
    }

    // MARK: - 1. loadExercise difficulty 1 → overTemplate

    func test_loadExercise_difficulty1_overTemplate() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))

        XCTAssertTrue(spy.presentLoadCalled)
        XCTAssertEqual(spy.lastLoadResponse?.tracingLevel, .overTemplate)
        XCTAssertEqual(spy.lastLoadResponse?.targetLetter, "А")
    }

    func test_loadExercise_difficulty2_dotsOnly() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "Б",
            difficulty: 2
        ))

        XCTAssertEqual(spy.lastLoadResponse?.tracingLevel, .dotsOnly)
    }

    func test_loadExercise_difficulty3_freeWrite() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "В",
            difficulty: 3
        ))

        XCTAssertEqual(spy.lastLoadResponse?.tracingLevel, .freeWrite)
    }

    // MARK: - 2. loadExercise difficulty 1: 3 раунда с одной буквой

    func test_loadExercise_difficulty1_3Rounds() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))

        XCTAssertEqual(spy.lastLoadResponse?.totalRounds, 3)
    }

    // MARK: - 3. loadExercise повторный вызов не перезагружает сессию

    func test_loadExercise_calledTwice_doesNotResetSession() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))
        let roundsBefore = spy.lastLoadResponse?.totalRounds

        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))

        XCTAssertEqual(spy.lastLoadResponse?.totalRounds, roundsBefore)
    }

    // MARK: - 4. loadExercise phonemeWord корректный

    func test_loadExercise_letterA_phonemeWordIsArbus() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))

        XCTAssertEqual(spy.lastLoadResponse?.phonemeWord, "арбуз")
    }

    func test_loadExercise_letterR_phonemeWordIsRyba() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "Р",
            difficulty: 1
        ))

        XCTAssertEqual(spy.lastLoadResponse?.phonemeWord, "рыба")
    }

    // MARK: - 5. submitDrawing с пустым рисунком → coverageScore 0

    func test_submitDrawing_emptyDrawing_coverageIsZero() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))
        let emptyDrawing = PKDrawing()
        await sut.submitDrawing(LetterTracingModels.SubmitDrawing.Request(
            drawing: emptyDrawing,
            targetLetter: "А",
            drawingDuration: 3.0
        ))

        XCTAssertTrue(spy.presentSubmitCalled)
        XCTAssertEqual(spy.lastSubmitResponse?.coverageScore ?? 1.0, 0.0, accuracy: 0.001)
    }

    func test_submitDrawing_emptyDrawing_finalScoreIsLow() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))
        let emptyDrawing = PKDrawing()
        await sut.submitDrawing(LetterTracingModels.SubmitDrawing.Request(
            drawing: emptyDrawing,
            targetLetter: "А",
            drawingDuration: 3.0
        ))

        let finalScore = spy.lastSubmitResponse?.finalScore ?? 1.0
        XCTAssertLessThan(finalScore, 0.65,
                          "Пустой рисунок должен давать низкий итоговый балл")
    }

    // MARK: - 6. submitDrawing: attemptNumber растёт

    func test_submitDrawing_attemptNumberIncrements() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(LetterTracingModels.LoadExercise.Request(
            targetLetter: "А",
            difficulty: 1
        ))
        let drawing = PKDrawing()

        await sut.submitDrawing(LetterTracingModels.SubmitDrawing.Request(
            drawing: drawing, targetLetter: "А", drawingDuration: 3.0
        ))
        let attempt1 = spy.lastSubmitResponse?.attemptNumber ?? 0

        await sut.submitDrawing(LetterTracingModels.SubmitDrawing.Request(
            drawing: drawing, targetLetter: "А", drawingDuration: 3.0
        ))
        let attempt2 = spy.lastSubmitResponse?.attemptNumber ?? 0

        XCTAssertGreaterThan(attempt2, attempt1)
    }

    // MARK: - 7. resetCanvas перезапускает таймер

    func test_resetCanvas_callsPresenter() {
        let (sut, spy, _) = makeSUT()
        sut.resetCanvas(LetterTracingModels.ResetCanvas.Request())

        XCTAssertTrue(spy.presentResetCalled)
    }

    // MARK: - 8. requestHint продвигает состояние подсказки

    func test_requestHint_firstRequest_givesStartPoint() {
        let (sut, spy, _) = makeSUT()
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))

        XCTAssertTrue(spy.presentHintCalled)
        XCTAssertEqual(spy.lastHintResponse?.hintState, .startPoint)
    }

    func test_requestHint_secondRequest_givesDirection() {
        let (sut, spy, _) = makeSUT()
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))

        XCTAssertEqual(spy.lastHintResponse?.hintState, .direction)
    }

    func test_requestHint_thirdRequest_givesFullTemplate() {
        let (sut, spy, _) = makeSUT()
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))

        XCTAssertEqual(spy.lastHintResponse?.hintState, .fullTemplate)
    }

    func test_requestHint_fourthRequest_staysAtFullTemplate() {
        let (sut, spy, _) = makeSUT()
        for _ in 0..<4 {
            sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "А"))
        }

        XCTAssertEqual(spy.lastHintResponse?.hintState, .fullTemplate)
    }

    func test_requestHint_descriptionNotEmpty() {
        let (sut, spy, _) = makeSUT()
        sut.requestHint(LetterTracingModels.RequestHint.Request(letter: "Р"))

        XCTAssertFalse(spy.lastHintResponse?.hintDescription.isEmpty ?? true)
    }

    // MARK: - 9. Static: phonemeWord покрывает все буквы

    func test_phonemeWord_allRussianLetters_nonEmpty() {
        let alphabet = ["А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н",
                        "О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"]
        for letter in alphabet {
            let word = LetterTracingInteractor.phonemeWord(for: letter)
            XCTAssertFalse(word.isEmpty,
                           "phonemeWord для буквы \(letter) пустой")
        }
    }

    // MARK: - 10. Static: strokeCount > 0 для всех букв

    func test_strokeCount_allRussianLetters_greaterThanZero() {
        let alphabet = ["А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н",
                        "О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"]
        for letter in alphabet {
            let strokes = LetterTracingInteractor.strokeCount(for: letter)
            XCTAssertGreaterThan(strokes, 0,
                                 "strokeCount для \(letter) должен быть > 0")
        }
    }

    // MARK: - 11. isAvailable всегда true

    func test_isAvailable_alwaysTrue() {
        XCTAssertTrue(LetterTracingInteractor.isAvailable())
    }

    // MARK: - 12. HintState.next прогрессирует корректно

    func test_hintState_next_progression() {
        XCTAssertEqual(LetterTracingModels.HintState.none.next, .startPoint)
        XCTAssertEqual(LetterTracingModels.HintState.startPoint.next, .direction)
        XCTAssertEqual(LetterTracingModels.HintState.direction.next, .fullTemplate)
        XCTAssertEqual(LetterTracingModels.HintState.fullTemplate.next, .fullTemplate)
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadExercise_difficulty2_threeLettersWithSimilar() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "А", difficulty: 2))
        // difficulty>1 → [target, target] + 1 similar
        XCTAssertEqual(spy.lastLoadResponse?.totalRounds, 3)
        XCTAssertEqual(spy.lastLoadResponse?.tracingLevel, .dotsOnly)
    }

    func test_loadExercise_strokeCountPositive() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "Ф", difficulty: 1))
        XCTAssertGreaterThan(spy.lastLoadResponse?.strokeCount ?? 0, 0)
    }

    func test_loadExercise_hintStateNoneInitially() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "Б", difficulty: 1))
        XCTAssertEqual(spy.lastLoadResponse?.hintState, LetterTracingModels.HintState.none)
    }

    func test_loadExercise_promptNotEmpty() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "В", difficulty: 1))
        XCTAssertFalse(spy.lastLoadResponse?.promptText.isEmpty ?? true)
    }

    func test_submitDrawing_recognitionScoreZeroForEmpty() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "А", difficulty: 1))
        await sut.submitDrawing(.init(drawing: PKDrawing(), targetLetter: "А", drawingDuration: 3.0))
        // Пустой рисунок не будет распознан как буква
        XCTAssertEqual(spy.lastSubmitResponse?.recognitionScore ?? 1.0, 0.0, accuracy: 0.001)
    }

    func test_submitDrawing_threeAttempts_advancesAndCompletes() async {
        let (sut, spy, router) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "А", difficulty: 1))
        // 3 раунда × 3 попытки = форс-переход к завершению
        for _ in 0..<9 {
            await sut.submitDrawing(.init(drawing: PKDrawing(), targetLetter: "А", drawingDuration: 3.0))
        }
        // scheduleSessionComplete асинхронный — даём время
        try? await Task.sleep(for: .milliseconds(1400))
        XCTAssertTrue(spy.presentCompleteCalled)
        XCTAssertTrue(router.routeToCompleteCalled)
    }

    func test_submitDrawing_bestScoreReported() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadExercise(.init(targetLetter: "А", difficulty: 1))
        await sut.submitDrawing(.init(drawing: PKDrawing(), targetLetter: "А", drawingDuration: 3.0))
        XCTAssertNotNil(spy.lastSubmitResponse?.bestScore)
    }

    func test_requestHint_descriptionForFullTemplate() {
        let (sut, spy, _) = makeSUT()
        sut.requestHint(.init(letter: "С"))
        sut.requestHint(.init(letter: "С"))
        sut.requestHint(.init(letter: "С"))
        XCTAssertEqual(spy.lastHintResponse?.hintState, .fullTemplate)
        XCTAssertFalse(spy.lastHintResponse?.hintDescription.isEmpty ?? true)
    }

    func test_tracingLevel_localizedTitles() {
        XCTAssertFalse(LetterTracingModels.TracingLevel.overTemplate.localizedTitle.isEmpty)
        XCTAssertFalse(LetterTracingModels.TracingLevel.dotsOnly.localizedTitle.isEmpty)
        XCTAssertFalse(LetterTracingModels.TracingLevel.freeWrite.localizedTitle.isEmpty)
    }

    func test_letterProficiency_initialState() {
        let prof = LetterTracingModels.LetterProficiency(letter: "Р")
        XCTAssertEqual(prof.letter, "Р")
        XCTAssertEqual(prof.attempts, 0)
        XCTAssertEqual(prof.bestScore, 0)
        XCTAssertFalse(prof.isAchieved)
    }

    func test_phonemeWord_specificLetters() {
        XCTAssertEqual(LetterTracingInteractor.phonemeWord(for: "С"), "сани")
        XCTAssertEqual(LetterTracingInteractor.phonemeWord(for: "Ш"), "шапка")
        XCTAssertEqual(LetterTracingInteractor.phonemeWord(for: "Я"), "яблоко")
    }

    func test_strokeCount_letterI_isThree() {
        XCTAssertEqual(LetterTracingInteractor.strokeCount(for: "И"), 3)
    }
}
