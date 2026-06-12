@testable import HappySpeech
import XCTest

// MARK: - ContentEngineTests

final class ContentEngineTests: XCTestCase {

    func testGeneratedCatalogReachesMatrixVolume() async {
        // Честный счётчик активностей из реального контента (замена устаревшего
        // estimatedContentCount, который считал слова-копии). Ожидаемо ≈766 по
        // матрице content-generator-matrix; допускаем диапазон калибровки minPool.
        let engine = ContentEngine(contentService: LiveContentService())
        let count = await engine.generatedActivityCount()
        XCTAssertGreaterThan(count, 600,
                             "Генератор вариаций должен выдавать сотни валидных активностей (≈766 по матрице), получено \(count)")
    }

    func testAvailableLessonsAreNonEmpty() {
        let engine = ContentEngine(contentService: MockContentService())
        let lessons = engine.availableLessons(for: "Р")
        XCTAssertFalse(lessons.isEmpty, "Должны быть доступные уроки для звука Р")
    }

    func testSeedContentRWordInitCount() {
        XCTAssertEqual(SeedContent.rWordInit.count, 40, "Должно быть ровно 40 слов для Р в начале слова")
    }

    func testSeedContentSWordInitCount() {
        XCTAssertEqual(SeedContent.sWordInit.count, 40, "Должно быть ровно 40 слов для С в начале слова")
    }

    func testSeedContentShWordInitCount() {
        XCTAssertEqual(SeedContent.shWordInit.count, 40, "Должно быть ровно 40 слов для Ш в начале слова")
    }

    func testSeedContentHasDifficulty1And2() {
        let items = SeedContent.rWordInit
        let diff1 = items.filter { $0.difficulty == 1 }
        let diff2 = items.filter { $0.difficulty == 2 }
        XCTAssertFalse(diff1.isEmpty, "Должны быть слова сложности 1")
        XCTAssertFalse(diff2.isEmpty, "Должны быть слова сложности 2")
    }

    func testSoundFamilyContainsSounds() {
        XCTAssertTrue(SoundFamily.sonorant.sounds.contains("Р"))
        XCTAssertTrue(SoundFamily.whistling.sounds.contains("С"))
        XCTAssertTrue(SoundFamily.hissing.sounds.contains("Ш"))
    }

    func testCorrectionStageOrder() {
        XCTAssertLessThan(CorrectionStage.prep, CorrectionStage.isolated)
        XCTAssertLessThan(CorrectionStage.isolated, CorrectionStage.syllable)
        XCTAssertLessThan(CorrectionStage.syllable, CorrectionStage.wordInit)
    }
}
