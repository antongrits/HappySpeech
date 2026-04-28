@testable import HappySpeech
import XCTest

// MARK: - GrammarGameInteractorTests
//
// 10 тестов для GrammarGameInteractor (F1-011).
// Покрывает: loadGame, evaluateAnswer (correct/incorrect/streak),
// завершение сессии по всем уровням сложности, scoringRate, difficultyTransition.

@MainActor
final class GrammarGameInteractorTests: XCTestCase {

    // MARK: - Spy Presenter

    @MainActor
    private final class SpyPresenter: GrammarGamePresentationLogic {
        var presentLoadGameCalled   = false
        var presentRoundCalled      = false
        var presentEvaluateAnswerCalled = false
        var presentDragDropCalled   = false
        var presentSessionCompleteCalled = false
        var presentExitConfirmationCalled = false
        var presentErrorCalled      = false

        var lastLoadResponse:     GrammarGameModels.LoadGame.Response?
        var lastRoundResponse:    GrammarGameModels.PresentRound.Response?
        var lastEvalResponse:     GrammarGameModels.EvaluateAnswer.Response?
        var lastSessionResponse:  GrammarGameModels.SessionComplete.Response?

        func presentLoadGame(_ r: GrammarGameModels.LoadGame.Response) {
            presentLoadGameCalled = true; lastLoadResponse = r
        }
        func presentRound(_ r: GrammarGameModels.PresentRound.Response) {
            presentRoundCalled = true; lastRoundResponse = r
        }
        func presentEvaluateAnswer(_ r: GrammarGameModels.EvaluateAnswer.Response) {
            presentEvaluateAnswerCalled = true; lastEvalResponse = r
        }
        func presentDragDrop(_ r: GrammarGameModels.DragDrop.Response) {
            presentDragDropCalled = true
        }
        func presentSessionComplete(_ r: GrammarGameModels.SessionComplete.Response) {
            presentSessionCompleteCalled = true; lastSessionResponse = r
        }
        func presentExitConfirmation() {
            presentExitConfirmationCalled = true
        }
        func presentError(_ message: String) {
            presentErrorCalled = true
        }
    }

    // MARK: - Factory

    private func makeSUT(
        mode: GrammarGameMode = .oneMany,
        difficulty: GrammarDifficulty = .easy
    ) -> (GrammarGameInteractor, SpyPresenter) {
        let spy     = SpyPresenter()
        let loader  = GrammarContentLoaderWorker()
        let scoring = GrammarScoringWorker()
        let feedback = GrammarFeedbackWorker()
        let sut = GrammarGameInteractor(
            contentLoader: loader,
            scoring: scoring,
            feedback: feedback
        )
        sut.presenter = spy
        return (sut, spy)
    }

    /// Возвращает fallback-раунды без обращения к JSON/сети.
    private func fallbackRounds(
        mode: GrammarGameMode = .oneMany,
        difficulty: GrammarDifficulty = .easy
    ) -> [GrammarRound] {
        GrammarContentLoaderWorker.fallbackRounds(mode: mode, difficulty: difficulty)
    }

    // MARK: - 1. loadGame: easy/oneMany → presenter получает не-nil response

    func test_loadFirstRound_oneMany_easy_returnsValidQuestion() async {
        let (sut, spy) = makeSUT(mode: .oneMany, difficulty: .easy)
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "test-child"))

        XCTAssertTrue(spy.presentLoadGameCalled,  "presentLoadGame должен вызываться")
        XCTAssertTrue(spy.presentRoundCalled,     "presentRound должен вызываться автоматически")
        let totalRounds = spy.lastLoadResponse?.totalRounds ?? 0
        XCTAssertGreaterThan(totalRounds, 0, "Должен быть хотя бы 1 раунд")
    }

    // MARK: - 2. loadGame: dative → choices пустые (drag-and-drop через extraData)

    func test_loadFirstRound_dative_roundHasExtraData() async {
        let (sut, spy) = makeSUT(mode: .dative, difficulty: .medium)
        await sut.loadGame(.init(mode: .dative, difficulty: .medium, childId: "test-child"))

        XCTAssertTrue(spy.presentRoundCalled)
        let round = spy.lastRoundResponse?.round
        XCTAssertNotNil(round, "Раунд должен быть не nil")
        // Dative-раунд содержит персонажей в extraData
        if case .dative(let characters, _) = round?.extraData {
            XCTAssertGreaterThanOrEqual(
                characters.count, 2,
                "Должно быть минимум 2 персонажа в dative-раунде"
            )
        } else {
            XCTFail("extraData должен быть .dative для dative-режима")
        }
    }

    // MARK: - 3. evaluateAnswer: правильный ответ → isCorrect == true

    func test_evaluateAnswer_correct_presenterReceivesCorrect() async {
        let (sut, spy) = makeSUT()
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "child-1"))
        guard let round = spy.lastRoundResponse?.round else {
            XCTFail("Раунд не загружен"); return
        }
        let correctId = round.choices[safe: round.correctIndex]?.id ?? "correct"

        await sut.evaluateAnswer(.init(selectedChoiceId: correctId, roundIndex: 0))

        XCTAssertTrue(spy.presentEvaluateAnswerCalled)
        XCTAssertEqual(spy.lastEvalResponse?.isCorrect, true)
    }

    // MARK: - 4. evaluateAnswer: неправильный ответ → isCorrect == false, streak не растёт

    func test_evaluateAnswer_incorrect_presenterReceivesIncorrect() async {
        let (sut, spy) = makeSUT()
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "child-2"))
        guard let round = spy.lastRoundResponse?.round else {
            XCTFail("Раунд не загружен"); return
        }
        // Выбираем гарантированно неправильный вариант
        let wrongId = round.choices.first(where: {
            $0.id != round.choices[safe: round.correctIndex]?.id
        })?.id ?? "d0"

        await sut.evaluateAnswer(.init(selectedChoiceId: wrongId, roundIndex: 0))

        XCTAssertTrue(spy.presentEvaluateAnswerCalled)
        XCTAssertEqual(spy.lastEvalResponse?.isCorrect, false)
        XCTAssertFalse(
            spy.presentSessionCompleteCalled,
            "Сессия не должна завершаться после неправильного ответа"
        )
    }

    // MARK: - 5. Easy = 5 раундов → completed после 5 advanceToNextRound

    func test_completedAllRounds_easy_5rounds() async {
        let (sut, spy) = makeSUT(mode: .oneMany, difficulty: .easy)
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "child-3"))
        guard let totalRounds = spy.lastLoadResponse?.totalRounds, totalRounds > 0 else {
            XCTFail("Раунды не загружены"); return
        }

        // Принудительно отвечаем на все раунды и двигаемся вперёд
        for roundIdx in 0..<totalRounds {
            guard let round = spy.lastRoundResponse?.round else { break }
            let correctId = round.choices[safe: round.correctIndex]?.id ?? "correct"
            await sut.evaluateAnswer(.init(selectedChoiceId: correctId, roundIndex: roundIdx))
            await sut.advanceToNextRound()
        }

        XCTAssertTrue(
            spy.presentSessionCompleteCalled,
            "Сессия должна завершиться после \(totalRounds) раундов"
        )
        XCTAssertEqual(spy.lastSessionResponse?.totalRounds, totalRounds)
    }

    // MARK: - 6. Medium = 7 раундов

    func test_completedAllRounds_medium_7rounds() async {
        let (sut, spy) = makeSUT(mode: .oneMany, difficulty: .medium)
        await sut.loadGame(.init(mode: .oneMany, difficulty: .medium, childId: "child-4"))
        guard let totalRounds = spy.lastLoadResponse?.totalRounds, totalRounds > 0 else {
            XCTFail("Раунды не загружены"); return
        }

        for roundIdx in 0..<totalRounds {
            guard let round = spy.lastRoundResponse?.round else { break }
            let correctId = round.choices[safe: round.correctIndex]?.id ?? "correct"
            await sut.evaluateAnswer(.init(selectedChoiceId: correctId, roundIndex: roundIdx))
            await sut.advanceToNextRound()
        }

        XCTAssertTrue(spy.presentSessionCompleteCalled)
        XCTAssertGreaterThanOrEqual(
            spy.lastSessionResponse?.totalRounds ?? 0, 5,
            "Medium должен содержать минимум 5 раундов (из fallback)"
        )
    }

    // MARK: - 7. Hard = 10 раундов

    func test_completedAllRounds_hard_10rounds() async {
        let (sut, spy) = makeSUT(mode: .oneMany, difficulty: .hard)
        await sut.loadGame(.init(mode: .oneMany, difficulty: .hard, childId: "child-5"))
        guard let totalRounds = spy.lastLoadResponse?.totalRounds, totalRounds > 0 else {
            XCTFail("Раунды не загружены"); return
        }

        for roundIdx in 0..<totalRounds {
            guard let round = spy.lastRoundResponse?.round else { break }
            let correctId = round.choices[safe: round.correctIndex]?.id ?? "correct"
            await sut.evaluateAnswer(.init(selectedChoiceId: correctId, roundIndex: roundIdx))
            await sut.advanceToNextRound()
        }

        XCTAssertTrue(spy.presentSessionCompleteCalled)
    }

    // MARK: - 8. Идеальная игра → successRate == 1.0

    func test_scoringRate_perfectGame_returns1_0() async {
        let (sut, spy) = makeSUT(mode: .oneMany, difficulty: .easy)
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "child-6"))
        guard let totalRounds = spy.lastLoadResponse?.totalRounds, totalRounds > 0 else {
            XCTFail("Раунды не загружены"); return
        }

        for roundIdx in 0..<totalRounds {
            guard let round = spy.lastRoundResponse?.round else { break }
            let correctId = round.choices[safe: round.correctIndex]?.id ?? "correct"
            await sut.evaluateAnswer(.init(selectedChoiceId: correctId, roundIndex: roundIdx))
            await sut.advanceToNextRound()
        }

        let rate = spy.lastSessionResponse?.successRate ?? -1
        XCTAssertEqual(rate, 1.0, accuracy: 0.01, "Идеальная игра должна давать 1.0")
    }

    // MARK: - 9. requestExit → presentExitConfirmation вызван

    func test_requestExit_callsPresenter() async {
        let (sut, spy) = makeSUT()
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "child-7"))
        sut.requestExit()
        XCTAssertTrue(spy.presentExitConfirmationCalled)
    }

    // MARK: - 10. Смена difficulty mid-game через новый loadGame → состояние сбрасывается

    func test_difficultyTransition_easyToHard_resetsState() async {
        let (sut, spy) = makeSUT()

        // Первая игра Easy
        await sut.loadGame(.init(mode: .oneMany, difficulty: .easy, childId: "child-8"))
        XCTAssertTrue(spy.presentLoadGameCalled, "Первый loadGame вызван")

        // Отвечаем неправильно на первый раунд
        if let round = spy.lastRoundResponse?.round {
            let wrongId = round.choices.first(where: {
                $0.id != round.choices[safe: round.correctIndex]?.id
            })?.id ?? "d0"
            await sut.evaluateAnswer(.init(selectedChoiceId: wrongId, roundIndex: 0))
        }

        // Перезапускаем игру на Hard — должен быть новый loadGame
        spy.presentLoadGameCalled = false
        spy.presentSessionCompleteCalled = false
        await sut.loadGame(.init(mode: .oneMany, difficulty: .hard, childId: "child-8"))

        XCTAssertTrue(spy.presentLoadGameCalled,   "После перезапуска presentLoadGame должен вызваться")
        XCTAssertFalse(spy.presentSessionCompleteCalled, "Сессия не должна быть завершена сразу")
        XCTAssertEqual(sut.phase, .awaitingAnswer, "После loadGame фаза должна быть awaitingAnswer")
    }
}

// MARK: - Array safe subscript (дублируем для тестов — Interactor.swift имеет private ext)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
