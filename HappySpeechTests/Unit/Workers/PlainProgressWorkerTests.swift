@testable import HappySpeech
import XCTest

// MARK: - PlainProgressWorkerTests
//
// Фаза E, Волна 7. Покрывает агрегацию аналитики PlainProgressWorker:
// фильтрация сессий по периодам (неделя / прошлая неделя / месяц назад),
// средняя точность, доминирующий звук фокуса, тренд по порогу 0.06,
// суммарные минуты, edge-cases (нет данных, ошибка профиля).

@MainActor
final class PlainProgressWorkerTests: XCTestCase {

    private let now = Date()

    private func child(
        id: String = "c-1",
        sounds: [String] = ["Р"],
        streak: Int = 4
    ) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Миша", age: 6, targetSounds: sounds,
                        parentId: "p-1", currentStreak: streak)
    }

    /// Сессия с заданной точностью (correct/total) и сдвигом по дням назад.
    private func session(
        id: String,
        daysAgo: Double,
        sound: String = "Р",
        total: Int = 10,
        correct: Int,
        duration: Int = 300
    ) -> SessionDTO {
        SessionDTO(
            id: id,
            childId: "c-1",
            date: now.addingTimeInterval(-(daysAgo * 86_400)),
            templateType: TemplateType.bingo.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: duration,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    private func makeSUT(
        children: [ChildProfileDTO],
        sessions: [SessionDTO]
    ) -> PlainProgressWorker {
        PlainProgressWorker(
            childRepository: MockChildRepository(children: children),
            sessionRepository: MockSessionRepository(sessions: sessions)
        )
    }

    // MARK: - Empty data

    func test_loadProgress_noSessions_reportsNoDataTrend() async throws {
        let sut = makeSUT(children: [child()], sessions: [])

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertFalse(response.hasWeekData)
        XCTAssertEqual(response.trend, .noData)
        XCTAssertEqual(response.sessionsThisWeek, 0)
        XCTAssertEqual(response.weekSuccessRate, 0)
        XCTAssertEqual(response.currentStreak, 4)
    }

    func test_loadProgress_missingChild_throws() async {
        let sut = makeSUT(children: [], sessions: [])
        do {
            _ = try await sut.loadProgress(childId: "missing")
            XCTFail("Ожидалась ошибка при отсутствии профиля")
        } catch {
            // Ожидаемо: fetch бросает entityNotFound.
        }
    }

    // MARK: - Week aggregation

    func test_loadProgress_countsOnlyThisWeekSessions() async throws {
        let sessions = [
            session(id: "w1", daysAgo: 1, correct: 8),
            session(id: "w2", daysAgo: 3, correct: 6),
            session(id: "old", daysAgo: 10, correct: 10) // вне недели
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.sessionsThisWeek, 2)
        XCTAssertTrue(response.hasWeekData)
    }

    func test_loadProgress_weekSuccessRateIsAverage() async throws {
        // Точности 0.8 и 0.6 → среднее 0.7.
        let sessions = [
            session(id: "w1", daysAgo: 1, total: 10, correct: 8),
            session(id: "w2", daysAgo: 2, total: 10, correct: 6)
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.weekSuccessRate, 0.7, accuracy: 0.0001)
    }

    func test_loadProgress_practiceMinutesSummedAndConvertedToMinutes() async throws {
        let sessions = [
            session(id: "w1", daysAgo: 1, correct: 8, duration: 300), // 5 мин
            session(id: "w2", daysAgo: 2, correct: 6, duration: 360)  // 6 мин
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.practiceMinutesThisWeek, 11) // 660s / 60
    }

    // MARK: - Trend (threshold 0.06)

    func test_loadProgress_trendImproved_whenWeekRateClearlyHigher() async throws {
        let sessions = [
            session(id: "this", daysAgo: 1, total: 10, correct: 9),   // 0.9
            session(id: "prev", daysAgo: 9, total: 10, correct: 5)    // 0.5 (прошлая неделя)
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.trend, .improved)
    }

    func test_loadProgress_trendDeclined_whenWeekRateClearlyLower() async throws {
        let sessions = [
            session(id: "this", daysAgo: 1, total: 10, correct: 4),   // 0.4
            session(id: "prev", daysAgo: 9, total: 10, correct: 9)    // 0.9
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.trend, .declined)
    }

    func test_loadProgress_trendSteady_whenChangeBelowThreshold() async throws {
        let sessions = [
            session(id: "this", daysAgo: 1, total: 10, correct: 7),   // 0.7
            session(id: "prev", daysAgo: 9, total: 10, correct: 7)    // 0.7 (delta 0)
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.trend, .steady)
    }

    // MARK: - Focus sound (dominant by session count)

    func test_loadProgress_focusSoundIsMostPracticedThisWeek() async throws {
        let sessions = [
            session(id: "s1", daysAgo: 1, sound: "Ш", correct: 7),
            session(id: "s2", daysAgo: 2, sound: "Ш", correct: 6),
            session(id: "s3", daysAgo: 3, sound: "Р", correct: 5)
        ]
        let sut = makeSUT(children: [child(sounds: ["Р", "Ш"])], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.focusSound, "Ш", "Звук с наибольшим числом сессий")
    }

    func test_loadProgress_focusSoundRateUsesFocusSessionsOnly() async throws {
        // Ш: точности 0.8 и 0.6 → 0.7; Р: 0.2 — не должно влиять на focusRate.
        let sessions = [
            session(id: "s1", daysAgo: 1, sound: "Ш", total: 10, correct: 8),
            session(id: "s2", daysAgo: 2, sound: "Ш", total: 10, correct: 6),
            session(id: "s3", daysAgo: 3, sound: "Р", total: 10, correct: 2)
        ]
        let sut = makeSUT(children: [child(sounds: ["Р", "Ш"])], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.focusSound, "Ш")
        XCTAssertEqual(response.focusSoundRate, 0.7, accuracy: 0.0001)
    }

    func test_loadProgress_noWeekSessions_focusFallsBackToTargetSound() async throws {
        // Сессии только старые → нет недельных → focusSound = первый target.
        let sessions = [session(id: "old", daysAgo: 20, sound: "Р", correct: 5)]
        let sut = makeSUT(children: [child(sounds: ["Л"])], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.focusSound, "Л")
    }

    // MARK: - Month-ago window

    func test_loadProgress_monthAgoRateUsesSessionsAround30DaysBack() async throws {
        // Окно «месяц назад»: [-37 дней; -30 дней).
        let sessions = [
            session(id: "month", daysAgo: 33, total: 10, correct: 5), // 0.5
            session(id: "this", daysAgo: 1, total: 10, correct: 9)
        ]
        let sut = makeSUT(children: [child()], sessions: sessions)

        let response = try await sut.loadProgress(childId: "c-1")

        XCTAssertEqual(response.monthAgoSuccessRate, 0.5, accuracy: 0.0001)
    }
}
