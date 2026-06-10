@testable import HappySpeech
import XCTest

// MARK: - MethodologyRetrieverTests
//
// Локальный BM25-поиск по методическому корпусу. Тесты проверяют: токенизацию,
// что релевантный по смыслу запрос находит правильный чанк, ранжирование,
// отсутствие совпадений, поведение на пустом корпусе.

final class MethodologyRetrieverTests: XCTestCase {

    // MARK: - Fixtures

    private func chunk(
        _ id: String,
        source: String,
        section: String,
        text: String
    ) -> MethodologyChunk {
        // MethodologyChunk — Decodable; собираем через JSON, чтобы не требовать
        // публичного инициализатора.
        let payload: [String: Any] = [
            "id": id, "source": source, "docTitle": "Документ",
            "section": section, "text": text
        ]
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: payload)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(MethodologyChunk.self, from: data)
    }

    private func sampleCorpus() -> [MethodologyChunk] {
        [
            chunk("c0", source: "therapy-stages.md", section: "Этап постановки звука Р",
                  text: "Звук Р ставится последним, после Л. Начните с артикуляционной гимнастики, "
                      + "затем вызывайте вибрацию языка от быстрого Д-Д-Д. Постановка идёт по этапам."),
            chunk("c1", source: "sound-groups-taxonomy.md", section: "Свистящие звуки",
                  text: "Свистящие звуки С, З, Ц требуют точной воздушной струи по центру языка. "
                      + "Кончик языка у нижних зубов, спинка выгнута."),
            chunk("c2", source: "fatigue-and-session-rules.md", section: "Длительность сессии",
                  text: "Сессия для ребёнка 5-8 лет должна быть короткой: не более 10-15 минут, "
                      + "чтобы избежать усталости и сохранить мотивацию и внимание."),
            chunk("c3", source: "parent-guidance-full.md", section: "Поддержка родителя",
                  text: "Родителю важно хвалить ребёнка за старание, а не только за результат. "
                      + "Создавайте спокойную игровую атмосферу дома.")
        ]
    }

    // MARK: - Tokenizer

    func test_tokenize_lowercasesAndDropsStopwordsAndShortTokens() {
        let tokens = MethodologyRetriever.tokenize("Как поставить звук Р у ребёнка?")
        XCTAssertTrue(tokens.contains("поставить"))
        XCTAssertTrue(tokens.contains("звук"))
        XCTAssertTrue(tokens.contains("ребёнка"))
        XCTAssertFalse(tokens.contains("как"), "стоп-слово как должно отфильтроваться")
        XCTAssertFalse(tokens.contains("у"), "односимвольный токен должен отфильтроваться")
        XCTAssertFalse(tokens.contains("р"), "односимвольный токен должен отфильтроваться")
    }

    // MARK: - Relevance

    func test_search_findsMostRelevantChunkForKnownQuery() {
        let retriever = MethodologyRetriever(chunks: sampleCorpus())
        let hits = retriever.search("Как поставить звук Р вибрацией языка?", limit: 3)

        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(hits.first?.chunk.id, "c0",
                       "Запрос про постановку Р должен вернуть чанк постановки Р первым")
        XCTAssertEqual(hits.first?.chunk.source, "therapy-stages.md")
    }

    func test_search_fatigueQueryReturnsSessionRulesChunk() {
        let retriever = MethodologyRetriever(chunks: sampleCorpus())
        let hits = retriever.search("Сколько минут длится занятие, чтобы ребёнок не устал?", limit: 2)

        XCTAssertEqual(hits.first?.chunk.id, "c2",
                       "Запрос про длительность и усталость → чанк правил сессии")
    }

    func test_search_rankingScoresDescending() {
        let retriever = MethodologyRetriever(chunks: sampleCorpus())
        let hits = retriever.search("свистящие звуки С З Ц язык струя", limit: 4)
        XCTAssertEqual(hits.first?.chunk.id, "c1")
        for i in 1..<hits.count {
            XCTAssertGreaterThanOrEqual(hits[i - 1].score, hits[i].score,
                                        "Оценки должны убывать")
        }
    }

    func test_search_noMatchReturnsEmpty() {
        let retriever = MethodologyRetriever(chunks: sampleCorpus())
        let hits = retriever.search("квантовая хромодинамика синхрофазотрон", limit: 4)
        XCTAssertTrue(hits.isEmpty, "Не связанный с корпусом запрос → нет совпадений")
    }

    func test_search_emptyCorpusReturnsEmpty() {
        let retriever = MethodologyRetriever(chunks: [])
        XCTAssertTrue(retriever.search("звук Р", limit: 4).isEmpty)
    }

    func test_search_respectsLimit() {
        let retriever = MethodologyRetriever(chunks: sampleCorpus())
        let hits = retriever.search("звук язык ребёнок", limit: 2)
        XCTAssertLessThanOrEqual(hits.count, 2)
    }
}
