@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubSyllableWorker: SyllableConstructorWorkerProtocol {

    var wordsByTier: [SyllableTier: [SyllableWord]]
    var tilesShuffle: ((SyllableWord) -> [SyllableTile])?
    private(set) var voiceCallCount = 0

    init(wordsByTier: [SyllableTier: [SyllableWord]]) {
        self.wordsByTier = wordsByTier
    }

    func nextWord(for tier: SyllableTier, exclude playedIds: Set<String>) -> SyllableWord? {
        let pool = wordsByTier[tier] ?? []
        if let remaining = pool.first(where: { !playedIds.contains($0.id) }) {
            return remaining
        }
        return pool.first
    }

    func availableTiers() -> [SyllableTier] {
        wordsByTier.keys.sorted(by: { $0.rawValue < $1.rawValue })
    }

    func count(for tier: SyllableTier) -> Int {
        wordsByTier[tier]?.count ?? 0
    }

    func makeTiles(from word: SyllableWord) -> [SyllableTile] {
        if let shuffle = tilesShuffle { return shuffle(word) }
        return word.syllables.enumerated().map { index, syllable in
            SyllableTile(id: "\(word.id)-\(index)", text: syllable)
        }
    }

    func voiceWord(_ word: SyllableWord) async {
        voiceCallCount += 1
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpySyllablePresenter: SyllableConstructorPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var submitCount = 0
    var lastSubmit: SyllableConstructorModels.SubmitGuess.Response?
    var lastStart: SyllableConstructorModels.Start.Response?

    func presentStart(response: SyllableConstructorModels.Start.Response) async {
        startCount += 1
        lastStart = response
    }
    func presentSubmit(response: SyllableConstructorModels.SubmitGuess.Response) async {
        submitCount += 1
        lastSubmit = response
    }
}

// MARK: - Helpers

private func makeWord(_ id: String, syllables: [String], tier: SyllableTier = .oneSyllableOpen) -> SyllableWord {
    SyllableWord(id: id, word: syllables.joined(), syllables: syllables, tier: tier)
}

// MARK: - Interactor Tests

@MainActor
final class SyllableConstructorInteractorTests: XCTestCase {

    private func makeSUT(
        words: [SyllableTier: [SyllableWord]] = [.oneSyllableOpen: [makeWord("w1", syllables: ["ма", "ма"])]]
    ) -> (SyllableConstructorInteractor, SpySyllablePresenter, StubSyllableWorker, SpyHapticService) {
        let worker = StubSyllableWorker(wordsByTier: words)
        let haptic = SpyHapticService()
        let interactor = SyllableConstructorInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic
        )
        let spy = SpySyllablePresenter()
        interactor.presenter = spy
        return (interactor, spy, worker, haptic)
    }

    func test_start_loadsWordAndShuffledTiles() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .oneSyllableOpen))
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.currentWord?.id, "w1")
        XCTAssertEqual(sut.currentTiles.count, 2)
        XCTAssertTrue(sut.playedIds.contains("w1"))
    }

    func test_start_useFirstAvailableTier_whenNoPreferred() async {
        let (sut, _, _, _) = makeSUT(words: [
            .twoSyllablesOpen: [makeWord("w-twoTier", syllables: ["во", "да"], tier: .twoSyllablesOpen)]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        XCTAssertEqual(sut.currentTier, .twoSyllablesOpen)
    }

    func test_submit_correctOrder_returnsTrue_andHaptic() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .oneSyllableOpen))
        let ids = sut.currentTiles.map(\.id)
        // sort by their text positions to match expected
        let orderedIds = sortedIdsForExpected(tiles: sut.currentTiles, expected: ["ма", "ма"])
        await sut.submitGuess(request: .init(tileIds: orderedIds))
        XCTAssertEqual(spy.submitCount, 1)
        XCTAssertEqual(spy.lastSubmit?.isCorrect, true)
        XCTAssertEqual(spy.lastSubmit?.assembled, "мама")
        XCTAssertGreaterThan(haptic.notificationCount, 0)
        _ = ids
    }

    func test_submit_wrongOrder_returnsFalse_andHaptic() async {
        let (sut, spy, _, haptic) = makeSUT(words: [
            .twoSyllablesOpen: [makeWord("w-wrong", syllables: ["во", "да"], tier: .twoSyllablesOpen)]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: .twoSyllablesOpen))
        // Намеренно подаём в обратном порядке.
        let reversedIds = sut.currentTiles.reversed().map(\.id)
        await sut.submitGuess(request: .init(tileIds: reversedIds))
        XCTAssertEqual(spy.lastSubmit?.isCorrect, false)
        XCTAssertEqual(spy.lastSubmit?.assembled, "дaво".lowercased() == "дaво" ? "даво" : "даво")
        XCTAssertGreaterThan(haptic.notificationCount, 0)
    }

    func test_submit_isCaseInsensitive() async {
        let (sut, spy, _, _) = makeSUT(words: [
            .oneSyllableOpen: [makeWord("w-case", syllables: ["Ма", "ма"])]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: .oneSyllableOpen))
        let orderedIds = sortedIdsForExpected(tiles: sut.currentTiles, expected: ["Ма", "ма"])
        await sut.submitGuess(request: .init(tileIds: orderedIds))
        XCTAssertEqual(spy.lastSubmit?.isCorrect, true)
    }

    func test_submit_beforeStart_isIgnored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.submitGuess(request: .init(tileIds: []))
        XCTAssertEqual(spy.submitCount, 0)
    }

    func test_nextWord_clearsCurrentAndLoadsNew() async {
        let (sut, spy, _, _) = makeSUT(words: [
            .oneSyllableOpen: [
                makeWord("w1", syllables: ["ма", "ма"]),
                makeWord("w2", syllables: ["па", "па"])
            ]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: .oneSyllableOpen))
        await sut.nextWord(request: .init(nextTier: nil))
        XCTAssertEqual(spy.startCount, 2)
        XCTAssertEqual(sut.playedIds.count, 2)
    }

    func test_nextWord_canSwitchTier() async {
        let (sut, _, _, _) = makeSUT(words: [
            .oneSyllableOpen: [makeWord("w1", syllables: ["ма"])],
            .twoSyllablesOpen: [makeWord("w2", syllables: ["во", "да"], tier: .twoSyllablesOpen)]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: .oneSyllableOpen))
        await sut.nextWord(request: .init(nextTier: .twoSyllablesOpen))
        XCTAssertEqual(sut.currentTier, .twoSyllablesOpen)
        XCTAssertEqual(sut.currentWord?.id, "w2")
    }

    func test_start_recordsChildId() async {
        let (sut, _, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-XYZ", preferredTier: .oneSyllableOpen))
        XCTAssertEqual(sut.childId, "child-XYZ")
    }

    func test_submit_orderedTextsIgnoresUnknownIds() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .oneSyllableOpen))
        // mix one valid id + one bogus id — bogus is skipped silently.
        let validId = sut.currentTiles.first?.id ?? ""
        await sut.submitGuess(request: .init(tileIds: [validId, "DOES_NOT_EXIST"]))
        XCTAssertNotNil(spy.lastSubmit)
        XCTAssertFalse(spy.lastSubmit?.isCorrect == true)
    }

    func test_start_doesNotCrashWhenEmpty() async {
        let (sut, spy, _, _) = makeSUT(words: [:])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        XCTAssertEqual(spy.startCount, 0)
        XCTAssertNil(sut.currentWord)
    }

    // MARK: - Helpers

    private func sortedIdsForExpected(tiles: [SyllableTile], expected: [String]) -> [String] {
        var remaining = tiles
        var ordered: [String] = []
        for target in expected {
            if let idx = remaining.firstIndex(where: { $0.text == target }) {
                ordered.append(remaining.remove(at: idx).id)
            }
        }
        return ordered
    }
}

// MARK: - Worker Tests

@MainActor
final class SyllableConstructorWorkerTests: XCTestCase {

    func test_makeTiles_producesUniqueIds_evenForDuplicates() {
        let worker = SyllableConstructorWorker()
        let word = SyllableWord(
            id: "test",
            word: "мама",
            syllables: ["ма", "ма"],
            tier: .oneSyllableOpen
        )
        let tiles = worker.makeTiles(from: word)
        XCTAssertEqual(tiles.count, 2)
        XCTAssertEqual(Set(tiles.map(\.id)).count, 2)
    }

    func test_makeTiles_deterministicShuffleWithSeed() {
        let worker = SyllableConstructorWorker(randomSource: { 0.0 })
        let word = SyllableWord(
            id: "test",
            word: "вода",
            syllables: ["во", "да"],
            tier: .twoSyllablesOpen
        )
        let tiles = worker.makeTiles(from: word)
        XCTAssertEqual(tiles.count, 2)
    }
}

// MARK: - Corpus Tests

final class SyllableConstructorCorpusTests: XCTestCase {

    func test_corpus_loadsFromBundle() {
        let all = SyllableConstructorCorpus.allWords
        XCTAssertGreaterThan(all.count, 60, "Корпус должен содержать ≥60 слов")
    }

    func test_corpus_hasAllFourTiers() {
        let tiers = Set(SyllableConstructorCorpus.allWords.map(\.tier))
        XCTAssertEqual(tiers, Set(SyllableTier.allCases))
    }

    func test_corpus_everyWord_hasNonEmptySyllables() {
        for word in SyllableConstructorCorpus.allWords {
            XCTAssertFalse(word.syllables.isEmpty, "Слово \(word.id) без слогов")
            for syllable in word.syllables {
                XCTAssertFalse(syllable.isEmpty, "Слово \(word.id): пустой слог")
            }
        }
    }

    func test_corpus_syllablesAssembleToWord() {
        for word in SyllableConstructorCorpus.allWords {
            XCTAssertEqual(
                word.syllables.joined().lowercased(),
                word.word.lowercased(),
                "Склейка слогов != слову: \(word.id)"
            )
        }
    }

    func test_corpus_idsAreUnique() {
        let ids = SyllableConstructorCorpus.allWords.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
