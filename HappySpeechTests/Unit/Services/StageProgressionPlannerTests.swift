@testable import HappySpeech
import XCTest

// MARK: - StageProgressionPlannerTests (F1-014 / F1-015)
// ==================================================================================
// Поэтапное движение по correction-stages:
//   • F1-015 — ретроспективный старт (первые 2–3 шага предыдущей стадии).
//   • F1-014 — откат-логика (rollback): <50% ×2 / перерыв >14 дней → стадия−1.
// Все функции чистые/детерминированные — тестируются напрямую, без I/O.
// ==================================================================================

// MARK: - SessionDTO factory (тест-стаб)

private extension SessionDTO {
    static func make(
        id: String = UUID().uuidString,
        childId: String = "child-1",
        targetSound: String = "Р",
        stage: CorrectionStage = .wordInit,
        successRate: Double = 0.75,
        daysAgo: Int = 0
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let total = 10
        let correct = Int((Double(total) * successRate).rounded())
        return SessionDTO(
            id: id,
            childId: childId,
            date: date,
            templateType: "listen-and-choose",
            targetSound: targetSound,
            stage: stage.rawValue,
            durationSeconds: 300,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}

final class StageProgressionPlannerTests: XCTestCase {

    // MARK: - CorrectionStage.previous

    // MARK: 1. previous идёт ровно на один шаг вниз по лестнице

    func testPrevious_oneStepDown() {
        XCTAssertEqual(CorrectionStage.wordInit.previous, .syllable, "слова → слоги (методический откат)")
        XCTAssertEqual(CorrectionStage.syllable.previous, .isolated)
        XCTAssertEqual(CorrectionStage.sentence.previous, .phrase)
        XCTAssertEqual(CorrectionStage.story.previous, .sentence)
    }

    // MARK: 2. previous у нижних стадий — упирается / nil

    func testPrevious_floor() {
        XCTAssertEqual(CorrectionStage.isolated.previous, .prep)
        XCTAssertNil(CorrectionStage.prep.previous, "ниже подготовки откатываться некуда")
        XCTAssertEqual(CorrectionStage.diff.previous, .story, "дифференциация → последняя линейная стадия")
    }

    // MARK: - F1-014 Rollback trigger

    // MARK: 3. Нет регресса — нет отката

    func testRollback_noRegression_noTrigger() {
        let sessions = [
            SessionDTO.make(successRate: 0.85, daysAgo: 2),
            SessionDTO.make(successRate: 0.80, daysAgo: 1)
        ]
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: sessions), .none)
    }

    // MARK: 4. <50% за 2 последние сессии подряд → откат по точности

    func testRollback_lowAccuracyTwice_triggers() {
        let sessions = [
            SessionDTO.make(successRate: 0.90, daysAgo: 3),
            SessionDTO.make(successRate: 0.40, daysAgo: 2),
            SessionDTO.make(successRate: 0.30, daysAgo: 1)
        ]
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: sessions), .lowAccuracy)
    }

    // MARK: 5. Одна низкая сессия из двух — НЕ откат

    func testRollback_singleLowSession_noTrigger() {
        let sessions = [
            SessionDTO.make(successRate: 0.85, daysAgo: 2),
            SessionDTO.make(successRate: 0.30, daysAgo: 1)
        ]
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: sessions), .none,
                       "одна неудача — не повод откатывать (errorless, без паники)")
    }

    // MARK: 6. Перерыв >14 дней → откат по перерыву

    func testRollback_longBreak_triggers() {
        let sessions = [SessionDTO.make(successRate: 0.85, daysAgo: 20)]
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: sessions), .longBreak)
    }

    // MARK: 7. Перерыв ровно 14 дней — ещё НЕ откат (строго больше)

    func testRollback_exactly14Days_noTrigger() {
        let sessions = [SessionDTO.make(successRate: 0.85, daysAgo: 14)]
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: sessions), .none)
    }

    // MARK: 8. Перерыв перекрывает низкую точность (нужен ретест)

    func testRollback_longBreakWins_overLowAccuracy() {
        let sessions = [
            SessionDTO.make(successRate: 0.30, daysAgo: 30),
            SessionDTO.make(successRate: 0.20, daysAgo: 20)
        ]
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: sessions), .longBreak)
    }

    // MARK: 9. Пустая история — нет отката

    func testRollback_emptyHistory_noTrigger() {
        XCTAssertEqual(StageProgressionPlanner.rollbackTrigger(soundSessions: []), .none)
    }

    // MARK: - F1-014 recommendedStage

    // MARK: 10. Откат сдвигает рекомендуемую стадию на шаг назад

    func testRecommendedStage_rollbackMovesBackOneStep() {
        let sessions = [
            SessionDTO.make(stage: .wordInit, successRate: 0.40, daysAgo: 2),
            SessionDTO.make(stage: .wordInit, successRate: 0.30, daysAgo: 1)
        ]
        let decision = StageProgressionPlanner.recommendedStage(current: .wordInit, soundSessions: sessions)
        XCTAssertTrue(decision.didRollback)
        XCTAssertEqual(decision.stage, .syllable, "слова → слоги (НЕ к изолированному)")
        XCTAssertEqual(decision.trigger, .lowAccuracy)
    }

    // MARK: 11. Без регресса — стадия не меняется

    func testRecommendedStage_noRegression_keepsStage() {
        let sessions = [SessionDTO.make(stage: .phrase, successRate: 0.85, daysAgo: 1)]
        let decision = StageProgressionPlanner.recommendedStage(current: .phrase, soundSessions: sessions)
        XCTAssertFalse(decision.didRollback)
        XCTAssertEqual(decision.stage, .phrase)
    }

    // MARK: 12. Откат не опускается ниже изолированного звука

    func testRecommendedStage_doesNotGoBelowIsolated() {
        let sessions = [
            SessionDTO.make(stage: .syllable, successRate: 0.10, daysAgo: 2),
            SessionDTO.make(stage: .syllable, successRate: 0.10, daysAgo: 1)
        ]
        let decision = StageProgressionPlanner.recommendedStage(current: .syllable, soundSessions: sessions)
        // syllable.previous = isolated → пол = isolated (не prep).
        XCTAssertEqual(decision.stage, .isolated, "не опускаемся на голую артикуляцию")
        XCTAssertTrue(decision.didRollback)
    }

    // MARK: 13. На изолированном звуке откатываться некуда — стадия держится

    func testRecommendedStage_atFloor_keepsStageButFlagsTrigger() {
        let sessions = [
            SessionDTO.make(stage: .isolated, successRate: 0.10, daysAgo: 2),
            SessionDTO.make(stage: .isolated, successRate: 0.10, daysAgo: 1)
        ]
        let decision = StageProgressionPlanner.recommendedStage(current: .isolated, soundSessions: sessions)
        XCTAssertEqual(decision.stage, .isolated, "пол лестницы — стадия не меняется")
    }

    // MARK: - F1-015 Retrospective start

    // MARK: 14. Ретро-старт: 3 шага предыдущей стадии (fresh), все isRetrospective

    func testRetrospective_freshGivesThreeStepsOfPreviousStage() {
        let steps = StageProgressionPlanner.retrospectiveSteps(
            currentStage: .wordInit,
            soundTarget: "Р",
            fatigue: .fresh
        )
        XCTAssertEqual(steps.count, 2, "по умолчанию 2 ретро-шага")
        XCTAssertTrue(steps.allSatisfy { $0.isRetrospective }, "все помечены ретроспективными")
        XCTAssertTrue(steps.allSatisfy { $0.stage == .syllable }, "предыдущая стадия — слоги")
    }

    // MARK: 15. Ретро-старт при усталости — короче (2 шага), без нагрузки

    func testRetrospective_tiredGivesTwoSteps() {
        let steps = StageProgressionPlanner.retrospectiveSteps(
            currentStage: .sentence,
            soundTarget: "С",
            fatigue: .tired
        )
        XCTAssertEqual(steps.count, 2)
        XCTAssertTrue(steps.allSatisfy { $0.stage == .phrase })
    }

    // MARK: 16. Ретро-старт на самом первом этапе — пусто (нечего вспоминать)

    func testRetrospective_atPrep_isEmpty() {
        let steps = StageProgressionPlanner.retrospectiveSteps(
            currentStage: .prep,
            soundTarget: "Р",
            fatigue: .fresh
        )
        XCTAssertTrue(steps.isEmpty, "на подготовке нет предыдущей стадии")
    }

    // MARK: 17. Ретро-шаги — лёгкие (difficulty 1, короткие, звуковой трек)

    func testRetrospective_stepsAreGentle() {
        let steps = StageProgressionPlanner.retrospectiveSteps(
            currentStage: .wordMed,
            soundTarget: "Ш",
            fatigue: .fresh
        )
        XCTAssertFalse(steps.isEmpty)
        for step in steps {
            XCTAssertEqual(step.difficulty, 1, "ретро — без когнитивной нагрузки")
            XCTAssertLessThanOrEqual(step.durationTargetSec, 90)
            XCTAssertEqual(step.track, .sound)
        }
    }

    // MARK: - Integration: buildDailyRoute (F1-014 + F1-015)

    // MARK: 18. Маршрут начинается с ретроспективных шагов предыдущей стадии

    func testBuildRoute_startsWithRetrospectiveSteps() async throws {
        // Ребёнок на стадии wordInit, хорошая история (без отката).
        let sessions = [SessionDTO.make(childId: "child-1", stage: .wordInit, successRate: 0.85, daysAgo: 1)]
        let child = ChildProfileDTO(id: "child-1", name: "Т", age: 6, targetSounds: ["Р"], parentId: "p")
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child]),
            sessionRepository: MockSessionRepository(sessions: sessions)
        )
        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertTrue(route.steps.first?.isRetrospective ?? false,
                      "первый шаг сессии — ретроспективный (вспомним прошлое)")
    }

    // MARK: 19. При регрессе маршрут содержит видимый rollback-шаг

    func testBuildRoute_regressionMarksRollbackStep() async throws {
        let sessions = [
            SessionDTO.make(childId: "child-1", stage: .wordInit, successRate: 0.30, daysAgo: 2),
            SessionDTO.make(childId: "child-1", stage: .wordInit, successRate: 0.20, daysAgo: 1)
        ]
        let child = ChildProfileDTO(id: "child-1", name: "Т", age: 6, targetSounds: ["Р"], parentId: "p")
        let planner = LiveAdaptivePlannerService(
            childRepository: MockChildRepository(children: [child]),
            sessionRepository: MockSessionRepository(sessions: sessions)
        )
        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertTrue(route.steps.contains { $0.isRollback },
                      "регресс должен дать видимый rollback-шаг «повторим прошлое»")
    }

    // MARK: 20. markFirstSoundStepRollback помечает первый звуковой шаг

    func testMarkFirstSoundStep_flagsOnlyFirstSound() {
        let steps = [
            RouteStepItem(templateType: .minimalPairs, targetSound: "Р", stage: .diff, difficulty: 2, wordCount: 6, durationTargetSec: 120, track: .phonemic),
            RouteStepItem(templateType: .repeatAfterModel, targetSound: "Р", stage: .syllable, difficulty: 1, wordCount: 6, durationTargetSec: 120, track: .sound),
            RouteStepItem(templateType: .sorting, targetSound: "Р", stage: .syllable, difficulty: 1, wordCount: 6, durationTargetSec: 120, track: .sound)
        ]
        let marked = LiveAdaptivePlannerService.markFirstSoundStepRollback(steps)
        XCTAssertFalse(marked[0].isRollback, "фонематический шаг не помечается")
        XCTAssertTrue(marked[1].isRollback, "первый звуковой шаг — rollback")
        XCTAssertFalse(marked[2].isRollback, "второй звуковой шаг — не помечается")
    }
}
