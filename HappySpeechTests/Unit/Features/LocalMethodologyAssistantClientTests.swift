@testable import HappySpeech
import XCTest

// MARK: - LocalMethodologyAssistantClientTests
//
// Локальный офлайн-ответчик по методическому корпусу. Тесты проверяют:
// успешный ответ с цитатами по релевантному запросу, дедупликацию источников,
// ошибку на пустом корпусе, валидацию длины вопроса, отсутствие совпадений.
// Используется in-memory корпус (без bundle) — детерминированно.

final class LocalMethodologyAssistantClientTests: XCTestCase {

    // MARK: - Fixtures

    private func chunk(
        _ id: String,
        source: String,
        section: String,
        text: String
    ) -> MethodologyChunk {
        let payload: [String: Any] = [
            "id": id, "source": source, "docTitle": "Документ",
            "section": section, "text": text
        ]
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: payload)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(MethodologyChunk.self, from: data)
    }

    private func corpus() -> [MethodologyChunk] {
        [
            chunk("c0", source: "therapy-stages.md", section: "Постановка звука Р",
                  text: "Звук Р ставится последним. Вызывайте вибрацию языка от быстрого Д-Д-Д "
                      + "после артикуляционной гимнастики и автоматизации Л."),
            chunk("c1", source: "therapy-stages.md", section: "Автоматизация",
                  text: "Автоматизация звука Р идёт по этапам: слог, слово по позициям, фраза, "
                      + "предложение, рассказ, свободная речь."),
            chunk("c2", source: "fatigue-and-session-rules.md", section: "Длительность",
                  text: "Занятие 10-15 минут для дошкольника, чтобы не было усталости.")
        ]
    }

    // MARK: - Success

    func test_ask_returnsAnswerWithCitationsForRelevantQuery() async throws {
        let client = LocalMethodologyAssistantClient(chunks: corpus())
        let answer = try await client.ask(question: "Как поставить звук Р вибрацией?")

        XCTAssertFalse(answer.answer.isEmpty)
        XCTAssertTrue(answer.answer.contains("вибрацию"),
                      "Ответ должен содержать текст из релевантного чанка")
        XCTAssertFalse(answer.citations.isEmpty)
        XCTAssertEqual(answer.citations.first?.source, "therapy-stages.md")
        XCTAssertNil(answer.sessionId, "Локальный ответчик не использует сессии")
    }

    func test_ask_deduplicatesCitationsBySource() async throws {
        // Запрос совпадает с c0 и c1 (оба therapy-stages.md) → источник один раз.
        let client = LocalMethodologyAssistantClient(chunks: corpus())
        let answer = try await client.ask(question: "звук Р постановка автоматизация этапы слог")

        let sources = answer.citations.map(\.source)
        XCTAssertEqual(Set(sources).count, sources.count, "Источники должны быть уникальны")
        XCTAssertTrue(sources.contains("therapy-stages.md"))
    }

    func test_ask_includesSectionHeadingsInAnswer() async throws {
        let client = LocalMethodologyAssistantClient(chunks: corpus())
        let answer = try await client.ask(question: "постановка звука Р вибрация языка")
        XCTAssertTrue(answer.answer.contains("Постановка звука Р"),
                      "Заголовок раздела попадает в markdown-ответ")
    }

    // MARK: - Errors

    func test_ask_emptyCorpus_throwsCorpusUnavailable() async {
        let client = LocalMethodologyAssistantClient(chunks: [])
        do {
            _ = try await client.ask(question: "Как поставить звук Р?")
            XCTFail("Ожидалась ошибка на пустом корпусе")
        } catch let error as LocalMethodologyAssistantClient.LocalError {
            XCTAssertEqual(error, .corpusUnavailable)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }

    func test_ask_tooShort_throwsInvalidQuestion() async {
        let client = LocalMethodologyAssistantClient(chunks: corpus())
        do {
            _ = try await client.ask(question: "Р")
            XCTFail("Ожидалась ошибка валидации")
        } catch let error as LocalMethodologyAssistantClient.LocalError {
            guard case .invalidQuestion = error else {
                return XCTFail("Ожидалась .invalidQuestion, получено \(error)")
            }
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }

    func test_ask_noMatch_throwsNoRelevantContent() async {
        let client = LocalMethodologyAssistantClient(chunks: corpus())
        do {
            _ = try await client.ask(question: "квантовая хромодинамика синхрофазотрон бозон")
            XCTFail("Ожидалась ошибка отсутствия совпадений")
        } catch let error as LocalMethodologyAssistantClient.LocalError {
            XCTAssertEqual(error, .noRelevantContent)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }

    // MARK: - Region

    func test_region_isLocal() {
        let client = LocalMethodologyAssistantClient(chunks: corpus())
        XCTAssertEqual(client.region, "local")
    }
}
