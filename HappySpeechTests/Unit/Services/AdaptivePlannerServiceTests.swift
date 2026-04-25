import XCTest
@testable import HappySpeech

// MARK: - AdaptivePlannerServiceTests
// ==================================================================================
// 15 unit-тестов для LiveAdaptivePlannerService (M10.1 batch 2 — требование ≥15).
//
// Стратегия:
//   • Чисто детерминированные методы (static) тестируются напрямую — без I/O.
//   • MockAdaptivePlannerService тестирует поведение через протокол.
//   • SoundProgressAggregator тестируется через SessionDTO-стабы.
//   • shouldTakeBreak / sessionMaxSec / normalize — пограничные случаи.
// ==================================================================================

// MARK: - SessionDTO factories (тест-стабы)

private extension SessionDTO {
    static func stub(
        id: String = UUID().uuidString,
        childId: String = "child-1",
        targetSound: String = "Р",
        stage: CorrectionStage = .wordInit,
        successRate: Double = 0.75,
        fatigueDetected: Bool = false,
        daysAgo: Int = 0,
        attempts: [AttemptDTO] = []
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
            fatigueDetected: fatigueDetected,
            isSynced: false,
            attempts: attempts
        )
    }
}

// MARK: - AdaptivePlannerServiceTests

final class AdaptivePlannerServiceTests: XCTestCase {

    // MARK: - 1. MockAdaptivePlannerService — buildDailyRoute возвращает маршрут

    func testMock_buildDailyRoute_returnsNonEmptyRoute() async throws {
        let sut = MockAdaptivePlannerService()
        let route = try await sut.buildDailyRoute(for: "child-1")
        XCTAssertFalse(route.steps.isEmpty, "Маршрут должен содержать хотя бы один шаг")
        XCTAssertGreaterThan(route.maxDurationSec, 0)
    }

    // MARK: - 2. MockAdaptivePlannerService — recordSessionResult сохраняет качество

    func testMock_recordSessionResult_storesQuality() async throws {
        let sut = MockAdaptivePlannerService()
        try await sut.recordSessionResult(childId: "child-1", soundTarget: "Р", qualityScore: .correct)
        XCTAssertEqual(sut.recordedQualities.count, 1)
        XCTAssertEqual(sut.recordedQualities.first?.quality, .correct)
        XCTAssertEqual(sut.recordedQualities.first?.soundTarget, "Р")
    }

    // MARK: - 3. shouldTakeBreak — 3 подряд неправильных → пауза

    func testShouldTakeBreak_threeWrong_returnsTrue() {
        let sut = MockAdaptivePlannerService()
        XCTAssertTrue(sut.shouldTakeBreak(consecutiveWrong: 3, sessionDurationSec: 60, childAge: 6))
    }

    // MARK: - 4. shouldTakeBreak — 2 подряд неправильных → продолжать

    func testShouldTakeBreak_twoWrong_returnsFalse() {
        let sut = MockAdaptivePlannerService()
        XCTAssertFalse(sut.shouldTakeBreak(consecutiveWrong: 2, sessionDurationSec: 60, childAge: 6))
    }

    // MARK: - 5. shouldTakeBreak — превышение 90% длительности → пауза

    func testShouldTakeBreak_overDurationCap_returnsTrue() {
        let sut = LiveAdaptivePlannerService()
        // 5-летний ребёнок: cap=480с → 90% = 432с → 440 > 432
        XCTAssertTrue(sut.shouldTakeBreak(consecutiveWrong: 0, sessionDurationSec: 440, childAge: 5))
    }

    // MARK: - 6. sessionMaxSec — правильные значения по возрасту

    func testSessionMaxSec_byAge() {
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 5), 480,  "5 лет → 8 мин")
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 6), 720,  "6 лет → 12 мин")
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 7), 720,  "7 лет → 12 мин")
        XCTAssertEqual(LiveAdaptivePlannerService.sessionMaxSec(for: 8), 1200, "8 лет → 20 мин")
    }

    // MARK: - 7. normalize — EF 1.3 → 0.0, EF 3.0 → 1.0, EF 2.15 → ~0.5

    func testNormalize_efBounds() {
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 1.3), 0.0, accuracy: 0.001)
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 3.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 2.15), 0.5, accuracy: 0.01)
    }

    // MARK: - 8. normalize — зажимает значения вне диапазона

    func testNormalize_clamps() {
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 0.5), 0.0, accuracy: 0.001, "EF ниже минимума → 0")
        XCTAssertEqual(LiveAdaptivePlannerService.normalize(ef: 5.0), 1.0, accuracy: 0.001, "EF выше максимума → 1")
    }

    // MARK: - 9. computeFatigue — 3 подряд неправильных → .tired

    func testComputeFatigue_threeConsecutiveWrong_isTired() {
        let state = SoundProgressState(
            soundTarget: "Р",
            stage: .wordInit,
            consecutiveWrong: 3
        )
        let level = LiveAdaptivePlannerService.computeFatigue(state: state, hour: 10)
        XCTAssertEqual(level, .tired)
    }

    // MARK: - 10. computeFatigue — 2 подряд неправильных → .normal

    func testComputeFatigue_twoConsecutiveWrong_isNormal() {
        let state = SoundProgressState(
            soundTarget: "Р",
            stage: .wordInit,
            consecutiveWrong: 2
        )
        let level = LiveAdaptivePlannerService.computeFatigue(state: state, hour: 10)
        XCTAssertEqual(level, .normal)
    }

    // MARK: - 11. computeFatigue — поздний час и есть история → как минимум .normal

    func testComputeFatigue_lateHour_withHistory_isAtLeastNormal() {
        let state = SoundProgressState(
            soundTarget: "Р",
            stage: .wordInit,
            lastReviewDate: Date().addingTimeInterval(-86400)
        )
        let level = LiveAdaptivePlannerService.computeFatigue(state: state, hour: 22)
        XCTAssertNotEqual(level, .fresh, "Поздний час с историей не должен быть fresh")
    }

    // MARK: - 12. computeFatigue — дневной час без истории → .fresh

    func testComputeFatigue_dayHour_noHistory_isFresh() {
        let state = SoundProgressState(soundTarget: "Р", stage: .wordInit)
        let level = LiveAdaptivePlannerService.computeFatigue(state: state, hour: 11)
        XCTAssertEqual(level, .fresh)
    }

    // MARK: - 13. selectPrimaryState — самый просроченный звук выбирается первым

    func testSelectPrimaryState_mostOverdueWins() {
        let recent = SoundProgressState(
            soundTarget: "С",
            stage: .wordInit,
            lastIntervalDays: 1,
            lastReviewDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
        )
        // «Р» не отрабатывался никогда → overdueDays = Int.max → побеждает
        let never = SoundProgressState(soundTarget: "Р", stage: .isolated)
        let primary = LiveAdaptivePlannerService.selectPrimaryState(from: [recent, never])
        XCTAssertEqual(primary?.soundTarget, "Р",
            "Звук без истории (overdue=Int.max) должен быть выбран как приоритетный")
    }

    // MARK: - 14. composeRoute — fresh → 4 шага, tired → 2 шага, normal → 3 шага

    func testComposeRoute_stepCountByFatigue() {
        let fresh  = LiveAdaptivePlannerService.composeRoute(soundTarget: "Р", stage: .wordInit, fatigue: .fresh)
        let normal = LiveAdaptivePlannerService.composeRoute(soundTarget: "Р", stage: .wordInit, fatigue: .normal)
        let tired  = LiveAdaptivePlannerService.composeRoute(soundTarget: "Р", stage: .wordInit, fatigue: .tired)
        XCTAssertEqual(fresh.count,  4, "fresh → 4 шага")
        XCTAssertEqual(normal.count, 3, "normal → 3 шага")
        XCTAssertEqual(tired.count,  2, "tired → 2 шага")
    }

    // MARK: - 15. SoundProgressAggregator — пустой список сессий → дефолтное состояние

    func testAggregator_noSessions_returnsDefault() {
        let state = SoundProgressAggregator.aggregate(soundTarget: "Ш", sessions: [])
        XCTAssertEqual(state.soundTarget, "Ш")
        XCTAssertEqual(state.easinessFactor, SM2Engine.defaultEF, accuracy: 0.001,
            "Без сессий EF должен быть дефолтным (2.5)")
        XCTAssertEqual(state.repetitions, 0)
        XCTAssertNil(state.lastReviewDate)
    }

    // MARK: - 16. SoundProgressAggregator — высокий successRate обновляет EF вверх

    func testAggregator_highSuccessRate_raisesEF() {
        let sessions = (0..<5).map { i in
            SessionDTO.stub(
                id: "s-\(i)",
                targetSound: "Ш",
                successRate: 0.95,
                daysAgo: 5 - i
            )
        }
        let state = SoundProgressAggregator.aggregate(soundTarget: "Ш", sessions: sessions)
        XCTAssertGreaterThan(state.easinessFactor, SM2Engine.defaultEF,
            "Высокий successRate должен повышать EF")
        XCTAssertGreaterThan(state.repetitions, 0)
    }

    // MARK: - 17. SoundProgressAggregator — низкий successRate включает флаг специалиста

    func testAggregator_lowSuccessRate_flagsSpecialistReview() {
        // 20 сессий с successRate=0.1 → много blackout → EF падает ниже 1.5
        let sessions = (0..<20).map { i in
            SessionDTO.stub(id: "s-\(i)", targetSound: "Р", successRate: 0.1, daysAgo: 20 - i)
        }
        let state = SoundProgressAggregator.aggregate(soundTarget: "Р", sessions: sessions)
        XCTAssertTrue(state.needsSpecialistReview,
            "После многих провалов EF должен опуститься ниже 1.5 → needsSpecialistReview=true")
    }
}
