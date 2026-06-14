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
