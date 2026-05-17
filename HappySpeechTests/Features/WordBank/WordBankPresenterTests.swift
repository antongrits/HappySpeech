@testable import HappySpeech
import XCTest

// MARK: - Display Spy

@MainActor
private final class WBDisplaySpy: WordBankDisplayLogic {
    var loadVM: WordBankModels.Load.ViewModel?
    var filterVM: WordBankModels.Filter.ViewModel?
    var selectVM: WordBankModels.SelectWord.ViewModel?
    var practiceRequest: WordBankModels.Practice.Request?

    func displayLoad(viewModel: WordBankModels.Load.ViewModel) async { loadVM = viewModel }
    func displayFilter(viewModel: WordBankModels.Filter.ViewModel) async { filterVM = viewModel }
    func displaySelectWord(viewModel: WordBankModels.SelectWord.ViewModel) async { selectVM = viewModel }
    func displayPractice(request: WordBankModels.Practice.Request) async { practiceRequest = request }
}

// MARK: - Builders

private func wbpStat(
    word: String,
    sound: String,
    score: Double,
    attempts: Int = 3,
    last: Date = Date()
) -> BankWordStat {
    BankWordStat(
        id: word + "_" + sound,
        word: word,
        targetSound: sound,
        avgScore: score,
        attemptCount: attempts,
        lastPracticedAt: last,
        isCorrectCount: 2
    )
}

// MARK: - Tests

@MainActor
final class WordBankPresenterTests: XCTestCase {

    private func makeSUT() -> (WordBankPresenter, WBDisplaySpy) {
        let spy = WBDisplaySpy()
        let presenter = WordBankPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    // MARK: starRating

    func test_starRating_oneStar_belowSixty() {
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 0.5), 1)
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 0.0), 1)
    }

    func test_starRating_twoStars_belowEighty() {
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 0.6), 2)
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 0.75), 2)
    }

    func test_starRating_threeStars_eightyAndAbove() {
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 0.8), 3)
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 0.85), 3)
        XCTAssertEqual(WordBankPresenter.starRating(avgScore: 1.0), 3)
    }

    func test_tileTint_matchesStarRating() {
        XCTAssertEqual(WordBankPresenter.tileTint(for: 3), .gold)
        XCTAssertEqual(WordBankPresenter.tileTint(for: 2), .mint)
        XCTAssertEqual(WordBankPresenter.tileTint(for: 1), .neutral)
    }

    // MARK: lastPracticedText

    func test_lastPracticedText_today() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let text = WordBankPresenter.lastPracticedText(from: now, now: now)
        XCTAssertEqual(text, String(localized: "wordBank.lastPracticed.today"))
    }

    func test_lastPracticedText_yesterday() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = now.addingTimeInterval(-86_400)
        let text = WordBankPresenter.lastPracticedText(from: yesterday, now: now)
        XCTAssertEqual(text, String(localized: "wordBank.lastPracticed.yesterday"))
    }

    func test_lastPracticedText_fiveDaysAgo() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiveDaysAgo = now.addingTimeInterval(-5 * 86_400)
        let text = WordBankPresenter.lastPracticedText(from: fiveDaysAgo, now: now)
        XCTAssertTrue(text.contains("5"))
    }

    // MARK: buildTiles

    func test_buildTiles_sortsThreeStarsFirst() {
        let stats = [
            wbpStat(word: "шуба", sound: "Ш", score: 0.5),   // 1 звезда
            wbpStat(word: "шапка", sound: "Ш", score: 0.9),  // 3 звезды
            wbpStat(word: "школа", sound: "Ш", score: 0.7)   // 2 звезды
        ]
        let tiles = WordBankPresenter.buildTiles(from: stats)
        XCTAssertEqual(tiles.first?.starRating, 3)
        XCTAssertEqual(tiles.last?.starRating, 1)
    }

    func test_buildTiles_sameStars_sortedAlphabetically() {
        let stats = [
            wbpStat(word: "яблоко", sound: "Я", score: 0.9),
            wbpStat(word: "арбуз", sound: "А", score: 0.9)
        ]
        let tiles = WordBankPresenter.buildTiles(from: stats)
        XCTAssertEqual(tiles.first?.word, "арбуз")
    }

    func test_buildTiles_emptyInput_emptyOutput() {
        XCTAssertTrue(WordBankPresenter.buildTiles(from: []).isEmpty)
    }

    func test_buildTiles_assignsTint() {
        let tiles = WordBankPresenter.buildTiles(from: [wbpStat(word: "шапка", sound: "Ш", score: 0.9)])
        XCTAssertEqual(tiles.first?.tileTint, .gold)
    }

    // MARK: soundFilters

    func test_soundFilters_uniqueSorted() {
        let stats = [
            wbpStat(word: "шапка", sound: "Ш", score: 0.9),
            wbpStat(word: "шуба", sound: "Ш", score: 0.6),
            wbpStat(word: "роза", sound: "Р", score: 0.7)
        ]
        let filters = WordBankPresenter.soundFilters(from: stats)
        XCTAssertEqual(filters, ["Р", "Ш"])
    }

    func test_soundFilters_emptyInput() {
        XCTAssertTrue(WordBankPresenter.soundFilters(from: []).isEmpty)
    }

    // MARK: presentLoad

    func test_presentLoad_buildsViewModel() async {
        let (sut, spy) = makeSUT()
        let stats = [
            wbpStat(word: "шапка", sound: "Ш", score: 0.9),
            wbpStat(word: "роза", sound: "Р", score: 0.7)
        ]
        await sut.presentLoad(response: .init(wordStats: stats))
        XCTAssertEqual(spy.loadVM?.totalCount, 2)
        XCTAssertEqual(spy.loadVM?.counterText, "2")
        XCTAssertEqual(spy.loadVM?.tiles.count, 2)
        XCTAssertEqual(spy.loadVM?.isEmpty, false)
    }

    func test_presentLoad_emptyStats_isEmptyTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(wordStats: []))
        XCTAssertEqual(spy.loadVM?.isEmpty, true)
        XCTAssertEqual(spy.loadVM?.counterText, "0")
    }

    func test_presentLoad_includesSoundFilters() async {
        let (sut, spy) = makeSUT()
        let stats = [
            wbpStat(word: "шапка", sound: "Ш", score: 0.9),
            wbpStat(word: "роза", sound: "Р", score: 0.7)
        ]
        await sut.presentLoad(response: .init(wordStats: stats))
        XCTAssertEqual(spy.loadVM?.soundFilters, ["Р", "Ш"])
    }

    // MARK: presentFilter

    func test_presentFilter_buildsTiles() async {
        let (sut, spy) = makeSUT()
        let filtered = [wbpStat(word: "шапка", sound: "Ш", score: 0.9)]
        await sut.presentFilter(response: .init(filtered: filtered))
        XCTAssertEqual(spy.filterVM?.tiles.count, 1)
    }

    // MARK: presentSelectWord

    func test_presentSelectWord_buildsDetailViewModel() async {
        let (sut, spy) = makeSUT()
        let stat = wbpStat(word: "шапка", sound: "Ш", score: 0.9, attempts: 4)
        await sut.presentSelectWord(response: .init(stat: stat))
        XCTAssertEqual(spy.selectVM?.word, "шапка")
        XCTAssertEqual(spy.selectVM?.starRating, 3)
        XCTAssertEqual(spy.selectVM?.targetSound, "Ш")
        XCTAssertFalse(spy.selectVM?.attemptCountText.isEmpty ?? true)
        XCTAssertFalse(spy.selectVM?.lastPracticedText.isEmpty ?? true)
    }

    // MARK: presentPractice

    func test_presentPractice_propagatesRequest() async {
        let (sut, spy) = makeSUT()
        await sut.presentPractice(request: .init(word: "роза", targetSound: "Р"))
        XCTAssertEqual(spy.practiceRequest?.word, "роза")
        XCTAssertEqual(spy.practiceRequest?.targetSound, "Р")
    }
}
