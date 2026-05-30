@testable import HappySpeech
import XCTest

// MARK: - SpeechTempoWorkerTests
//
// Фаза E, Волна 8. Покрывает buildSession: подбор чистоговорок под целевые звуки
// ребёнка (приоритет чистоговорок с целевым звуком в начале), верхняя граница
// rhymesPerSession, fallback при сбое профиля. Плюс чистая логика корпуса
// SpeechTempoCorpus.session (фильтрация по подстроке звука, prefix-cap) и
// модель TempoRhyme.syllableCount.

@MainActor
final class SpeechTempoWorkerTests: XCTestCase {

    private func child(id: String = "c-1", sounds: [String]) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 7, targetSounds: sounds, parentId: "p-1")
    }

    private func makeSUT(children: [ChildProfileDTO]) -> SpeechTempoWorker {
        SpeechTempoWorker(childRepository: MockChildRepository(children: children))
    }

    // MARK: - buildSession

    func test_buildSession_producesRhymes() async {
        let sut = makeSUT(children: [child(sounds: ["р"])])
        let response = await sut.buildSession(childId: "c-1")
        XCTAssertFalse(response.rhymes.isEmpty)
    }

    func test_buildSession_respectsSessionCap() async {
        let sut = makeSUT(children: [child(sounds: ["р"])])
        let response = await sut.buildSession(childId: "c-1")
        XCTAssertLessThanOrEqual(response.rhymes.count,
                                 SpeechTempoCorpus.rhymesPerSession)
    }

    func test_buildSession_rhymeIdsAreUnique() async {
        let sut = makeSUT(children: [child(sounds: ["р"])])
        let response = await sut.buildSession(childId: "c-1")
        let ids = response.rhymes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Чистоговорки в сессии не повторяются")
    }

    func test_buildSession_missingChild_stillProducesRhymes() async {
        // Сбой профиля → targetSounds = [] → случайная подборка.
        let sut = makeSUT(children: [])
        let response = await sut.buildSession(childId: "missing")
        XCTAssertFalse(response.rhymes.isEmpty)
    }

    // MARK: - SpeechTempoCorpus.session (pure)

    func test_corpus_session_emptyTargets_returnsCappedSelection() {
        let rhymes = SpeechTempoCorpus.session(for: [])
        XCTAssertLessThanOrEqual(rhymes.count, SpeechTempoCorpus.rhymesPerSession)
        XCTAssertFalse(rhymes.isEmpty)
    }

    func test_corpus_session_prioritisesRhymesContainingTargetSound() throws {
        // Берём звук, который точно встречается хотя бы в одной чистоговорке.
        let all = SpeechTempoCorpus.rhymes
        guard let withR = all.first(where: { $0.text.lowercased().contains("р") }) else {
            throw XCTSkip("В корпусе нет чистоговорки со звуком Р")
        }
        _ = withR
        let session = SpeechTempoCorpus.session(for: ["Р"])
        // Если в корпусе есть хоть одна предпочтительная чистоговорка, и она помещается
        // в сессию, первая позиция должна содержать целевой звук.
        let preferredCount = all.filter { $0.text.lowercased().contains("р") }.count
        if preferredCount > 0, !session.isEmpty {
            XCTAssertTrue(session.first!.text.lowercased().contains("р"),
                          "Чистоговорка с целевым звуком ставится в начало сессии")
        }
    }

    func test_corpus_session_unknownSound_stillReturnsRhymes() {
        // Звук, которого нет ни в одном тексте → preferred пуст → rest заполняет.
        let session = SpeechTempoCorpus.session(for: ["ъ"])
        XCTAssertFalse(session.isEmpty)
        XCTAssertLessThanOrEqual(session.count, SpeechTempoCorpus.rhymesPerSession)
    }

    func test_corpus_session_isCaseInsensitiveForTargetSound() {
        // Воркер нормализует к lowercase; верхний/нижний регистр дают тот же объём.
        let upper = SpeechTempoCorpus.session(for: ["Р"]).count
        let lower = SpeechTempoCorpus.session(for: ["р"]).count
        XCTAssertEqual(upper, lower)
    }

    // MARK: - TempoRhyme model

    func test_tempoRhyme_syllableCountMatchesArray() {
        let rhyme = TempoRhyme(id: "x", text: "Со-ро-ка", syllables: ["со", "ро", "ка"])
        XCTAssertEqual(rhyme.syllableCount, 3)
    }
}
