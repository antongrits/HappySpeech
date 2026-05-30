@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubSnailWorker: SyllableSnailWorkerProtocol {
    var response: SyllableSnailModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastMode: SnailMode?
    private(set) var lastTier: SyllableTier?

    init(response: SyllableSnailModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        mode: SnailMode?,
        preferredTier: SyllableTier?
    ) async -> SyllableSnailModels.Start.Response {
        buildCallCount += 1
        lastMode = mode
        lastTier = preferredTier
        return response
    }

    func makeTiles(from word: SnailWord) -> [SyllableTile] {
        word.syllables.enumerated().map { SyllableTile(id: "\(word.id)-\($0.offset)-\($0.element)", text: $0.element) }
    }
    func makeScrambledTiles(from word: SnailWord) -> [SyllableTile] {
        makeTiles(from: word)
    }
    func voiceSyllables(_ word: SnailWord, slowed: Bool) async {}
}

// MARK: - Spy Presenter

@MainActor
private final class SpySnailPresenter: SyllableSnailPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var tapCount = 0
    var submitCount = 0
    var fixCount = 0
    var lastTap: SyllableSnailModels.Tap.Response?
    var lastSubmit: SyllableSnailModels.Submit.Response?
    var lastFix: SyllableSnailModels.Fix.Response?

    func presentStart(response: SyllableSnailModels.Start.Response) async { startCount += 1 }
    func presentTap(response: SyllableSnailModels.Tap.Response) async { tapCount += 1; lastTap = response }
    func presentSubmit(response: SyllableSnailModels.Submit.Response) async { submitCount += 1; lastSubmit = response }
    func presentFix(response: SyllableSnailModels.Fix.Response) async { fixCount += 1; lastFix = response }
}

// MARK: - Spy AdaptivePlanner

private final class SpySnailPlanner: AdaptivePlannerService, @unchecked Sendable {
    private let lock = NSLock()
    private var _recordCount = 0
    private var _lastSound: String?
    private var _lastQuality: SM2Quality?

    var recordCount: Int { lock.withLock { _recordCount } }
    var lastSound: String? { lock.withLock { _lastSound } }
    var lastQuality: SM2Quality? { lock.withLock { _lastQuality } }

    func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        AdaptiveRoute(steps: [], maxDurationSec: 600, fatigueLevel: .normal)
    }
    func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
    func recordSessionResult(childId: String, soundTarget: String, qualityScore: SM2Quality) async throws {
        lock.withLock {
            _recordCount += 1
            _lastSound = soundTarget
            _lastQuality = qualityScore
        }
    }
    func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool { false }
}

// MARK: - Helpers

@MainActor
private func makeWord(
    id: String = "w",
    word: String = "машина",
    syllables: [String] = ["ма", "ши", "на"],
    tier: SyllableTier = .threeSyllablesWithClosed
) -> SnailWord {
    SnailWord(
        base: SyllableWord(id: id, word: word, syllables: syllables, tier: tier),
        imageAsset: "word_car",
        markovaClass: 6,
        audioSyllables: syllables,
        scrambledHints: []
    )
}

@MainActor
private func makeRound(
    word: SnailWord,
    mode: SnailMode,
    suffix: String = "0"
) -> SnailRound {
    let tiles: [SyllableTile]
    switch mode {
    case .clap:
        tiles = []
    case .build, .fix:
        tiles = word.syllables.enumerated().map {
            SyllableTile(id: "\(word.id)-\($0.offset)-\($0.element)", text: $0.element)
        }
    }
    return SnailRound(id: "\(mode.rawValue)-\(word.id)-\(suffix)", word: word, mode: mode, tiles: tiles)
}

@MainActor
private func makeSUT(
    rounds: [SnailRound],
    mode: SnailMode,
    tier: SyllableTier = .threeSyllablesWithClosed
) -> (SyllableSnailInteractor, SpySnailPresenter, SpyHapticService, SpySnailPlanner) {
    let response = SyllableSnailModels.Start.Response(mode: mode, tier: tier, rounds: rounds)
    let worker = StubSnailWorker(response: response)
    let haptic = SpyHapticService()
    let planner = SpySnailPlanner()
    let sut = SyllableSnailInteractor(
        childId: "child-1", worker: worker, hapticService: haptic, adaptivePlanner: planner
    )
    let spy = SpySnailPresenter()
    sut.presenter = spy
    return (sut, spy, haptic, planner)
}

/// Возвращает id плиток раунда в порядке текстов `order`.
@MainActor
private func ids(in round: SnailRound, order: [String]) -> [String] {
    var remaining = round.tiles
    var result: [String] = []
    for text in order {
        if let idx = remaining.firstIndex(where: { $0.text == text }) {
            result.append(remaining.remove(at: idx).id)
        }
    }
    return result
}

// MARK: - Interactor Tests

@MainActor
final class SyllableSnailInteractorTests: XCTestCase {

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let word = makeWord()
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, spy, _, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.sessionMode, .clap)
    }

    func test_start_resetsProgress() async {
        let word = makeWord()
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, _, _, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        await sut.tap(request: .init(tapCount: 3, attemptInRound: 1)) // hit (3 слога)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    // MARK: Режим A — «Прохлопай» (clap)

    func test_clap_exactCount_isHit() async {
        let word = makeWord(syllables: ["ма", "ши", "на"]) // 3 слога
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, spy, haptic, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        await sut.tap(request: .init(tapCount: 3, attemptInRound: 1))
        XCTAssertEqual(spy.lastTap?.feedback, .hit)
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertTrue(spy.lastTap?.snailReachedHome ?? false)
        XCTAssertTrue(spy.lastTap?.advancedToNextRound ?? false)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_clap_offByOne_isAlmost_doesNotAdvance() async {
        let word = makeWord(syllables: ["ма", "ши", "на"]) // 3
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, spy, _, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        // 2 тапа при 3 слогах → ±1 → almost.
        await sut.tap(request: .init(tapCount: 2, attemptInRound: 1))
        XCTAssertEqual(spy.lastTap?.feedback, .almost)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertTrue(spy.lastTap?.replayBySyllable ?? false)
        XCTAssertFalse(spy.lastTap?.showHint ?? true)
    }

    func test_clap_farOff_firstAttempt_isAlmost_neverWrong() async {
        let word = makeWord(syllables: ["ма", "ши", "на"]) // 3
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, spy, _, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        // 6 тапов при 3 слогах → не ±1, но первый промах всё равно «почти» (не «неправильно»).
        await sut.tap(request: .init(tapCount: 6, attemptInRound: 1))
        XCTAssertEqual(spy.lastTap?.feedback, .almost)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func test_clap_secondMiss_isRetry_showsHint_andAdvances() async {
        let word = makeWord(syllables: ["ма", "ши", "на"]) // 3
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, spy, _, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        await sut.tap(request: .init(tapCount: 1, attemptInRound: 1))
        await sut.tap(request: .init(tapCount: 5, attemptInRound: 2))
        XCTAssertEqual(spy.lastTap?.feedback, .retry)
        XCTAssertTrue(spy.lastTap?.showHint ?? false, "После 2 промахов — подсказка")
        XCTAssertTrue(spy.lastTap?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0, "Счётчик попыток сброшен на новом раунде")
    }

    // MARK: Режим B — «Выложи» (build)

    func test_build_correctOrder_isHit() async {
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let round = makeRound(word: word, mode: .build)
        let (sut, spy, _, _) = makeSUT(rounds: [round], mode: .build)
        await sut.start(request: .init(childId: "child-1", mode: .build, preferredTier: nil))
        let correctIds = ids(in: round, order: ["ма", "ши", "на"])
        await sut.submit(request: .init(tileIds: correctIds, attemptInRound: 1))
        XCTAssertEqual(spy.lastSubmit?.feedback, .hit)
        XCTAssertEqual(spy.lastSubmit?.assembled, "машина")
        XCTAssertTrue(spy.lastSubmit?.snailReachedHome ?? false)
    }

    func test_build_oneSwapDistance_firstAttempt_isAlmost() async {
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let round = makeRound(word: word, mode: .build)
        let (sut, spy, _, _) = makeSUT(rounds: [round], mode: .build)
        await sut.start(request: .init(childId: "child-1", mode: .build, preferredTier: nil))
        // Переставлены 2 соседних слога → Левенштейн = 2; но первый промах = almost by methodology.
        let order = ids(in: round, order: ["ма", "на", "ши"])
        await sut.submit(request: .init(tileIds: order, attemptInRound: 1))
        XCTAssertEqual(spy.lastSubmit?.feedback, .almost)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: Режим C — «Почини» (fix, ядро)

    func test_fix_correctOrder_isHit_andRecordsResult() async {
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let round = makeRound(word: word, mode: .fix)
        let (sut, spy, haptic, planner) = makeSUT(rounds: [round], mode: .fix)
        await sut.start(request: .init(childId: "child-1", mode: .fix, preferredTier: nil))
        let correctIds = ids(in: round, order: ["ма", "ши", "на"])
        await sut.fix(request: .init(orderedTileIds: correctIds, attemptInRound: 1))
        XCTAssertEqual(spy.lastFix?.feedback, .hit)
        XCTAssertEqual(spy.lastFix?.assembled, "машина")
        XCTAssertTrue(spy.lastFix?.isFinished ?? false)
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastSound, SyllableSnailInteractor.skillTarget)
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_fix_secondMiss_showsFirstWrongSlotIndex() async {
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let round = makeRound(word: word, mode: .fix)
        let (sut, spy, _, _) = makeSUT(rounds: [round], mode: .fix)
        await sut.start(request: .init(childId: "child-1", mode: .fix, preferredTier: nil))
        // Неверно: "на ма ши" — первый слот (0) уже неверен.
        let wrong = ids(in: round, order: ["на", "ма", "ши"])
        await sut.fix(request: .init(orderedTileIds: wrong, attemptInRound: 1))
        await sut.fix(request: .init(orderedTileIds: wrong, attemptInRound: 2))
        XCTAssertEqual(spy.lastFix?.feedback, .retry)
        XCTAssertTrue(spy.lastFix?.showHint ?? false)
        XCTAssertEqual(spy.lastFix?.firstWrongSlotIndex, 0)
    }

    // MARK: Прогресс / завершение / адаптив

    func test_finish_lowAccuracy_recordsLowerQuality() async {
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let rounds = [makeRound(word: word, mode: .clap), makeRound(word: word, mode: .clap, suffix: "1")]
        let (sut, _, _, planner) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        // r1: 2 промаха → retry advance (0 верных).
        await sut.tap(request: .init(tapCount: 1, attemptInRound: 1))
        await sut.tap(request: .init(tapCount: 5, attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 верных).
        await sut.tap(request: .init(tapCount: 1, attemptInRound: 1))
        await sut.tap(request: .init(tapCount: 5, attemptInRound: 2))
        XCTAssertEqual(planner.recordCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }

    func test_tap_afterFinish_isIgnored() async {
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let rounds = [makeRound(word: word, mode: .clap)]
        let (sut, spy, _, _) = makeSUT(rounds: rounds, mode: .clap)
        await sut.start(request: .init(childId: "child-1", mode: .clap, preferredTier: nil))
        await sut.tap(request: .init(tapCount: 3, attemptInRound: 1)) // hit, finishes
        let after = spy.tapCount
        await sut.tap(request: .init(tapCount: 3, attemptInRound: 1))
        XCTAssertEqual(spy.tapCount, after, "Тапы после завершения игнорируются")
    }

    func test_feedbackTier_hasNoWrongCase() {
        // Методика: только hit/almost/retry — никакого «неправильно».
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }
}

// MARK: - Levenshtein / firstWrongIndex (pure)

final class SyllableSnailLevenshteinTests: XCTestCase {

    func test_levenshtein_identical_isZero() {
        XCTAssertEqual(SyllableSnailInteractor.syllableLevenshtein(["ма", "ши", "на"], ["ма", "ши", "на"]), 0)
    }

    func test_levenshtein_oneReplacement_isOne() {
        XCTAssertEqual(SyllableSnailInteractor.syllableLevenshtein(["ма", "ши", "на"], ["ма", "ло", "на"]), 1)
    }

    func test_levenshtein_oneMissing_isOne() {
        // Пропуск слога (типовая НСС-ошибка элизии).
        XCTAssertEqual(SyllableSnailInteractor.syllableLevenshtein(["ма", "на"], ["ма", "ши", "на"]), 1)
    }

    func test_levenshtein_emptyVsNonEmpty() {
        XCTAssertEqual(SyllableSnailInteractor.syllableLevenshtein([], ["ма", "ши"]), 2)
    }

    func test_firstWrongIndex_findsFirstMismatch() {
        XCTAssertEqual(SyllableSnailInteractor.firstWrongIndex(["ма", "на", "ши"], ["ма", "ши", "на"]), 1)
    }

    func test_firstWrongIndex_allCorrect_isNil() {
        XCTAssertNil(SyllableSnailInteractor.firstWrongIndex(["ма", "ши", "на"], ["ма", "ши", "на"]))
    }

    func test_firstWrongIndex_tooShort_pointsToMissingSlot() {
        XCTAssertEqual(SyllableSnailInteractor.firstWrongIndex(["ма", "ши"], ["ма", "ши", "на"]), 2)
    }
}

// MARK: - Worker tier resolution / building

@MainActor
final class SyllableSnailWorkerTests: XCTestCase {

    func test_ageGate_age5_isTier1() {
        XCTAssertEqual(SyllableSnailWorker.ageAllowedTier(age: 5), .oneSyllableOpen)
    }

    func test_ageGate_age6_isTier3() {
        XCTAssertEqual(SyllableSnailWorker.ageAllowedTier(age: 6), .threeSyllablesWithClosed)
    }

    func test_ageGate_age7_isTier4() {
        XCTAssertEqual(SyllableSnailWorker.ageAllowedTier(age: 7), .consonantCluster)
    }

    func test_resolveTier_capsPreferredAtAgeGate() {
        // 5-летке нельзя tier 4, даже если просят.
        XCTAssertEqual(SyllableSnailWorker.resolveTier(preferredTier: .consonantCluster, age: 5), .oneSyllableOpen)
    }

    func test_resolveTier_allowsLowerThanGate() {
        XCTAssertEqual(SyllableSnailWorker.resolveTier(preferredTier: .oneSyllableOpen, age: 8), .oneSyllableOpen)
    }

    func test_resolveTier_nilUsesAgeGate() {
        XCTAssertEqual(SyllableSnailWorker.resolveTier(preferredTier: nil, age: 6), .threeSyllablesWithClosed)
    }

    func test_makeRounds_retroStart_beginsWithTier1() {
        let worker = SyllableSnailWorker(childRepository: MockChildRepository())
        let rounds = worker.makeRounds(mode: .clap, tier: .threeSyllablesWithClosed)
        XCTAssertGreaterThanOrEqual(rounds.count, 3)
        XCTAssertEqual(rounds[0].word.tier, .oneSyllableOpen)
        XCTAssertEqual(rounds[1].word.tier, .oneSyllableOpen)
        XCTAssertTrue(rounds.contains { $0.word.tier == .threeSyllablesWithClosed })
    }

    func test_makeRounds_tier1_noRetroPrefix() {
        let worker = SyllableSnailWorker(childRepository: MockChildRepository())
        let rounds = worker.makeRounds(mode: .clap, tier: .oneSyllableOpen)
        XCTAssertTrue(rounds.allSatisfy { $0.word.tier == .oneSyllableOpen })
    }

    func test_makeRounds_respectsRoundsPerSession() {
        let worker = SyllableSnailWorker(childRepository: MockChildRepository())
        let rounds = worker.makeRounds(mode: .build, tier: .threeSyllablesWithClosed)
        XCTAssertEqual(rounds.count, SyllableSnailCorpus.roundsPerSession)
    }

    func test_makeRounds_buildMode_onlyMultiSyllableWords() {
        // build требует ≥ 2 слогов (нечего собирать из одного).
        let worker = SyllableSnailWorker(childRepository: MockChildRepository())
        let rounds = worker.makeRounds(mode: .build, tier: .consonantCluster)
        XCTAssertTrue(rounds.allSatisfy { $0.word.syllables.count >= 2 })
    }

    func test_makeScrambledTiles_isNonIdentityForMultiSyllable() {
        let worker = SyllableSnailWorker(childRepository: MockChildRepository())
        let word = makeWord(syllables: ["ма", "ши", "на"])
        let scrambled = worker.makeScrambledTiles(from: word).map(\.text)
        XCTAssertNotEqual(scrambled, word.syllables, "Перестановка должна отличаться от исходной")
        XCTAssertEqual(scrambled.sorted(), word.syllables.sorted(), "Те же слоги, иной порядок")
    }
}

// MARK: - Corpus Tests

final class SyllableSnailCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(SyllableSnailCorpus.allWords.isEmpty)
    }

    func test_wordIds_areUnique() {
        let ids = SyllableSnailCorpus.allWords.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_eachTier_hasAtLeast20Words() {
        for tier in SyllableTier.allCases {
            let count = SyllableSnailCorpus.words(for: tier).count
            XCTAssertGreaterThanOrEqual(count, 20, "Tier \(tier.rawValue) only \(count) words")
        }
    }

    func test_everyWord_hasImageAndSyllablesAndMarkova() {
        for word in SyllableSnailCorpus.allWords {
            XCTAssertFalse(word.imageAsset.isEmpty, "no image: \(word.id)")
            XCTAssertFalse(word.syllables.isEmpty, "no syllables: \(word.id)")
            XCTAssertFalse(word.word.isEmpty)
            XCTAssertTrue((1...13).contains(word.markovaClass), "markovaClass out of range: \(word.id)")
        }
    }

    func test_buildAndFixModes_excludeSingleSyllableWords() {
        for tier in SyllableTier.allCases {
            for word in SyllableSnailCorpus.words(for: tier, mode: .build) {
                XCTAssertGreaterThanOrEqual(word.syllables.count, 2)
            }
            for word in SyllableSnailCorpus.words(for: tier, mode: .fix) {
                XCTAssertGreaterThanOrEqual(word.syllables.count, 2)
            }
        }
    }

    func test_scrambledHints_whenPresent_arePermutationOfSyllables() {
        for word in SyllableSnailCorpus.allWords where !word.scrambledHints.isEmpty {
            XCTAssertEqual(word.scrambledHints.sorted(), word.syllables.sorted(),
                           "scrambledHints не перестановка слогов: \(word.id)")
            XCTAssertNotEqual(word.scrambledHints, word.syllables,
                              "scrambledHints совпадает с исходным порядком: \(word.id)")
        }
    }
}
