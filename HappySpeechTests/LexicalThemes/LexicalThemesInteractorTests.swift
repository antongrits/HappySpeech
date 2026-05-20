@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubLexicalWorker: LexicalThemesWorkerProtocol {
    var loadResponse: LexicalThemesModels.LoadThemes.Response
    var sessionResponse: LexicalThemesModels.StartTheme.Response?
    private(set) var loadCount = 0
    private(set) var masteredThemeIds: [String] = []
    private(set) var reviews: [(childId: String, wordId: String, wasCorrect: Bool)] = []
    var stubbedDueCount: Int = 0

    init(
        loadResponse: LexicalThemesModels.LoadThemes.Response,
        sessionResponse: LexicalThemesModels.StartTheme.Response?
    ) {
        self.loadResponse = loadResponse
        self.sessionResponse = sessionResponse
    }

    func loadThemes(childId: String) async -> LexicalThemesModels.LoadThemes.Response {
        loadCount += 1
        return loadResponse
    }
    func buildThemeSession(themeId: String) -> LexicalThemesModels.StartTheme.Response? {
        sessionResponse
    }
    func markThemeMastered(childId: String, themeId: String) async {
        masteredThemeIds.append(themeId)
    }
    func recordReview(childId: String, wordId: String, wasCorrect: Bool) async {
        reviews.append((childId, wordId, wasCorrect))
    }
    func dueCount(childId: String, at date: Date) async -> Int {
        stubbedDueCount
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyLexicalPresenter: LexicalThemesPresentationLogic, @unchecked Sendable {
    var themesCount = 0
    var startCount = 0
    var answerCount = 0
    var lastAnswer: LexicalThemesModels.Answer.Response?

    func presentThemes(response: LexicalThemesModels.LoadThemes.Response) async {
        themesCount += 1
    }
    func presentThemeStart(response: LexicalThemesModels.StartTheme.Response) async {
        startCount += 1
    }
    func presentAnswer(response: LexicalThemesModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Helpers

@MainActor
private func makeWord(id: String = "w") -> LexicalWord {
    .init(id: id, text: "морковь", action: "растёт", attribute: "оранжевая")
}

@MainActor
private func makeRounds(count: Int) -> [LexicalRound] {
    (0..<count).map {
        LexicalRound(
            id: "r\($0)", kind: .naming,
            word: makeWord(id: "w\($0)"), themeId: "vegetables"
        )
    }
}

// MARK: - Interactor Tests

@MainActor
final class LexicalThemesInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [LexicalRound]
    ) -> (LexicalThemesInteractor, SpyLexicalPresenter, StubLexicalWorker) {
        let load = LexicalThemesModels.LoadThemes.Response(
            themes: LexicalThemesCorpus.themes,
            masteredThemeIds: []
        )
        let session = LexicalThemesModels.StartTheme.Response(
            theme: LexicalThemesCorpus.vegetables,
            rounds: rounds
        )
        let worker = StubLexicalWorker(loadResponse: load, sessionResponse: session)
        let haptic = SpyHapticService()
        let sut = LexicalThemesInteractor(
            childId: "child-1", worker: worker, hapticService: haptic
        )
        let spy = SpyLexicalPresenter()
        sut.presenter = spy
        return (sut, spy, worker)
    }

    func test_loadThemes_presents() async {
        let (sut, spy, worker) = makeSUT(rounds: makeRounds(count: 4))
        await sut.loadThemes(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.loadCount, 1)
        XCTAssertEqual(spy.themesCount, 1)
    }

    func test_startTheme_setsRounds() async {
        let (sut, spy, _) = makeSUT(rounds: makeRounds(count: 4))
        await sut.startTheme(request: .init(themeId: "vegetables"))
        XCTAssertEqual(sut.activeThemeId, "vegetables")
        XCTAssertEqual(sut.rounds.count, 4)
        XCTAssertEqual(spy.startCount, 1)
    }

    func test_answer_correct_incrementsAndAdvances() async {
        let (sut, spy, _) = makeSUT(rounds: makeRounds(count: 4))
        await sut.startTheme(request: .init(themeId: "vegetables"))
        // Индекс 0 — правильный.
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, true)
    }

    func test_answer_wrong_doesNotIncrement() async {
        let (sut, _, _) = makeSUT(rounds: makeRounds(count: 4))
        await sut.startTheme(request: .init(themeId: "vegetables"))
        await sut.answer(request: .init(optionIndex: 2))
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_answer_allCorrect_marksThemeMastered() async {
        let (sut, _, worker) = makeSUT(rounds: makeRounds(count: 4))
        await sut.startTheme(request: .init(themeId: "vegetables"))
        for _ in 0..<4 {
            await sut.answer(request: .init(optionIndex: 0))
        }
        XCTAssertEqual(worker.masteredThemeIds, ["vegetables"])
    }

    func test_answer_lowAccuracy_doesNotMarkMastered() async {
        let (sut, _, worker) = makeSUT(rounds: makeRounds(count: 4))
        await sut.startTheme(request: .init(themeId: "vegetables"))
        await sut.answer(request: .init(optionIndex: 0))
        for _ in 0..<3 {
            await sut.answer(request: .init(optionIndex: 1))
        }
        XCTAssertTrue(worker.masteredThemeIds.isEmpty)
    }
}

// MARK: - Corpus Tests

final class LexicalThemesCorpusTests: XCTestCase {

    func test_corpus_hasAtLeastTwelveThemes() {
        XCTAssertGreaterThanOrEqual(LexicalThemesCorpus.themes.count, 12)
    }

    func test_themeIdsAreUnique() {
        let ids = LexicalThemesCorpus.themes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_allWordIdsAreUnique() {
        let ids = LexicalThemesCorpus.allWords.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everyThemeHasWordsAndGeneralization() {
        for theme in LexicalThemesCorpus.themes {
            XCTAssertGreaterThanOrEqual(theme.words.count, 8)
            XCTAssertFalse(theme.generalization.isEmpty)
            for word in theme.words {
                XCTAssertFalse(word.action.isEmpty)
                XCTAssertFalse(word.attribute.isEmpty)
            }
        }
    }

    func test_corpus_hasOver100Words() {
        XCTAssertGreaterThanOrEqual(LexicalThemesCorpus.allWords.count, 100)
    }

    func test_wordsExcludingTheme_omitsThatTheme() {
        let words = LexicalThemesCorpus.words(excludingTheme: "vegetables")
        let veggieIds = Set(LexicalThemesCorpus.vegetables.words.map(\.id))
        XCTAssertTrue(words.allSatisfy { !veggieIds.contains($0.id) })
    }
}
