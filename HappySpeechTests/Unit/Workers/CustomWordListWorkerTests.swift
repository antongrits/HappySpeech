@testable import HappySpeech
import XCTest

// MARK: - CustomWordListWorkerTests
//
// Фаза E, Волна 7. Покрывает чистую логику генерации упражнений из draft
// (generateExercises): тримминг/фильтрация слов, пороги шаблонов bingo/memory,
// обрезка до лимитов. CRUD-методы (fetchAll/save/delete) — тонкие проброски в
// RealmActor (hardware side), здесь не покрываются. SUT создаётся с реальным
// RealmActor(), но эти методы в тестах не вызываются — generateExercises pure.

@MainActor
final class CustomWordListWorkerTests: XCTestCase {

    private func makeSUT() -> LiveCustomWordListWorker {
        LiveCustomWordListWorker(realmActor: RealmActor())
    }

    private func draft(words: [String], sound: String = "Р", id: String = "draft-1") -> WordListDraft {
        WordListDraft(id: id, name: "Список", targetSound: sound, words: words)
    }

    // MARK: - Empty / whitespace handling

    func test_generateExercises_emptyWords_returnsEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.generateExercises(from: draft(words: [])).isEmpty)
    }

    func test_generateExercises_onlyWhitespaceWords_returnsEmpty() {
        let sut = makeSUT()
        let result = sut.generateExercises(from: draft(words: ["  ", "\n", "\t"]))
        XCTAssertTrue(result.isEmpty, "Слова из одних пробелов отфильтровываются")
    }

    func test_generateExercises_trimsWhitespaceFromWords() {
        let sut = makeSUT()
        let result = sut.generateExercises(from: draft(words: ["  рыба  ", "роза\n"]))
        let rep = result.first { $0.kind == .repeatAfterModel }
        XCTAssertEqual(rep?.words, ["рыба", "роза"])
    }

    // MARK: - repeat-after-model: всегда базовое

    func test_generateExercises_singleWord_onlyRepeatAfterModel() {
        let sut = makeSUT()
        let result = sut.generateExercises(from: draft(words: ["рак"]))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .repeatAfterModel)
        XCTAssertEqual(result.first?.id, "draft-1-rep")
        XCTAssertEqual(result.first?.targetSound, "Р")
    }

    func test_generateExercises_threeWords_stillOnlyRepeat() {
        let sut = makeSUT()
        // bingo/memory требуют ≥4 слов.
        let result = sut.generateExercises(from: draft(words: ["рак", "роза", "рыба"]))
        XCTAssertEqual(result.map(\.kind), [.repeatAfterModel])
    }

    // MARK: - bingo / memory thresholds (≥4 слов)

    func test_generateExercises_fourWords_addsBingoAndMemory() {
        let sut = makeSUT()
        let result = sut.generateExercises(from: draft(words: ["рак", "роза", "рыба", "ручка"]))
        let kinds = Set(result.map(\.kind))
        XCTAssertEqual(kinds, [.repeatAfterModel, .bingo, .memory])
        XCTAssertEqual(result.count, 3)
    }

    func test_generateExercises_bingoCappedAtNineWords() {
        let sut = makeSUT()
        let words = (1...12).map { "слово\($0)" }
        let result = sut.generateExercises(from: draft(words: words))
        let bingo = result.first { $0.kind == .bingo }
        XCTAssertEqual(bingo?.words.count, 9, "bingo обрезается до 9 слов")
    }

    func test_generateExercises_memoryCappedAtEightWords() {
        let sut = makeSUT()
        let words = (1...12).map { "слово\($0)" }
        let result = sut.generateExercises(from: draft(words: words))
        let memory = result.first { $0.kind == .memory }
        XCTAssertEqual(memory?.words.count, 8, "memory обрезается до 8 слов")
    }

    func test_generateExercises_repeatKeepsAllWords() {
        let sut = makeSUT()
        let words = (1...12).map { "слово\($0)" }
        let result = sut.generateExercises(from: draft(words: words))
        let rep = result.first { $0.kind == .repeatAfterModel }
        XCTAssertEqual(rep?.words.count, 12, "repeat-after-model сохраняет все слова")
    }

    func test_generateExercises_idsAreDerivedFromDraftId() {
        let sut = makeSUT()
        let words = ["рак", "роза", "рыба", "ручка"]
        let result = sut.generateExercises(from: draft(words: words, id: "abc"))
        XCTAssertTrue(result.contains { $0.id == "abc-rep" })
        XCTAssertTrue(result.contains { $0.id == "abc-bingo" })
        XCTAssertTrue(result.contains { $0.id == "abc-mem" })
    }

    func test_generateExercises_propagatesTargetSoundToAllExercises() {
        let sut = makeSUT()
        let words = ["шар", "шуба", "шапка", "шкаф"]
        let result = sut.generateExercises(from: draft(words: words, sound: "Ш"))
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.targetSound == "Ш" })
    }

    // MARK: - WordListDraft.toData transformation (pure model logic)

    func test_draftToData_trimsNameAndFiltersEmptyWords() {
        let d = WordListDraft(id: "d", name: "  Звук Р  ", targetSound: "Р",
                              words: ["рак ", " ", "роза"])
        let now = Date(timeIntervalSince1970: 1000)
        let data = d.toData(specialistId: "spec-1", createdAt: Date(timeIntervalSince1970: 1), now: now)
        XCTAssertEqual(data.name, "Звук Р")
        XCTAssertEqual(data.words, ["рак", "роза"])
        XCTAssertEqual(data.specialistId, "spec-1")
        XCTAssertEqual(data.updatedAt, now)
    }

    func test_draftFromData_roundTrips() {
        let data = CustomWordListData(id: "d", specialistId: "s", name: "Имя",
                                      targetSound: "Л", words: ["лук", "луна"],
                                      createdAt: Date(), updatedAt: Date())
        let d = WordListDraft.from(data)
        XCTAssertEqual(d.id, "d")
        XCTAssertEqual(d.targetSound, "Л")
        XCTAssertEqual(d.words, ["лук", "луна"])
    }
}
