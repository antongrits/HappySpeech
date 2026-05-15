@testable import HappySpeech
import XCTest

// MARK: - Tests
//
// ARStoryQuestInteractor — 8-шаговый нарративный квест. Тесты покрывают
// загрузку, оценку попыток (`scoreAttempt` через `.submitAttempt`),
// переходы между шагами, завершение квеста и рестарт.
//
// Заметка: `.startListening` / `.stopListening` зависят от AudioService/ASRService;
// здесь они проверяются через mock-сервисы AppContainer (детерминированный путь).

@MainActor
final class ARStoryQuestInteractorTests: XCTestCase {

    private func makeSUT() -> (
        ARStoryQuestInteractor,
        ARStoryQuestPresenter,
        ARStoryQuestRouter,
        captured: () -> ARStoryQuestDisplay?
    ) {
        let presenter = ARStoryQuestPresenter()
        let router = ARStoryQuestRouter()
        let container = AppContainer.test()
        let sut = ARStoryQuestInteractor(
            presenter: presenter,
            router: router,
            container: container,
            script: .spaceAdventure
        )
        var lastDisplay: ARStoryQuestDisplay?
        presenter.onUpdate = { lastDisplay = $0 }
        return (sut, presenter, router, { lastDisplay })
    }

    // MARK: - loadQuest

    func test_loadQuest_publishesFirstStep() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        let display = captured()
        XCTAssertNotNil(display)
        XCTAssertEqual(display?.stepNumber, 1)
        XCTAssertEqual(display?.totalSteps, 8)
        XCTAssertFalse(display?.isLoading ?? true)
        XCTAssertFalse(display?.targetWord.isEmpty ?? true)
    }

    func test_loadQuest_emptyScript_publishesError() async {
        let (sut, _, _, captured) = makeSUT()
        let emptyScript = QuestScript(questId: "empty", title: "Пусто", steps: [])
        await sut.handle(.loadQuest(script: emptyScript))
        XCTAssertNotNil(captured()?.errorMessage)
    }

    // MARK: - submitAttempt scoring

    func test_submitAttempt_exactMatch_passes() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        let target = QuestScript.spaceAdventure.steps[0].targetWord
        await sut.handle(.submitAttempt(transcript: target, confidence: 0.5))
        let display = captured()
        XCTAssertTrue(display?.canAdvance ?? false, "Точное совпадение → можно продвинуться")
        XCTAssertEqual(display?.lastScore, 1.0)
        XCTAssertTrue(display?.showFeedback ?? false)
    }

    func test_submitAttempt_containsTarget_passes() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        let target = QuestScript.spaceAdventure.steps[0].targetWord
        await sut.handle(.submitAttempt(transcript: "вот \(target) тут", confidence: 0.3))
        XCTAssertEqual(captured()?.lastScore, 1.0)
    }

    func test_submitAttempt_highConfidenceNonEmpty_passes() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        // Несовпадающий transcript, но очень высокая уверенность модели
        await sut.handle(.submitAttempt(transcript: "абвгде", confidence: 0.95))
        let display = captured()
        XCTAssertTrue(display?.canAdvance ?? false)
        XCTAssertGreaterThanOrEqual(display?.lastScore ?? 0, 0.85)
    }

    func test_submitAttempt_prefixMatch_passesBorderline() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        let target = QuestScript.spaceAdventure.steps[0].targetWord.lowercased()
        let prefix = String(target.prefix(2)) + "ххххх"
        await sut.handle(.submitAttempt(transcript: prefix, confidence: 0.4))
        let display = captured()
        // prefixMatch ветка: 0.65 либо 0.9 при высокой confidence; в любом случае passed
        XCTAssertTrue(display?.canAdvance ?? false)
    }

    func test_submitAttempt_emptyTranscriptLowConfidence_fails() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.submitAttempt(transcript: "", confidence: 0.1))
        let display = captured()
        XCTAssertFalse(display?.canAdvance ?? true, "Пустой ввод с низкой уверенностью → не пройдено")
        XCTAssertGreaterThanOrEqual(display?.lastScore ?? -1, 0.3)
    }

    func test_submitAttempt_garbageTranscript_fails() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.submitAttempt(transcript: "ффффф", confidence: 0.2))
        XCTAssertFalse(captured()?.canAdvance ?? true)
    }

    // MARK: - advanceStep

    func test_advanceStep_movesToNextStep() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.advanceStep)
        XCTAssertEqual(captured()?.stepNumber, 2)
    }

    func test_advanceStep_throughAllSteps_completesQuest() async {
        let (sut, _, router, captured) = makeSUT()
        var routedStars: Int?
        router.onQuestCompleted = { stars, _ in routedStars = stars }
        await sut.handle(.loadQuest(script: .spaceAdventure))
        // Проходим все 8 шагов с засчитанными попытками
        for index in 0..<8 {
            let target = QuestScript.spaceAdventure.steps[index].targetWord
            await sut.handle(.submitAttempt(transcript: target, confidence: 1.0))
            await sut.handle(.advanceStep)
        }
        let display = captured()
        XCTAssertTrue(display?.isCompleted ?? false)
        XCTAssertEqual(display?.starsEarned, 3, "Все точные совпадения → 3 звезды")
        XCTAssertNotNil(routedStars)
        XCTAssertEqual(routedStars, 3)
    }

    func test_completeQuest_withoutScores_doesNotComplete() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        // Продвигаемся без submitAttempt — stepScores пуст
        for _ in 0..<8 {
            await sut.handle(.advanceStep)
        }
        XCTAssertFalse(captured()?.isCompleted ?? true, "Без оценок квест не завершается")
    }

    // MARK: - restartQuest

    func test_restartQuest_resetsToFirstStep() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.advanceStep)
        await sut.handle(.advanceStep)
        XCTAssertEqual(captured()?.stepNumber, 3)
        await sut.handle(.restartQuest)
        XCTAssertEqual(captured()?.stepNumber, 1)
        XCTAssertFalse(captured()?.isCompleted ?? true)
    }

    // MARK: - listening pipeline

    func test_startListening_emitsListeningStarted() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.startListening)
        XCTAssertTrue(captured()?.isListening ?? false)
    }

    func test_stopListening_transcribesAndEvaluates() async {
        let (sut, _, _, captured) = makeSUT()
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.startListening)
        await sut.handle(.stopListening)
        // MockASRService возвращает "рыба"; шаг оценивается → showFeedback true
        XCTAssertTrue(captured()?.showFeedback ?? false)
        XCTAssertFalse(captured()?.isListening ?? true)
    }

    // MARK: - dismiss

    func test_dismiss_routesBack() async {
        let (sut, _, router, _) = makeSUT()
        var didRouteBack = false
        router.dismiss = { didRouteBack = true }
        await sut.handle(.loadQuest(script: .spaceAdventure))
        await sut.handle(.dismiss)
        XCTAssertTrue(didRouteBack)
    }

    // MARK: - QuestScript content

    func test_spaceAdventure_hasEightSteps() {
        XCTAssertEqual(QuestScript.spaceAdventure.steps.count, 8)
        XCTAssertTrue(QuestScript.spaceAdventure.steps.allSatisfy { !$0.targetWord.isEmpty })
        let stepNumbers = QuestScript.spaceAdventure.steps.map(\.stepNumber)
        XCTAssertEqual(stepNumbers, Array(1...8))
    }
}
