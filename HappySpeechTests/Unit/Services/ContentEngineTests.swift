import XCTest
@testable import HappySpeech

// MARK: - ContentEngineTests

final class ContentEngineTests: XCTestCase {

    func testEstimatedContentCountIsAbove6000() {
        let engine = ContentEngine(contentService: MockContentService())
        XCTAssertGreaterThan(engine.estimatedContentCount, 6000,
                             "ContentEngine должен обеспечивать более 6000 единиц контента")
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
