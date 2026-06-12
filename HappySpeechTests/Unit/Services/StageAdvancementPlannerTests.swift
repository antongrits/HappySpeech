@testable import HappySpeech
import XCTest

// MARK: - StageAdvancementPlannerTests (P0-4)
// ==================================================================================
// Продвижение ВПЕРЁД по 10-этапной лестнице коррекции (Фомичёва):
//   • критерий освоения: ≥80% × 2 сессии (изолированный 8/10 = 0.8; рассказ 0.7);
//   • квалифицирующие сессии должны идти ПОДРЯД (неуспех обнуляет серию);
//   • gate: линейное продвижение упирается в `.story`, не заходит в `.diff`
//     (дифференциация управляется SoundTrafficLight после автоматизации пары);
//   • стадия повышается ровно на один шаг лестницы, без перепрыгивания.
// Все функции чистые/детерминированные — тестируются напрямую, без I/O.
// ==================================================================================

final class StageAdvancementPlannerTests: XCTestCase {

    // MARK: - qualifyingRate / sessionQualifies

    func test_qualifyingRate_standardStages_is80Percent() {
        XCTAssertEqual(StageAdvancementPlanner.qualifyingRate(for: .isolated), 0.80, accuracy: 0.0001)
        XCTAssertEqual(StageAdvancementPlanner.qualifyingRate(for: .wordInit), 0.80, accuracy: 0.0001)
        XCTAssertEqual(StageAdvancementPlanner.qualifyingRate(for: .sentence), 0.80, accuracy: 0.0001)
    }

    func test_qualifyingRate_story_is70Percent() {
        XCTAssertEqual(StageAdvancementPlanner.qualifyingRate(for: .story), 0.70, accuracy: 0.0001)
    }

    func test_qualifyingRate_diff_is90Percent() {
        XCTAssertEqual(StageAdvancementPlanner.qualifyingRate(for: .diff), 0.90, accuracy: 0.0001)
    }

    func test_sessionQualifies_atExactThreshold_isTrue() {
        // 8/10 = 0.8 для изолированного звука (методический критерий).
        XCTAssertTrue(StageAdvancementPlanner.sessionQualifies(stage: .isolated, successRate: 0.80))
    }

    func test_sessionQualifies_belowThreshold_isFalse() {
        XCTAssertFalse(StageAdvancementPlanner.sessionQualifies(stage: .wordInit, successRate: 0.79))
    }

    // MARK: - nextLinearStage (gate)

    func test_nextLinearStage_walksLadderUpToStory() {
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .isolated), .syllable)
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .syllable), .wordInit)
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .wordInit), .wordMed)
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .wordMed), .wordFinal)
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .wordFinal), .phrase)
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .phrase), .sentence)
        XCTAssertEqual(StageAdvancementPlanner.nextLinearStage(after: .sentence), .story)
    }

    func test_nextLinearStage_atStoryCeiling_isNil_doesNotEnterDiff() {
        // Gate: дифференциация НЕ достигается автоматическим линейным шагом.
        XCTAssertNil(StageAdvancementPlanner.nextLinearStage(after: .story))
    }

    func test_nextLinearStage_fromDiff_isNil() {
        XCTAssertNil(StageAdvancementPlanner.nextLinearStage(after: .diff))
    }

    // MARK: - apply: освоение → повышение

    func test_apply_twoConsecutiveQualifyingSessions_advancesOneStage() {
        // 1-я квалифицирующая сессия: серия 1, стадия держится.
        let start = StageProgress(stage: .wordInit, consecutiveQualifyingSessions: 0)
        let first = StageAdvancementPlanner.apply(progress: start, sessionSuccessRate: 0.85)
        XCTAssertFalse(first.didAdvance)
        XCTAssertEqual(first.progress.stage, .wordInit)
        XCTAssertEqual(first.progress.consecutiveQualifyingSessions, 1)

        // 2-я квалифицирующая сессия подряд → повышение на следующий шаг лестницы.
        let second = StageAdvancementPlanner.apply(progress: first.progress, sessionSuccessRate: 0.90)
        XCTAssertTrue(second.didAdvance)
        XCTAssertEqual(second.progress.stage, .wordMed, "wordInit → wordMed (один шаг)")
        XCTAssertEqual(second.progress.consecutiveQualifyingSessions, 0, "серия сбрасывается после перехода")
    }

    func test_apply_doesNotSkipStages_onSingleHighSession() {
        // Одной успешной сессии недостаточно — нужны 2 подряд (нет перепрыгивания).
        let start = StageProgress(stage: .syllable, consecutiveQualifyingSessions: 0)
        let result = StageAdvancementPlanner.apply(progress: start, sessionSuccessRate: 1.0)
        XCTAssertFalse(result.didAdvance)
        XCTAssertEqual(result.progress.stage, .syllable)
    }

    // MARK: - apply: провал → нет повышения / сброс серии

    func test_apply_failingSession_resetsStreak_holdsStage() {
        // Накоплена 1 квалифицирующая сессия, затем провал → серия обнуляется.
        let withStreak = StageProgress(stage: .wordInit, consecutiveQualifyingSessions: 1)
        let result = StageAdvancementPlanner.apply(progress: withStreak, sessionSuccessRate: 0.40)
        XCTAssertFalse(result.didAdvance)
        XCTAssertEqual(result.progress.stage, .wordInit, "провал не двигает стадию (откат — у планировщика маршрута)")
        XCTAssertEqual(result.progress.consecutiveQualifyingSessions, 0, "нужны ПОДРЯД успешные — серия сброшена")
    }

    func test_apply_qualifyingThenFailing_doesNotAdvance() {
        let start = StageProgress(stage: .wordMed, consecutiveQualifyingSessions: 0)
        let good = StageAdvancementPlanner.apply(progress: start, sessionSuccessRate: 0.9)   // серия 1
        let bad = StageAdvancementPlanner.apply(progress: good.progress, sessionSuccessRate: 0.3) // сброс
        let goodAgain = StageAdvancementPlanner.apply(progress: bad.progress, sessionSuccessRate: 0.9) // серия 1 (не 2)
        XCTAssertFalse(goodAgain.didAdvance, "прерванная серия не накапливается через провал")
        XCTAssertEqual(goodAgain.progress.stage, .wordMed)
        XCTAssertEqual(goodAgain.progress.consecutiveQualifyingSessions, 1)
    }

    // MARK: - apply: gate на потолке лестницы

    func test_apply_atStoryCeiling_neverAdvancesToDiff() {
        // Даже после многих идеальных сессий на «рассказе» — стадия остаётся `.story`.
        var progress = StageProgress(stage: .story, consecutiveQualifyingSessions: 0)
        for _ in 0..<6 {
            let decision = StageAdvancementPlanner.apply(progress: progress, sessionSuccessRate: 1.0)
            XCTAssertFalse(decision.didAdvance, "линейное продвижение не входит в дифференциацию")
            XCTAssertEqual(decision.progress.stage, .story)
            progress = decision.progress
        }
    }

    func test_apply_storyUsesLowerThreshold() {
        // На «рассказе» критерий 0.70 (связность + 70%), а не 0.80.
        let start = StageProgress(stage: .story, consecutiveQualifyingSessions: 0)
        let result = StageAdvancementPlanner.apply(progress: start, sessionSuccessRate: 0.72)
        XCTAssertEqual(result.progress.consecutiveQualifyingSessions, 1, "0.72 ≥ 0.70 → квалифицирует на story")
    }

    // MARK: - End-to-end лестница

    func test_endToEnd_climbsLadder_isolatedToStory_neverDiff() {
        var progress = StageProgress(stage: .isolated, consecutiveQualifyingSessions: 0)
        // 7 ступеней от .isolated до .story, каждая требует 2 квалифицирующих сессии.
        let expectedClimb: [CorrectionStage] = [.syllable, .wordInit, .wordMed, .wordFinal, .phrase, .sentence, .story]
        for expected in expectedClimb {
            // Первая квалифицирующая сессия копит серию (без перехода).
            progress = StageAdvancementPlanner.apply(progress: progress, sessionSuccessRate: 0.95).progress
            // Вторая подряд — переход на следующий шаг.
            let advanced = StageAdvancementPlanner.apply(progress: progress, sessionSuccessRate: 0.95)
            progress = advanced.progress
            XCTAssertTrue(advanced.didAdvance)
            XCTAssertEqual(progress.stage, expected)
        }
        XCTAssertEqual(progress.stage, .story)
        // Дальнейшие успехи не выводят в дифференциацию.
        let beyond = StageAdvancementPlanner.apply(progress: progress, sessionSuccessRate: 1.0)
        let beyond2 = StageAdvancementPlanner.apply(progress: beyond.progress, sessionSuccessRate: 1.0)
        XCTAssertFalse(beyond2.didAdvance)
        XCTAssertEqual(beyond2.progress.stage, .story)
    }
}
