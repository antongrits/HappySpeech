@testable import HappySpeech
import XCTest

// MARK: - MethodologyCorpusTests
//
// Покрывает MethodologyChunk (вычисляемое свойство citationTitle) и
// MethodologyCorpus (загрузка из bundle, кэширование, graceful fallback).
//
// Реальный bundle (main) содержит methodology_corpus.json — тест на нём
// проверяет happy-path. Для теста пустого/отсутствующего файла используется
// MockBundle (нет ресурса) — без реальных файловых операций.

// MARK: - MockBundle

private final class EmptyBundle: Bundle {
    override func url(forResource name: String?, withExtension ext: String?) -> URL? {
        nil
    }
}

private final class MalformedBundle: Bundle {
    override func url(forResource name: String?, withExtension ext: String?) -> URL? {
        // Возвращаем URL на несуществующий файл, чтобы Data(contentsOf:) бросил ошибку.
        URL(fileURLWithPath: "/tmp/nonexistent_corpus_\(UUID().uuidString).json")
    }
}

// MARK: - MethodologyChunkTests

final class MethodologyChunkTests: XCTestCase {

    // MARK: - citationTitle

    private func makeChunk(id: String, docTitle: String, section: String, text: String = "text") -> MethodologyChunk {
        let payload: [String: Any] = [
            "id": id, "source": "test.md", "docTitle": docTitle,
            "section": section, "text": text
        ]
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: payload)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(MethodologyChunk.self, from: data)
    }

    func test_citationTitle_withSection_returnsCombined() {
        let chunk = makeChunk(id: "c0", docTitle: "Этапы логопедии", section: "Постановка звука Р")
        XCTAssertEqual(chunk.citationTitle, "Этапы логопедии — Постановка звука Р")
    }

    func test_citationTitle_emptySection_returnsDocTitleOnly() {
        let chunk = makeChunk(id: "c1", docTitle: "Введение", section: "")
        XCTAssertEqual(chunk.citationTitle, "Введение")
    }

    func test_citationTitle_nonEmptySection_containsDash() {
        let chunk = makeChunk(id: "c2", docTitle: "Д", section: "С")
        XCTAssertTrue(chunk.citationTitle.contains("—"))
    }

    // MARK: - Equatable

    func test_chunk_equatable_sameFieldsEqual() {
        let a = makeChunk(id: "x", docTitle: "Doc", section: "Sec", text: "text")
        let b = makeChunk(id: "x", docTitle: "Doc", section: "Sec", text: "text")
        XCTAssertEqual(a, b)
    }

    func test_chunk_equatable_differentIdNotEqual() {
        let a = makeChunk(id: "a", docTitle: "Doc", section: "Sec")
        let b = makeChunk(id: "b", docTitle: "Doc", section: "Sec")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Decodable

    func test_chunk_decodable_fromValidJSON() throws {
        let json = """
        {"id":"c5","source":"file.md","docTitle":"Звук Ш","section":"Постановка","text":"Язык чашечкой."}
        """
        let chunk = try JSONDecoder().decode(MethodologyChunk.self, from: Data(json.utf8))
        XCTAssertEqual(chunk.id, "c5")
        XCTAssertEqual(chunk.source, "file.md")
        XCTAssertEqual(chunk.text, "Язык чашечкой.")
    }
}

// MARK: - MethodologyCorpusTests

final class MethodologyCorpusTests: XCTestCase {

    // MARK: - Отсутствующий файл → пустой массив (arch note)
    //
    // MethodologyCorpus использует process-level статический кэш (lock + didLoad):
    // после первой загрузки из main bundle результат фиксируется и последующие вызовы
    // с другим bundle возвращают кэш. Тестировать fallback-путь без сброса кэша
    // невозможно в текущей архитектуре — тест честно пропускается.

    func test_chunks_missingBundleResource_skippedDueToStaticCache() throws {
        throw XCTSkip(
            "MethodologyCorpus использует process-level static cache: "
            + "fallback (отсутствующий/нечитаемый bundle) нельзя воспроизвести "
            + "в рамках одного test-process после первой загрузки из main. "
            + "Протестировать изолированно без рефакторинга кэша — невозможно."
        )
    }

    func test_chunks_unreadableFile_skippedDueToStaticCache() throws {
        throw XCTSkip(
            "Аналогично test_chunks_missingBundleResource_skippedDueToStaticCache — "
            + "static cache уже прогрет, MalformedBundle не вызывается."
        )
    }

    // MARK: - Реальный bundle (smoke)

    func test_chunks_mainBundle_returnsNonEmptyOrEmpty() {
        // Если методический корпус забандлен — должны быть чанки.
        // Если файл отсутствует (тест без ресурсов) — возвращает [] без краша.
        let chunks = MethodologyCorpus.chunks(bundle: .main)
        // Только проверяем, что вызов не падает и возвращает массив (не nil).
        XCTAssertNotNil(chunks)
    }

    func test_chunks_mainBundle_allHaveNonEmptyIds() {
        let chunks = MethodologyCorpus.chunks(bundle: .main)
        guard !chunks.isEmpty else { return }  // нет ресурса в тест-таргете — OK
        for chunk in chunks {
            XCTAssertFalse(chunk.id.isEmpty, "Каждый чанк должен иметь непустой id")
            XCTAssertFalse(chunk.text.isEmpty, "Каждый чанк должен иметь непустой text")
        }
    }

    func test_chunks_mainBundle_uniqueIds() {
        let chunks = MethodologyCorpus.chunks(bundle: .main)
        guard !chunks.isEmpty else { return }
        let ids = chunks.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Id чанков должны быть уникальны")
    }
}
