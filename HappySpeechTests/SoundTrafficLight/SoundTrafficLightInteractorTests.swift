@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubTrafficLightWorker: SoundTrafficLightWorkerProtocol {
    var response: SoundTrafficLightModels.Start.Response
    private(set) var buildCallCount = 0

    init(response: SoundTrafficLightModels.Start.Response) {
        self.response = response
    }

    func buildSession(childId: String) async -> SoundTrafficLightModels.Start.Response {
        buildCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyTrafficLightPresenter: SoundTrafficLightPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var sortCount = 0
    var phraseCount = 0
    var textCount = 0
    var lastSort: SoundTrafficLightModels.Sort.Response?
    var lastPhrase: SoundTrafficLightModels.ChoosePhrase.Response?
    var lastText: SoundTrafficLightModels.CountText.Response?

    func presentStart(response: SoundTrafficLightModels.Start.Response) async {
        startCount += 1
    }
    func presentSort(response: SoundTrafficLightModels.Sort.Response) async {
        sortCount += 1
        lastSort = response
    }
    func presentChoosePhrase(response: SoundTrafficLightModels.ChoosePhrase.Response) async {
        phraseCount += 1
        lastPhrase = response
    }
    func presentCountText(response: SoundTrafficLightModels.CountText.Response) async {
        textCount += 1
        lastText = response
    }
}

// MARK: - Mock progress store

@MainActor
private final class MockDifferentiationProgressStore: DifferentiationProgressStoring {
    var stored: [String: DifferentiationProgress] = [:]

    func progress(childId: String, pairId: String) -> DifferentiationProgress {
        stored["\(childId).\(pairId)"] ?? DifferentiationProgress(level: .word)
    }
    func save(_ progress: DifferentiationProgress, childId: String, pairId: String) {
        stored["\(childId).\(pairId)"] = progress
    }
    func clear(childId: String) {
        stored = stored.filter { !$0.key.hasPrefix("\(childId).") }
    }
}

// MARK: - Helpers

@MainActor
private func makePair(
    syllablesA: [String] = [],
    syllablesB: [String] = [],
    phrases: [TrafficLightPhrase] = [],
    texts: [TrafficLightText] = []
) -> DifferentiationPair {
    .init(
        id: "p", soundA: "С", soundB: "Ш",
        syllablesA: syllablesA, syllablesB: syllablesB,
        wordsA: ["сок"], wordsB: ["шар"],
        phrases: phrases, texts: texts
    )
}

@MainActor
private func makeResponse(
    rounds: [TrafficLightRound],
    level: DifferentiationLevel = .word,
    phrases: [TrafficLightPhrase] = [],
    texts: [TrafficLightText] = []
) -> SoundTrafficLightModels.Start.Response {
    .init(
        pair: makePair(phrases: phrases, texts: texts),
        level: level,
        rounds: rounds,
        phrases: phrases,
        texts: texts
    )
}

private let twoRounds: [TrafficLightRound] = [
    .init(id: "r1", word: "сок", belongsToA: true),
    .init(id: "r2", word: "шар", belongsToA: false)
]

// MARK: - Interactor Tests

@MainActor
final class SoundTrafficLightInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [TrafficLightRound],
        level: DifferentiationLevel = .word,
        phrases: [TrafficLightPhrase] = [],
        texts: [TrafficLightText] = []
    ) -> (SoundTrafficLightInteractor, SpyTrafficLightPresenter, StubTrafficLightWorker, SpyHapticService) {
        let response = makeResponse(rounds: rounds, level: level, phrases: phrases, texts: texts)
        let worker = StubTrafficLightWorker(response: response)
        let haptic = SpyHapticService()
        let sut = SoundTrafficLightInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic,
            progressStore: MockDifferentiationProgressStore()
        )
        let spy = SpyTrafficLightPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func test_sort_correctAnswer_incrementsCorrectCount() async {
        let (sut, spy, _, haptic) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        // r1 = "сок" belongs to A; picking garage A is correct.
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastSort?.wasCorrect, true)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_sort_wrongAnswer_doesNotIncrementCorrect() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        // r1 belongs to A; picking garage B is wrong.
        await sut.sort(request: .init(pickedGarageA: false))
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(spy.lastSort?.wasCorrect, false)
    }

    func test_sort_advancesThroughRounds() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastSort?.isFinished, false)
        XCTAssertNotNil(spy.lastSort?.nextRound)
        XCTAssertEqual(spy.lastSort?.nextRoundIndex, 1)
    }

    func test_sort_lastRound_marksFinished() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.sort(request: .init(pickedGarageA: false))
        XCTAssertEqual(spy.lastSort?.isFinished, true)
        XCTAssertNil(spy.lastSort?.nextRound)
        XCTAssertNil(spy.lastSort?.nextRoundIndex)
        XCTAssertEqual(spy.lastSort?.correctCount, 2)
    }

    func test_sort_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.sort(request: .init(pickedGarageA: false))
        let countAfterFinish = spy.sortCount
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(spy.sortCount, countAfterFinish)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    // MARK: - Level: syllable

    func test_start_syllableLevel_setsLevel() async {
        let (sut, _, _, _) = makeSUT(rounds: twoRounds, level: .syllable)
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.level, .syllable)
    }

    func test_sort_syllableLevel_checksGarage() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds, level: .syllable)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(spy.lastSort?.wasCorrect, true)
        XCTAssertEqual(spy.lastSort?.level, .syllable)
    }

    // MARK: - Level: phrase

    private let twoPhrases: [TrafficLightPhrase] = [
        .init(id: "p0", text: "Сок и шум.", dominant: .both, wordsA: ["Сок"], wordsB: ["шум"]),
        .init(id: "p1", text: "Сова.", dominant: .soundA, wordsA: ["Сова"], wordsB: [])
    ]

    func test_choosePhrase_correctDominant_isCorrect() async {
        let (sut, spy, _, haptic) = makeSUT(rounds: [], level: .phrase, phrases: twoPhrases)
        await sut.start(request: .init(childId: "child-1"))
        // p0 dominant = both; выбираем both → верно.
        await sut.choosePhrase(request: .init(pickedSide: .both))
        XCTAssertEqual(spy.lastPhrase?.wasCorrect, true)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_choosePhrase_wrongDominant_isIncorrect() async {
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .phrase, phrases: twoPhrases)
        await sut.start(request: .init(childId: "child-1"))
        await sut.choosePhrase(request: .init(pickedSide: .soundA))
        XCTAssertEqual(spy.lastPhrase?.wasCorrect, false)
    }

    func test_choosePhrase_advancesAndFinishes() async {
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .phrase, phrases: twoPhrases)
        await sut.start(request: .init(childId: "child-1"))
        await sut.choosePhrase(request: .init(pickedSide: .both))
        XCTAssertEqual(spy.lastPhrase?.isFinished, false)
        XCTAssertNotNil(spy.lastPhrase?.nextPhrase)
        await sut.choosePhrase(request: .init(pickedSide: .soundA))
        XCTAssertEqual(spy.lastPhrase?.isFinished, true)
        XCTAssertNil(spy.lastPhrase?.nextPhrase)
    }

    func test_sort_onPhraseLevel_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .phrase, phrases: twoPhrases)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(spy.sortCount, 0, "sort не должен срабатывать на уровне фразы")
    }

    // MARK: - Level: text (count)

    private let oneText: [TrafficLightText] = [
        .init(id: "t0", title: "Тест", lines: ["Сок шум."], countA: 5, countB: 3, source: "test")
    ]

    func test_countText_exactAnswer_passes() async {
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .text, texts: oneText)
        await sut.start(request: .init(childId: "child-1"))
        await sut.countText(request: .init(answerA: 5, answerB: 3))
        XCTAssertEqual(spy.lastText?.correctA, true)
        XCTAssertEqual(spy.lastText?.correctB, true)
        XCTAssertEqual(spy.lastText?.textPassed, true)
    }

    func test_countText_withinTolerance_passes() async {
        // Допуск ±1 (критерий ТЕКСТ).
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .text, texts: oneText)
        await sut.start(request: .init(childId: "child-1"))
        await sut.countText(request: .init(answerA: 6, answerB: 2))
        XCTAssertEqual(spy.lastText?.textPassed, true, "±1 в допуске")
    }

    func test_countText_outsideTolerance_fails() async {
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .text, texts: oneText)
        await sut.start(request: .init(childId: "child-1"))
        await sut.countText(request: .init(answerA: 9, answerB: 3))
        XCTAssertEqual(spy.lastText?.correctA, false, "9 vs 5 вне допуска ±1")
        XCTAssertEqual(spy.lastText?.textPassed, false)
    }

    func test_countText_finishes_onLastText() async {
        let (sut, spy, _, _) = makeSUT(rounds: [], level: .text, texts: oneText)
        await sut.start(request: .init(childId: "child-1"))
        await sut.countText(request: .init(answerA: 5, answerB: 3))
        XCTAssertEqual(spy.lastText?.isFinished, true)
        XCTAssertNil(spy.lastText?.nextText)
    }

    // MARK: - Progression / persistence (gate)

    func test_progression_twoQualifyingSyllableSessions_promoteToWord() async {
        let store = MockDifferentiationProgressStore()
        // Старт на слоге.
        store.save(.init(level: .syllable), childId: "child-1", pairId: "p")
        let pair = makePair(syllablesA: ["са"], syllablesB: ["ша"],
                            phrases: twoPhrases, texts: oneText)
        let worker = StubTrafficLightWorker(
            response: .init(pair: pair, level: .syllable,
                            rounds: twoRounds, phrases: [], texts: [])
        )
        let sut = SoundTrafficLightInteractor(
            childId: "child-1", worker: worker,
            hapticService: SpyHapticService(), progressStore: store
        )
        let spy = SpyTrafficLightPresenter()
        sut.presenter = spy

        // Сессия 1: 2/2 = 100% — квалифицирующая.
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.sort(request: .init(pickedGarageA: false))
        XCTAssertEqual(store.progress(childId: "child-1", pairId: "p").level, .syllable,
                       "После 1 сессии ещё слог")

        // Сессия 2: снова 100% — должен перейти на слово.
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.sort(request: .init(pickedGarageA: false))
        XCTAssertEqual(store.progress(childId: "child-1", pairId: "p").level, .word,
                       "После 2 успешных сессий слог → слово")
    }

    func test_progression_failingSession_doesNotPromote() async {
        let store = MockDifferentiationProgressStore()
        store.save(.init(level: .word), childId: "child-1", pairId: "p")
        let pair = makePair(phrases: twoPhrases, texts: oneText)
        let worker = StubTrafficLightWorker(
            response: .init(pair: pair, level: .word, rounds: twoRounds)
        )
        let sut = SoundTrafficLightInteractor(
            childId: "child-1", worker: worker,
            hapticService: SpyHapticService(), progressStore: store
        )
        sut.presenter = SpyTrafficLightPresenter()

        // 1/2 = 50% — ниже порога 90%, перехода нет.
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))   // r1 → A верно
        await sut.sort(request: .init(pickedGarageA: true))   // r2 → B, выбрал A — ошибка
        XCTAssertEqual(store.progress(childId: "child-1", pairId: "p").level, .word,
                       "Неуспешная сессия не повышает уровень")
        XCTAssertEqual(store.progress(childId: "child-1", pairId: "p").consecutiveQualifyingSessions, 0)
    }
}

// MARK: - Corpus Tests

final class SoundTrafficLightCorpusTests: XCTestCase {

    func test_corpus_hasDifferentiationPairs() {
        // v29: пак pack_differentiation.json содержит не менее 9 пар.
        XCTAssertGreaterThanOrEqual(SoundTrafficLightCorpus.pairs.count, 9)
    }

    func test_corpus_pairsHaveWordsForBothSounds() {
        for pair in SoundTrafficLightCorpus.pairs {
            XCTAssertGreaterThanOrEqual(pair.wordsA.count, SoundTrafficLightCorpus.roundsPerSession / 2)
            XCTAssertGreaterThanOrEqual(pair.wordsB.count, SoundTrafficLightCorpus.roundsPerSession / 2)
        }
    }

    func test_recommendedPair_matchesTargetSound() {
        let pair = SoundTrafficLightCorpus.recommendedPair(for: ["Р"])
        XCTAssertTrue(pair.soundA == "Р" || pair.soundB == "Р")
    }

    func test_recommendedPair_unknownSound_returnsDefault() {
        let pair = SoundTrafficLightCorpus.recommendedPair(for: ["Я"])
        XCTAssertEqual(pair.id, SoundTrafficLightCorpus.pairs[0].id)
    }

    func test_pairIdsAreUnique() {
        let ids = SoundTrafficLightCorpus.pairs.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
