@testable import HappySpeech
import CoreVideo
import XCTest

// MARK: - VisionObjectClassifierWorkerTests
//
// Покрывает чистое ядро «Звукового охотника» — `SoundHunterMapping`:
//   - маппинг Vision-лейбла (точный / частичный через запятую) → русское слово;
//   - фильтрацию классификаций по целевому звуку + порогу уверенности;
//   - сортировку по убыванию confidence;
//   - нормализацию звука (регистр, мягкий знак);
//   - список «охотничьих» слов для фоллбэка фото-карточек.
//
// Vision-инференс (ClassifyImageRequest / VNClassifyImageRequest) проверяется
// через Mock-worker — `VNClassificationObservation` нельзя инстанцировать
// вручную, а ANE-контекст недоступен на CI. Контракт маппинга — тот же.

final class VisionObjectClassifierWorkerTests: XCTestCase {

    // MARK: - Fixtures

    private func makeMapping() -> SoundHunterMapping {
        SoundHunterMapping(entries: [
            "scarf": ObjectMapping(ru: "шарф", sounds: ["ш", "р", "ф"]),
            "sock": ObjectMapping(ru: "носок", sounds: ["с", "к"]),
            "umbrella": ObjectMapping(ru: "зонт", sounds: ["з", "т"]),
            "cup": ObjectMapping(ru: "чашка", sounds: ["ч", "ш", "к"])
        ])
    }

    // MARK: - entry(forVisionLabel:)

    func test_entry_exactMatch() {
        let mapping = makeMapping()
        XCTAssertEqual(mapping.entry(forVisionLabel: "scarf")?.ru, "шарф")
    }

    func test_entry_partialMatch_commaSuffix() {
        let mapping = makeMapping()
        // ImageNet иногда отдаёт "scarf, muffler" — берём первую компоненту.
        XCTAssertEqual(mapping.entry(forVisionLabel: "scarf, muffler")?.ru, "шарф")
    }

    func test_entry_unknown_returnsNil() {
        let mapping = makeMapping()
        XCTAssertNil(mapping.entry(forVisionLabel: "spaceship"))
    }

    // MARK: - matches(from:targetSound:minimumConfidence:)

    func test_matches_targetSoundNil_returnsAllMapped() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("scarf", 0.9), ("sock", 0.8), ("unknown", 0.95)],
            targetSound: nil,
            minimumConfidence: 0.25
        )
        // "unknown" не в словаре — отброшен; остальные две прошли.
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.word)), ["шарф", "носок"])
    }

    func test_matches_filtersByTargetSound() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("scarf", 0.9), ("sock", 0.8), ("umbrella", 0.7)],
            targetSound: "с",
            minimumConfidence: 0.25
        )
        // Только "носок" содержит звук "с".
        XCTAssertEqual(result.map(\.word), ["носок"])
    }

    func test_matches_targetSound_sh_keepsBothSibilants() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("scarf", 0.9), ("cup", 0.6), ("sock", 0.8)],
            targetSound: "ш",
            minimumConfidence: 0.25
        )
        // "шарф" и "чашка" содержат "ш"; "носок" — нет.
        XCTAssertEqual(Set(result.map(\.word)), ["шарф", "чашка"])
    }

    func test_matches_belowConfidence_dropped() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("scarf", 0.10)],
            targetSound: nil,
            minimumConfidence: 0.25
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_matches_sortedByConfidenceDescending() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("sock", 0.4), ("scarf", 0.9), ("umbrella", 0.6)],
            targetSound: nil,
            minimumConfidence: 0.25
        )
        XCTAssertEqual(result.map(\.word), ["шарф", "зонт", "носок"])
    }

    func test_matches_caseInsensitiveTargetSound() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("scarf", 0.9)],
            targetSound: "Ш",
            minimumConfidence: 0.25
        )
        XCTAssertEqual(result.map(\.word), ["шарф"])
    }

    func test_matches_targetSoundAbsent_returnsEmpty() {
        let mapping = makeMapping()
        let result = mapping.matches(
            from: [("scarf", 0.9), ("sock", 0.8)],
            targetSound: "ы",
            minimumConfidence: 0.25
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - normalize(sound:)

    func test_normalize_lowercasesAndTrims() {
        XCTAssertEqual(SoundHunterMapping.normalize(sound: "  Ш "), "ш")
    }

    func test_normalize_softSign_reducesToBase() {
        // Мягкие звуки сводятся к базовой согласной (в словаре звуки без «ь»).
        XCTAssertEqual(SoundHunterMapping.normalize(sound: "Сь"), "с")
        XCTAssertEqual(SoundHunterMapping.normalize(sound: "Рь"), "р")
    }

    func test_normalize_nilAndEmpty() {
        XCTAssertNil(SoundHunterMapping.normalize(sound: nil))
        XCTAssertNil(SoundHunterMapping.normalize(sound: "   "))
    }

    // MARK: - huntableWords(forSound:)

    func test_huntableWords_filteredAndSorted() {
        let mapping = makeMapping()
        let words = mapping.huntableWords(forSound: "к")
        // "носок" и "чашка" содержат "к"; отсортированы по слову.
        XCTAssertEqual(words.map(\.word), ["носок", "чашка"])
    }

    func test_huntableWords_softSignNormalized() {
        let mapping = makeMapping()
        // "Сь" → "с" → только "носок".
        let words = mapping.huntableWords(forSound: "Сь")
        XCTAssertEqual(words.map(\.word), ["носок"])
    }

    func test_huntableWords_noMatch_empty() {
        let mapping = makeMapping()
        XCTAssertTrue(mapping.huntableWords(forSound: "ы").isEmpty)
    }

    // MARK: - distractorWords(forSound:) + huntableGrid(...)
    // P0-1: фоллбэк-сетка фото-карточек должна содержать дистракторы (без звука),
    // иначе «найди предмет со звуком Х» теряет смысл — все карточки «правильные».

    func test_distractorWords_excludeTargetSound() {
        let mapping = makeMapping()
        // Звук "ш": целевые — шарф, чашка; дистракторы — носок, зонт.
        let distractors = mapping.distractorWords(forSound: "ш")
        XCTAssertEqual(Set(distractors.map(\.word)), ["носок", "зонт"])
        XCTAssertFalse(distractors.contains { $0.sounds.contains("ш") })
    }

    func test_huntableGrid_hasTargetsAndDistractors() {
        let mapping = makeMapping()
        let grid = mapping.huntableGrid(forSound: "ш", targetCount: 2, distractorCount: 2)
        let targets = grid.filter { $0.isTarget }
        let distractors = grid.filter { !$0.isTarget }
        XCTAssertGreaterThanOrEqual(targets.count, 1, "Всегда хотя бы 1 целевой")
        XCTAssertGreaterThanOrEqual(distractors.count, 2, "Всегда хотя бы 2 дистрактора")
        // Целевые реально содержат звук, дистракторы — нет.
        XCTAssertTrue(targets.allSatisfy { $0.match.sounds.contains("ш") })
        XCTAssertFalse(distractors.contains { $0.match.sounds.contains("ш") })
    }

    func test_huntableGrid_enforcesMinimumsEvenWhenZeroRequested() {
        let mapping = makeMapping()
        // Запросили 0 целевых/0 дистракторов — Worker всё равно держит минимумы.
        let grid = mapping.huntableGrid(forSound: "ш", targetCount: 0, distractorCount: 0)
        XCTAssertGreaterThanOrEqual(grid.filter { $0.isTarget }.count, 1)
        XCTAssertGreaterThanOrEqual(grid.filter { !$0.isTarget }.count, 2)
    }

    // MARK: - hasAsset фильтрация (пустые карточки)

    func test_huntableWords_hasAssetFilter_excludesWordsWithoutImage() {
        let mapping = makeMapping()
        // Разрешаем только "носок" — "шарф" будет отброшен.
        let words = mapping.huntableWords(forSound: "к", hasAsset: { $0 == "носок" })
        XCTAssertEqual(words.map(\.word), ["носок"])
        XCTAssertFalse(words.contains { $0.word == "чашка" })
    }

    func test_distractorWords_hasAssetFilter_excludesWordsWithoutImage() {
        let mapping = makeMapping()
        // Для звука "ш" дистракторы — носок, зонт; разрешаем только зонт.
        let words = mapping.distractorWords(forSound: "ш", hasAsset: { $0 == "зонт" })
        XCTAssertEqual(words.map(\.word), ["зонт"])
    }

    func test_huntableGrid_hasAssetFilter_noEmptyCards() {
        // Словарь с 4 предметами: 2 со звуком "ш" (шарф, чашка) и 2 без (носок, зонт).
        // Запрещаем "шарф" — в целевых должна оказаться только "чашка".
        let mapping = makeMapping()
        let grid = mapping.huntableGrid(
            forSound: "ш",
            targetCount: 2,
            distractorCount: 2,
            hasAsset: { $0 != "шарф" }
        )
        XCTAssertFalse(grid.contains { $0.match.word == "шарф" },
                       "Слово без ассета не должно попадать в сетку")
        // Хотя бы 1 целевой (чашка) и 2 дистрактора (носок, зонт).
        XCTAssertGreaterThanOrEqual(grid.filter { $0.isTarget }.count, 1)
        XCTAssertGreaterThanOrEqual(grid.filter { !$0.isTarget }.count, 2)
    }

    // MARK: - MockVisionObjectClassifierWorker (async contract)

    func test_mockWorker_classify_filtersByTargetSound() async throws {
        let result = try await Self.runMockClassify(targetSound: "ш")
        // Мок: scarf(шарф) + cup(чашка) содержат "ш"; sock(носок) — нет.
        XCTAssertEqual(Set(result.map(\.word)), ["шарф", "чашка"])
    }

    func test_mockWorker_classify_nilReturnsAll() async throws {
        let result = try await Self.runMockClassify(targetSound: nil)
        XCTAssertEqual(result.count, 3)
    }

    func test_mockWorker_huntableWords() async {
        let sut = MockVisionObjectClassifierWorker()
        let words = await sut.huntableWords(forSound: "с")
        XCTAssertEqual(words.map(\.word), ["носок"])
    }

    // MARK: - Live mapping load (resource-dependent, graceful)

    func test_loadFromBundle_eitherLoadsOrThrowsMappingNotFound() {
        // Ресурс лежит в Bundle.main приложения; под тест-хостом может быть
        // недоступен — тогда корректно бросается mappingNotFound. Без краша.
        do {
            let mapping = try SoundHunterMapping.loadFromBundle()
            // Если загрузился — словарь непустой и базовые слова на месте.
            XCTAssertNotNil(mapping.entry(forVisionLabel: "scarf"))
        } catch SoundHunterError.mappingNotFound {
            // Допустимо в тест-бандле.
        } catch {
            XCTFail("Неожиданная ошибка загрузки маппинга: \(error)")
        }
    }

    // MARK: - Helpers (Sendable-safe pixel buffer region)

    private static func runMockClassify(targetSound: String?) async throws -> [SoundHunterMapping.Match] {
        let sut = MockVisionObjectClassifierWorker()
        let buffer = try XCTUnwrap(makePixelBuffer())
        return try await sut.classify(in: buffer, targetSound: targetSound)
    }

    private static func makePixelBuffer(width: Int = 32, height: Int = 32) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA, attrs, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 100, CVPixelBufferGetBytesPerRow(buffer) * height)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
