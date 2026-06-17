@testable import HappySpeech
import XCTest

// MARK: - AdvancedGrammarInteractorTests
//
// Проверяет бизнес-логику «Грамматического конструктора-2»: загрузку трёх
// режимов, корректность грамматических форм в собранных раундах, скоринг по
// первой попытке, мягкую коррекцию при ошибке и запись результата в планировщик.

@MainActor
final class AdvancedGrammarInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: AdvancedGrammarPresentationLogic {
        var startResponse: AdvancedGrammarModels.Start.Response?
        var roundResponses: [AdvancedGrammarModels.PresentRound.Response] = []
        var evaluateResponses: [AdvancedGrammarModels.Evaluate.Response] = []
        var completeResponse: AdvancedGrammarModels.Complete.Response?
        var playingLog: [Bool] = []

        func presentStart(_ response: AdvancedGrammarModels.Start.Response) { startResponse = response }
        func presentRound(_ response: AdvancedGrammarModels.PresentRound.Response) { roundResponses.append(response) }
        func presentPlaying(_ isPlaying: Bool) { playingLog.append(isPlaying) }
        func presentEvaluate(_ response: AdvancedGrammarModels.Evaluate.Response) { evaluateResponses.append(response) }
        func presentComplete(_ response: AdvancedGrammarModels.Complete.Response) { completeResponse = response }
    }

    // MARK: - Planner spy

    private final class PlannerSpy: AdaptivePlannerService, @unchecked Sendable {
        private(set) var sessionResults: [(sound: String, quality: SM2Quality)] = []
        private(set) var itemOutcomes: [(itemId: String, correct: Bool)] = []
        var fatigue: FatigueLevel = .fresh

        func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
            AdaptiveRoute(steps: [], maxDurationSec: 0, fatigueLevel: fatigue, disorder: .dyslalia)
        }
        func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
        func recordSessionResult(childId: String, soundTarget: String, qualityScore: SM2Quality) async throws {
            sessionResults.append((soundTarget, qualityScore))
        }
        func recordItemOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
            itemOutcomes.append((itemId, correct))
        }
        func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool { false }
    }

    // MARK: - Fixtures (raw items)

    private func prepositionItems() -> [AdvancedGrammarRawItem] {
        [
            AdvancedGrammarRawItem(
                id: "p0", subject: "котёнок", subjectVerb: "выглянул",
                object: "стол", objectGenitive: "стола", preposition: "из-под",
                scene: "under", hint: "под столом → из-под"),
            AdvancedGrammarRawItem(
                id: "p1", subject: "белка", subjectVerb: "выглянула",
                object: "дерево", objectGenitive: "дерева", preposition: "из-за",
                scene: "behind", hint: "позади дерева → из-за")
        ]
    }

    private func possessiveItems() -> [AdvancedGrammarRawItem] {
        [
            AdvancedGrammarRawItem(
                id: "v0", part: "хвост", partAdjective: "пушистый",
                partGender: "masculine", questionWord: "чей",
                owner: "лиса", possessive: "лисий", hint: "хвост лисы — лисий хвост"),
            AdvancedGrammarRawItem(
                id: "v1", part: "уши", partAdjective: "длинные",
                partGender: "plural", questionWord: "чьи",
                owner: "заяц", possessive: "заячьи", hint: "уши зайца — заячьи уши")
        ]
    }

    private func agreementItems() -> [AdvancedGrammarRawItem] {
        [
            AdvancedGrammarRawItem(
                id: "a0", noun: "машина", gender: "feminine",
                adjectiveStem: "красн", ending: "ая", hint: "машина — она → красная"),
            AdvancedGrammarRawItem(
                id: "a1", noun: "ботинки", gender: "plural",
                adjectiveStem: "нов", ending: "ые", hint: "ботинок много → новые")
        ]
    }

    private func makeSUT(
        mode: AdvancedGrammarMode,
        items: [AdvancedGrammarRawItem],
        difficulty: AdvancedGrammarDifficulty = .medium
    ) -> (AdvancedGrammarInteractor, SpyPresenter, PlannerSpy) {
        let spy = SpyPresenter()
        let planner = PlannerSpy()
        let sut = AdvancedGrammarInteractor(
            childId: "child-1",
            mode: mode,
            content: AdvancedGrammarContentWorker(seededItems: items),
            feedback: AdvancedGrammarFeedbackWorker(),
            adaptivePlanner: planner,
            forcedDifficulty: difficulty
        )
        sut.presenter = spy
        return (sut, spy, planner)
    }

    /// Удобный доступ к текущему раунду (первый из start, затем — последний presentRound).
    private func currentRound(_ spy: SpyPresenter) -> AdvancedGrammarRound? {
        spy.roundResponses.last?.round ?? spy.startResponse?.firstRound
    }

    // MARK: - start / load

    func test_start_loadsPrepositionRounds() async {
        let (sut, spy, _) = makeSUT(mode: .complexPreposition, items: prepositionItems())
        await sut.start(.init(childId: "child-1"))
        XCTAssertEqual(spy.startResponse?.mode, .complexPreposition)
        XCTAssertEqual(spy.startResponse?.totalRounds, 2)
        XCTAssertNotNil(spy.startResponse?.firstRound)
    }

    // MARK: - Grammar correctness: preposition

    func test_preposition_round_hasCorrectFullPhraseAndChoices() async {
        // Один item → детерминированный раунд.
        let (sut, spy, _) = makeSUT(
            mode: .complexPreposition,
            items: [prepositionItems()[0]]
        )
        await sut.start(.init(childId: "child-1"))
        let round = currentRound(spy)
        XCTAssertEqual(round?.correctChoiceId, "из-под")
        XCTAssertEqual(round?.fullPhrase, "Котёнок выглянул из-под стола")
        // Все 4 предлога присутствуют как варианты.
        XCTAssertEqual(round?.choices.count, 4)
        XCTAssertTrue(round?.choices.contains { $0.id == "из-под" } ?? false)
        XCTAssertTrue(round?.choices.contains { $0.id == "из-за" } ?? false)
    }

    // MARK: - Grammar correctness: possessive

    func test_possessive_masculine_usesChey_andCorrectAdjective() async {
        let (sut, spy, _) = makeSUT(mode: .possessive, items: [possessiveItems()[0]])
        await sut.start(.init(childId: "child-1"))
        let round = currentRound(spy)
        XCTAssertEqual(round?.correctChoiceId, "чей", "Хвост — м.р. → чей")
        XCTAssertEqual(round?.fullPhrase, "лисий хвост")
        XCTAssertEqual(round?.gender, .masculine)
    }

    func test_possessive_plural_usesChyi() async {
        let (sut, spy, _) = makeSUT(mode: .possessive, items: [possessiveItems()[1]])
        await sut.start(.init(childId: "child-1"))
        let round = currentRound(spy)
        XCTAssertEqual(round?.correctChoiceId, "чьи", "Уши — мн.ч. → чьи")
        XCTAssertEqual(round?.fullPhrase, "заячьи уши")
        XCTAssertEqual(round?.gender, .plural)
    }

    // MARK: - Grammar correctness: agreement

    func test_agreement_feminine_endingMatches() async {
        let (sut, spy, _) = makeSUT(mode: .agreement, items: [agreementItems()[0]])
        await sut.start(.init(childId: "child-1"))
        let round = currentRound(spy)
        XCTAssertEqual(round?.correctChoiceId, GrammaticalGender.feminine.rawValue)
        XCTAssertEqual(round?.fullPhrase, "красная машина")
        // Женский вариант показывает «красная», не «красный».
        let feminineChoice = round?.choices.first { $0.id == GrammaticalGender.feminine.rawValue }
        XCTAssertEqual(feminineChoice?.primary, "красная")
        let masculineChoice = round?.choices.first { $0.id == GrammaticalGender.masculine.rawValue }
        XCTAssertEqual(masculineChoice?.primary, "красный")
    }

    func test_agreement_plural_endingMatches() async {
        let (sut, spy, _) = makeSUT(mode: .agreement, items: [agreementItems()[1]])
        await sut.start(.init(childId: "child-1"))
        let round = currentRound(spy)
        XCTAssertEqual(round?.correctChoiceId, GrammaticalGender.plural.rawValue)
        XCTAssertEqual(round?.fullPhrase, "новые ботинки")
    }

    // MARK: - evaluate correct (first try)

    func test_evaluate_correctChoice_marksCorrect() async {
        let (sut, spy, _) = makeSUT(mode: .agreement, items: [agreementItems()[0]])
        await sut.start(.init(childId: "child-1"))
        let correct = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: correct))
        let r = spy.evaluateResponses.last
        XCTAssertEqual(r?.isCorrect, true)
        XCTAssertEqual(r?.isFirstAttempt, true)
        XCTAssertEqual(r?.fullPhrase, "красная машина")
        XCTAssertTrue(r?.correctionText.isEmpty ?? false)
    }

    // MARK: - evaluate wrong → soft correction, no advance

    func test_evaluate_wrongChoice_givesSoftCorrection() async {
        let (sut, spy, _) = makeSUT(mode: .agreement, items: [agreementItems()[0]])
        await sut.start(.init(childId: "child-1"))
        // Заведомо неверный — мужской род для женской машины.
        sut.evaluate(.init(selectedChoiceId: GrammaticalGender.masculine.rawValue))
        let r = spy.evaluateResponses.last
        XCTAssertEqual(r?.isCorrect, false)
        XCTAssertFalse(r?.correctionText.isEmpty ?? true, "Должна быть мягкая коррекция")
    }

    func test_evaluate_wrongThenCorrect_notFirstTry() async {
        let (sut, spy, _) = makeSUT(mode: .agreement, items: [agreementItems()[0]])
        await sut.start(.init(childId: "child-1"))
        sut.evaluate(.init(selectedChoiceId: GrammaticalGender.masculine.rawValue)) // wrong
        let correct = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: correct)) // recover
        let r = spy.evaluateResponses.last
        XCTAssertEqual(r?.isCorrect, true)
        XCTAssertEqual(r?.isFirstAttempt, false, "После ошибки очко с первой попытки не засчитывается")
    }

    // MARK: - scoring & persistence

    func test_completeSession_allFirstTry_scoreOne_andRecords() async {
        let (sut, spy, planner) = makeSUT(mode: .agreement, items: agreementItems())
        await sut.start(.init(childId: "child-1"))

        // Первое слово — верно с первой попытки.
        let c0 = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: c0))
        await sut.advance()
        // Второе слово — верно с первой попытки.
        let c1 = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: c1))
        await sut.advance() // last → complete

        XCTAssertEqual(spy.completeResponse?.totalRounds, 2)
        XCTAssertEqual(spy.completeResponse?.correctFirstTry, 2)
        XCTAssertEqual(spy.completeResponse?.successRate ?? -1, Float(1.0), accuracy: 0.001)
        XCTAssertEqual(planner.sessionResults.first?.quality, .perfect)
        XCTAssertEqual(planner.itemOutcomes.count, 2)
        XCTAssertTrue(planner.itemOutcomes.allSatisfy { $0.correct })
    }

    func test_completeSession_withError_lowersScore_andOutcomeFalse() async {
        let (sut, spy, planner) = makeSUT(mode: .agreement, items: [agreementItems()[0]])
        await sut.start(.init(childId: "child-1"))
        sut.evaluate(.init(selectedChoiceId: GrammaticalGender.masculine.rawValue)) // ошибка
        let correct = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: correct))                              // исправил
        await sut.advance() // last → complete

        XCTAssertEqual(spy.completeResponse?.correctFirstTry, 0, "Раунд с ошибкой не даёт очка за первую попытку")
        XCTAssertEqual(spy.completeResponse?.successRate ?? -1, Float(0.0), accuracy: 0.001)
        XCTAssertEqual(planner.itemOutcomes.first?.correct, false)
    }

    // MARK: - advance

    func test_advance_movesToNextRound() async {
        let (sut, spy, _) = makeSUT(mode: .preposition_placeholder(), items: prepositionItems())
        await sut.start(.init(childId: "child-1"))
        let firstId = currentRound(spy)?.id
        let c0 = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: c0))
        await sut.advance()
        XCTAssertEqual(spy.roundResponses.last?.roundIndex, 1)
        XCTAssertNotEqual(spy.roundResponses.last?.round.id, firstId, "Перешли на другой раунд")
        XCTAssertNil(spy.completeResponse, "Сессия ещё не завершена")
    }

    // MARK: - cancel

    func test_cancel_stopsFurtherEvaluation() async {
        let (sut, spy, _) = makeSUT(mode: .agreement, items: [agreementItems()[0]])
        await sut.start(.init(childId: "child-1"))
        sut.cancel()
        let correct = currentRound(spy)?.correctChoiceId ?? ""
        sut.evaluate(.init(selectedChoiceId: correct))
        XCTAssertTrue(spy.evaluateResponses.isEmpty, "После cancel ответы не обрабатываются")
    }

    // MARK: - difficulty respects fatigue

    func test_difficulty_resolvedFromFatigue_whenNotForced() async {
        let spy = SpyPresenter()
        let planner = PlannerSpy()
        planner.fatigue = .tired
        let sut = AdvancedGrammarInteractor(
            childId: "child-1",
            mode: .agreement,
            content: AdvancedGrammarContentWorker(seededItems: agreementItems()),
            feedback: AdvancedGrammarFeedbackWorker(),
            adaptivePlanner: planner,
            forcedDifficulty: nil
        )
        sut.presenter = spy
        await sut.start(.init(childId: "child-1"))
        // При усталости — лёгкий уровень (5 раундов max; здесь items=2 → 2 раунда).
        XCTAssertEqual(spy.startResponse?.difficulty, .easy)
    }
}

// MARK: - Test helper

private extension AdvancedGrammarMode {
    /// Явный алиас, чтобы тест читался ближе к UX-названию режима предлогов.
    static func preposition_placeholder() -> AdvancedGrammarMode { .complexPreposition }
}
