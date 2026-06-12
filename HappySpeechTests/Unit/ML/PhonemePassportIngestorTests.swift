@testable import HappySpeech
import XCTest

// MARK: - PhonemePassportIngestorTests
//
// Покрывает фоновый ингестор «Фонемного паспорта» (v17): запуск пайплайна
// G2P → logits → forced alignment → GOP → классификация → record, а также
// гейтинг по RAM и tier (пустой childId). Использует управляемый mock Wav2Vec2,
// возвращающий заданную матрицу логитов, и mock-репозиторий наблюдений.

final class PhonemePassportIngestorTests: XCTestCase {

    private let vocabSize = Wav2Vec2Vocabulary.size
    private let blankId = Wav2Vec2Vocabulary.blankIndex
    private let highMemory: UInt64 = 6 * 1024 * 1024 * 1024
    private let lowMemory: UInt64 = 2 * 1024 * 1024 * 1024

    // MARK: - Logits builder

    /// Строит матрицу логитов T×C, где каждый элемент `segments` задаёт класс
    /// (кириллица словаря), доминирующий в своём спане кадров. Между сегментами —
    /// blank-кадр. Так можно смоделировать как корректное произнесение (класс =
    /// эталон), так и замену (класс = конкурент).
    private func logits(segments: [(letter: String, frames: Int)]) -> [[Float]] {
        let high: Float = 6.0
        let low: Float = -2.0
        func row(dominant: Int) -> [Float] {
            var values = [Float](repeating: low, count: vocabSize)
            values[dominant] = high
            return values
        }
        var matrix: [[Float]] = [row(dominant: blankId)]
        for segment in segments {
            let classId = Wav2Vec2Vocabulary.index(of: segment.letter) ?? blankId
            for _ in 0..<segment.frames { matrix.append(row(dominant: classId)) }
            matrix.append(row(dominant: blankId))
        }
        return matrix
    }

    private func makeIngestor(
        logits matrix: [[Float]],
        repository: MockPhonemeObservationRepository,
        memory: UInt64
    ) -> LivePhonemePassportIngestor {
        let wav2Vec2 = Wav2Vec2ServiceMock(text: "", logits: matrix)
        let profile = LivePhonemeProfileService(repository: repository)
        return LivePhonemePassportIngestor(
            wav2Vec2: wav2Vec2,
            profileService: profile,
            minPhysicalMemoryBytes: 4 * 1024 * 1024 * 1024,
            physicalMemoryBytes: { memory }
        )
    }

    // MARK: - Happy path: корректное произнесение записывается

    func test_ingest_recordsTargetPhonemes_onCorrectPronunciation() async throws {
        // Слово «рак»: G2P → [r, a, k]. Целевые: р (соноры), к (заднеязычные).
        let matrix = logits(segments: [
            ("р", 5), ("а", 5), ("к", 5)
        ])
        let repository = MockPhonemeObservationRepository()
        let ingestor = makeIngestor(logits: matrix, repository: repository, memory: highMemory)

        let count = await ingestor.ingest(
            audio: Data(count: 64),
            word: "рак",
            childId: "child-1",
            wordId: "word_rak"
        )

        XCTAssertGreaterThan(count, 0, "Должно записаться хотя бы одно целевое наблюдение")
        let observations = repository.observations
        XCTAssertTrue(observations.contains { $0.phoneme == "r" }, "Фонема 'r' должна попасть в паспорт")
        XCTAssertTrue(observations.allSatisfy { $0.childId == "child-1" })
        XCTAssertTrue(observations.allSatisfy { $0.wordId == "word_rak" })
        // Гласная 'a' и прочие нецелевые группы НЕ записываются.
        XCTAssertFalse(observations.contains { $0.phoneme == "a" }, "Гласные в паспорт не пишутся")
    }

    // MARK: - Замена Р→Л фиксируется как age_substitution с конкурентом

    func test_ingest_recordsSubstitution_whenRProducedAsL() async throws {
        // Эталон «рак», но спан фонемы 'р' акустически доминируется классом 'л'.
        let matrix = logits(segments: [
            ("л", 5), ("а", 5), ("к", 5)
        ])
        let repository = MockPhonemeObservationRepository()
        let ingestor = makeIngestor(logits: matrix, repository: repository, memory: highMemory)

        let count = await ingestor.ingest(
            audio: Data(count: 64),
            word: "рак",
            childId: "child-2",
            wordId: "word_rak"
        )

        XCTAssertGreaterThan(count, 0)
        let rObservation = repository.observations.first { $0.phoneme == "r" }
        let observation = try XCTUnwrap(rObservation, "Наблюдение по 'r' должно существовать")
        // Р→Л — закономерная возрастная замена (ламбдацизм).
        XCTAssertEqual(observation.defect, "age_substitution", "Р→Л — возрастная замена")
        XCTAssertEqual(observation.competitor, "l", "Конкурент-замена для 'r' — 'l'")
    }

    // MARK: - RAM-gate: при недостаточной памяти ничего не пишется

    func test_ingest_skips_whenInsufficientMemory() async {
        let matrix = logits(segments: [("р", 5), ("а", 5), ("к", 5)])
        let repository = MockPhonemeObservationRepository()
        let ingestor = makeIngestor(logits: matrix, repository: repository, memory: lowMemory)

        let count = await ingestor.ingest(
            audio: Data(count: 64),
            word: "рак",
            childId: "child-3",
            wordId: "word_rak"
        )

        XCTAssertEqual(count, 0, "RAM ниже порога → ingest пропущен")
        XCTAssertTrue(repository.observations.isEmpty, "Ни одно наблюдение не должно быть записано")
    }

    // MARK: - Tier-gate: пустой childId → пропуск

    func test_ingest_skips_whenChildIdEmpty() async {
        let matrix = logits(segments: [("р", 5), ("а", 5), ("к", 5)])
        let repository = MockPhonemeObservationRepository()
        let ingestor = makeIngestor(logits: matrix, repository: repository, memory: highMemory)

        let count = await ingestor.ingest(
            audio: Data(count: 64),
            word: "рак",
            childId: "",
            wordId: "word_rak"
        )

        XCTAssertEqual(count, 0, "Пустой childId → ingest пропущен (нет владельца наблюдений)")
        XCTAssertTrue(repository.observations.isEmpty)
    }

    // MARK: - Пустое/нефонемное слово → graceful no-op

    func test_ingest_skips_whenWordHasNoTargetPhonemes() async {
        // Слово только из гласной — нет целевых согласных групп.
        let matrix = logits(segments: [("а", 5)])
        let repository = MockPhonemeObservationRepository()
        let ingestor = makeIngestor(logits: matrix, repository: repository, memory: highMemory)

        let count = await ingestor.ingest(
            audio: Data(count: 64),
            word: "а",
            childId: "child-4",
            wordId: "word_a"
        )

        XCTAssertEqual(count, 0, "Нет целевых фонем → ничего не записано")
    }

    // MARK: - Чистые хелперы ингестора

    func test_position_mapsByIndex() {
        XCTAssertEqual(LivePhonemePassportIngestor.position(forPhonemeIndex: 0, totalPhonemes: 3), .initial)
        XCTAssertEqual(LivePhonemePassportIngestor.position(forPhonemeIndex: 1, totalPhonemes: 3), .medial)
        XCTAssertEqual(LivePhonemePassportIngestor.position(forPhonemeIndex: 2, totalPhonemes: 3), .final)
        XCTAssertEqual(LivePhonemePassportIngestor.position(forPhonemeIndex: 0, totalPhonemes: 1), .initial)
    }

    func test_isTargetPhoneme_filtersByGroup() {
        XCTAssertTrue(LivePhonemePassportIngestor.isTargetPhoneme("r"), "соноры — целевая группа")
        XCTAssertTrue(LivePhonemePassportIngestor.isTargetPhoneme("s"), "свистящие — целевая группа")
        XCTAssertTrue(LivePhonemePassportIngestor.isTargetPhoneme("ʂ"), "шипящие — целевая группа")
        XCTAssertTrue(LivePhonemePassportIngestor.isTargetPhoneme("k"), "заднеязычные — целевая группа")
        XCTAssertFalse(LivePhonemePassportIngestor.isTargetPhoneme("a"), "гласные — не цель")
        XCTAssertFalse(LivePhonemePassportIngestor.isTargetPhoneme("b"), "губные — не цель")
    }

    func test_defectKey_mapsToProfileStrings() {
        XCTAssertEqual(LivePhonemePassportIngestor.defectKey(.correct), "ok")
        XCTAssertEqual(LivePhonemePassportIngestor.defectKey(.distortion), "distortion")
        XCTAssertEqual(LivePhonemePassportIngestor.defectKey(.developmentalSubstitution), "age_substitution")
        XCTAssertEqual(LivePhonemePassportIngestor.defectKey(.unexpectedSubstitution), "substitution")
        XCTAssertEqual(LivePhonemePassportIngestor.defectKey(.omission), "omission")
    }
}
