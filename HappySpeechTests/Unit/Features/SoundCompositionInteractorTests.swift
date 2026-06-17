@testable import HappySpeech
import XCTest

// MARK: - SoundCompositionInteractorTests
//
// Проверяет бизнес-логику «Мастерской звукового состава»: старт сессии,
// постановку фишек (верный цвет / мягкая подсказка), синтез, бонус-цепочку,
// скоринг по «чистым» словам и запись результата в планировщик.

@MainActor
final class SoundCompositionInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: SoundCompositionPresentationLogic {
        var startResponse: SoundCompositionModels.Start.Response?
        var loadWordResponses: [SoundCompositionModels.LoadWord.Response] = []
        var placeChipResponses: [SoundCompositionModels.PlaceChip.Response] = []
        var synthesisResponse: SoundCompositionModels.Synthesis.Response?
        var bonusResponse: SoundCompositionModels.Bonus.Response?
        var completeResponse: SoundCompositionModels.Complete.Response?
        var playingLog: [Bool] = []

        func presentStart(_ response: SoundCompositionModels.Start.Response) { startResponse = response }
        func presentLoadWord(_ response: SoundCompositionModels.LoadWord.Response) { loadWordResponses.append(response) }
        func presentPlaying(_ isPlaying: Bool) { playingLog.append(isPlaying) }
        func presentPlaceChip(_ response: SoundCompositionModels.PlaceChip.Response, allSounds: [SoundUnit]) {
            placeChipResponses.append(response)
        }
        func presentSynthesis(_ response: SoundCompositionModels.Synthesis.Response) { synthesisResponse = response }
        func presentBonus(_ response: SoundCompositionModels.Bonus.Response) { bonusResponse = response }
        func presentComplete(_ response: SoundCompositionModels.Complete.Response) { completeResponse = response }
    }

    // MARK: - Planner spy

    private final class PlannerSpy: AdaptivePlannerService, @unchecked Sendable {
        private(set) var sessionResults: [(sound: String, quality: SM2Quality)] = []
        private(set) var itemOutcomes: [(itemId: String, correct: Bool)] = []

        func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
            AdaptiveRoute(steps: [], maxDurationSec: 0, fatigueLevel: .fresh, disorder: .dyslalia)
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

    // MARK: - Fixtures

    /// МАК (hard, vowel, hard) + бонус-цепочка → РАК.
    private func makWord() -> SoundCompositionWord {
        SoundCompositionWord(
            id: "mak", text: "мак", imageAsset: "word_mak",
            stressIndex: 2, syllables: ["мак"],
            sounds: [
                SoundUnit(letter: "М", type: .hard),
                SoundUnit(letter: "А", type: .vowel),
                SoundUnit(letter: "К", type: .hard)
            ],
            chain: SoundChain(
                baseText: "мак", baseAsset: "word_mak",
                variants: [
                    SoundChain.Variant(swapTo: "Р", text: "рак", asset: "word_rak"),
                    SoundChain.Variant(swapTo: "Л", text: "лак", asset: "word_lak")
                ]
            )
        )
    }

    /// КИТ (soft, vowel, hard).
    private func kitWord() -> SoundCompositionWord {
        SoundCompositionWord(
            id: "kit", text: "кит", imageAsset: "word_kit",
            stressIndex: 2, syllables: ["кит"],
            sounds: [
                SoundUnit(letter: "К", type: .soft),
                SoundUnit(letter: "И", type: .vowel),
                SoundUnit(letter: "Т", type: .hard)
            ],
            chain: nil
        )
    }

    private func makeSUT(words: [SoundCompositionWord]) -> (SoundCompositionInteractor, SpyPresenter, PlannerSpy) {
        let spy = SpyPresenter()
        let planner = PlannerSpy()
        let sut = SoundCompositionInteractor(
            childId: "child-1",
            childAge: 7,
            builder: SoundCompositionBuilder(),
            adaptivePlanner: planner,
            seededWords: words
        )
        sut.presenter = spy
        return (sut, spy, planner)
    }

    // MARK: - start

    func test_start_presentsSeededWords() async {
        let (sut, spy, _) = makeSUT(words: [kitWord(), makWord()])
        await sut.start(.init(childId: "child-1"))
        XCTAssertEqual(spy.startResponse?.words.count, 2)
        XCTAssertEqual(spy.startResponse?.words.first?.text, "кит")
    }

    // MARK: - placeChip correct

    func test_placeChip_correctColor_advancesAndPlaces() async {
        let (sut, spy, _) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        // К — мягкий.
        sut.placeChip(.init(chosenType: .soft))
        let r = spy.placeChipResponses.last
        XCTAssertEqual(r?.isCorrect, true)
        XCTAssertEqual(r?.soundIndex, 0)
        XCTAssertEqual(r?.isWordComplete, false)
    }

    func test_placeChip_wrongColor_givesSoftHint_doesNotAdvance() async {
        let (sut, spy, _) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        // К — мягкий, ребёнок ставит твёрдый → мягкая подсказка, без продвижения.
        sut.placeChip(.init(chosenType: .hard))
        let r = spy.placeChipResponses.last
        XCTAssertEqual(r?.isCorrect, false)
        XCTAssertEqual(r?.soundIndex, 0, "Остаёмся на том же звуке")
        XCTAssertEqual(r?.correctType, .soft, "Подсказка указывает верный тип")
    }

    func test_placeChip_fullWord_marksComplete() async {
        let (sut, spy, _) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        sut.placeChip(.init(chosenType: .soft))   // К
        sut.placeChip(.init(chosenType: .vowel))  // И
        sut.placeChip(.init(chosenType: .hard))   // Т
        XCTAssertEqual(spy.placeChipResponses.last?.isWordComplete, true)
    }

    func test_placeChip_recoversAfterWrong() async {
        let (sut, spy, _) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        sut.placeChip(.init(chosenType: .vowel))  // неверно (К — мягкий)
        sut.placeChip(.init(chosenType: .soft))   // верно
        XCTAssertEqual(spy.placeChipResponses.last?.isCorrect, true)
        XCTAssertEqual(spy.placeChipResponses.last?.soundIndex, 0)
    }

    // MARK: - synthesis

    func test_enterSynthesis_buildsChipsAndBonus() async {
        let (sut, spy, _) = makeSUT(words: [makWord()])
        await sut.start(.init(childId: "child-1"))
        sut.placeChip(.init(chosenType: .hard))   // М
        sut.placeChip(.init(chosenType: .vowel))  // А
        sut.placeChip(.init(chosenType: .hard))   // К
        sut.enterSynthesis()
        XCTAssertEqual(spy.synthesisResponse?.chips.count, 3)
        XCTAssertEqual(spy.synthesisResponse?.word.text, "мак")
        XCTAssertEqual(spy.synthesisResponse?.word.chain?.variants.count, 2)
    }

    // MARK: - bonus

    func test_chooseBonus_targetVariant_isCorrect() async {
        let (sut, spy, _) = makeSUT(words: [makWord()])
        await sut.start(.init(childId: "child-1"))
        sut.enterSynthesis()
        sut.chooseBonus(.init(variantIndex: 0)) // РАК — целевой
        XCTAssertEqual(spy.bonusResponse?.isCorrect, true)
        XCTAssertEqual(spy.bonusResponse?.resultWord, "рак")
    }

    func test_chooseBonus_otherVariant_isIncorrect() async {
        let (sut, spy, _) = makeSUT(words: [makWord()])
        await sut.start(.init(childId: "child-1"))
        sut.enterSynthesis()
        sut.chooseBonus(.init(variantIndex: 1)) // ЛАК — не целевой
        XCTAssertEqual(spy.bonusResponse?.isCorrect, false)
    }

    // MARK: - scoring & persistence

    func test_completeSession_cleanWords_scoreOne_andRecords() async {
        let (sut, spy, planner) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        sut.placeChip(.init(chosenType: .soft))
        sut.placeChip(.init(chosenType: .vowel))
        sut.placeChip(.init(chosenType: .hard))
        sut.enterSynthesis()
        await sut.advanceWord() // last word → complete

        XCTAssertEqual(spy.completeResponse?.score ?? -1, Float(1.0), accuracy: 0.001)
        XCTAssertEqual(spy.completeResponse?.totalWords, 1)
        XCTAssertEqual(planner.sessionResults.count, 1)
        XCTAssertEqual(planner.sessionResults.first?.quality, .perfect)
        XCTAssertEqual(planner.itemOutcomes.first?.correct, true, "Чистое слово → outcome correct")
    }

    func test_completeSession_withColorError_lowersScore() async {
        let (sut, spy, planner) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        sut.placeChip(.init(chosenType: .hard))   // ошибка цвета на К
        sut.placeChip(.init(chosenType: .soft))   // исправил
        sut.placeChip(.init(chosenType: .vowel))
        sut.placeChip(.init(chosenType: .hard))
        sut.enterSynthesis()
        await sut.advanceWord()

        // Слово было с ошибкой → не «чистое» → score 0 при 1 слове.
        XCTAssertEqual(spy.completeResponse?.score ?? -1, Float(0.0), accuracy: 0.001)
        XCTAssertEqual(planner.itemOutcomes.first?.correct, false)
    }

    func test_advanceWord_movesToNextWord() async {
        let (sut, spy, _) = makeSUT(words: [kitWord(), makWord()])
        await sut.start(.init(childId: "child-1"))
        // Собираем первое слово.
        sut.placeChip(.init(chosenType: .soft))
        sut.placeChip(.init(chosenType: .vowel))
        sut.placeChip(.init(chosenType: .hard))
        sut.enterSynthesis()
        await sut.advanceWord()
        XCTAssertEqual(spy.loadWordResponses.last?.word.text, "мак")
        XCTAssertEqual(spy.loadWordResponses.last?.wordIndex, 1)
        XCTAssertNil(spy.completeResponse, "Сессия ещё не завершена")
    }

    func test_cancel_stopsFurtherPresentation() async {
        let (sut, spy, _) = makeSUT(words: [kitWord()])
        await sut.start(.init(childId: "child-1"))
        sut.cancel()
        sut.placeChip(.init(chosenType: .soft))
        XCTAssertTrue(spy.placeChipResponses.isEmpty, "После cancel фишки не обрабатываются")
    }
}
