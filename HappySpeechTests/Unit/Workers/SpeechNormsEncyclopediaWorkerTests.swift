@testable import HappySpeech
import XCTest

// MARK: - SpeechNormsEncyclopediaWorkerTests
//
// Фаза E, Волна 8. Worker стейтлесс (loadCards отдаёт корпус) — покрываем
// непустоту и совпадение с корпусом. Основная реальная логика модуля — в
// SpeechNormsEncyclopediaCorpus: фильтр по возрасту cards(for:), регистро-
// независимый поиск filter(by:) по title/summary/body, обработка пустого
// запроса (возврат исходного набора). Их и покрываем содержательно.

@MainActor
final class SpeechNormsEncyclopediaWorkerTests: XCTestCase {

    private func makeSUT() -> SpeechNormsEncyclopediaWorker {
        SpeechNormsEncyclopediaWorker()
    }

    // MARK: - loadCards

    func test_loadCards_returnsNonEmptyCorpus() async {
        let sut = makeSUT()
        let cards = await sut.loadCards()
        XCTAssertFalse(cards.isEmpty, "Корпус карточек (пак или fallback) не пуст")
    }

    func test_loadCards_matchesCorpus() async {
        let sut = makeSUT()
        let cards = await sut.loadCards()
        XCTAssertEqual(cards.map(\.id), SpeechNormsEncyclopediaCorpus.cards.map(\.id))
    }

    func test_loadCards_idsAreUnique() async {
        let sut = makeSUT()
        let ids = await sut.loadCards().map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // MARK: - Corpus.cards(for:) — age filter

    func test_corpus_cardsForAge_allMatchRequestedAge() {
        for age in NormAge.allCases {
            let cards = SpeechNormsEncyclopediaCorpus.cards(for: age)
            XCTAssertTrue(cards.allSatisfy { $0.age == age },
                          "Все карточки для возраста \(age.rawValue) имеют этот возраст")
        }
    }

    func test_corpus_cardsForAge_unionEqualsSubsetOfFullCorpus() {
        let total = NormAge.allCases
            .map { SpeechNormsEncyclopediaCorpus.cards(for: $0).count }
            .reduce(0, +)
        // Каждая карточка имеет ровно один возраст → сумма по возрастам ≤ всего карточек.
        XCTAssertLessThanOrEqual(total, SpeechNormsEncyclopediaCorpus.cards.count)
    }

    // MARK: - Corpus.filter(by:in:) — search

    func test_corpus_filter_emptyQueryReturnsAllInput() {
        let input = SpeechNormsEncyclopediaCorpus.cards
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "", in: input)
        XCTAssertEqual(result.count, input.count)
    }

    func test_corpus_filter_whitespaceQueryReturnsAllInput() {
        let input = SpeechNormsEncyclopediaCorpus.cards
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "   \n", in: input)
        XCTAssertEqual(result.count, input.count, "Пустой после тримминга запрос → весь набор")
    }

    func test_corpus_filter_matchesTitleCaseInsensitively() {
        let card = NormCard(id: "t1", age: .five, axis: .sounds,
                            title: "Звук Р", summary: "x", body: "y", sources: [])
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "звук", in: [card])
        XCTAssertEqual(result.map(\.id), ["t1"])
    }

    func test_corpus_filter_matchesBodySubstring() {
        let card = NormCard(id: "b1", age: .six, axis: .grammar,
                            title: "T", summary: "S", body: "дисграфия в письме", sources: [])
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "дисграфия", in: [card])
        XCTAssertEqual(result.map(\.id), ["b1"])
    }

    func test_corpus_filter_matchesSummarySubstring() {
        let card = NormCard(id: "s1", age: .seven, axis: .vocabulary,
                            title: "T", summary: "богатый словарь", body: "B", sources: [])
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "словарь", in: [card])
        XCTAssertEqual(result.map(\.id), ["s1"])
    }

    func test_corpus_filter_noMatchReturnsEmpty() {
        let card = NormCard(id: "n1", age: .eight, axis: .motor,
                            title: "Письмо", summary: "S", body: "B", sources: [])
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "квантовая физика", in: [card])
        XCTAssertTrue(result.isEmpty)
    }

    func test_corpus_filter_trimsQueryBeforeMatching() {
        let card = NormCard(id: "tr1", age: .five, axis: .sounds,
                            title: "Свистящие", summary: "S", body: "B", sources: [])
        let result = SpeechNormsEncyclopediaCorpus.filter(by: "  свистящие  ", in: [card])
        XCTAssertEqual(result.map(\.id), ["tr1"], "Запрос тримится перед сравнением")
    }

    // MARK: - ethicsNote

    func test_corpus_ethicsNote_isNonEmpty() {
        XCTAssertFalse(SpeechNormsEncyclopediaCorpus.ethicsNote.isEmpty)
    }
}
