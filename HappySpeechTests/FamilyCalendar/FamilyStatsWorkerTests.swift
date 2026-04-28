@testable import HappySpeech
import XCTest

// MARK: - FamilyStatsWorkerTests
//
// 5 unit-тестов для FamilyStatsWorker (F3-005).
// Чистая вычислительная логика — не обращается к Realm.

final class FamilyStatsWorkerTests: XCTestCase {

    // MARK: - SUT

    private let sut = FamilyStatsWorker()

    // MARK: - Helpers

    private func makeChild(
        id: String,
        name: String = "Тест",
        progressSummary: [String: Double] = [:]
    ) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: 6,
            targetSounds: ["Р"],
            parentId: "parent-1",
            progressSummary: progressSummary
        )
    }

    private func makeSession(
        childId: String,
        daysAgo: Int,
        totalAttempts: Int = 10,
        correct: Int = 8
    ) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            templateType: "listen-and-choose",
            targetSound: "Р",
            stage: "word",
            durationSeconds: 300,
            totalAttempts: totalAttempts,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    // MARK: - 11. aggregateMonth — корректный уровень активности для дня с 5 сессиями

    func test_aggregateMonth_correctActivityLevel() {
        let child = makeChild(id: "c-1")
        // 5 сессий сегодня — ожидаем activityLevel=4 (today+active) или 2 (4-6)
        var sessions: [SessionDTO] = []
        for _ in 0..<5 {
            sessions.append(makeSession(childId: "c-1", daysAgo: 0))
        }

        let agg = sut.aggregate(child: child, sessions: sessions)

        let calendar = Calendar.current
        let todayNorm = calendar.startOfDay(for: Date())
        XCTAssertEqual(agg.dayActivities[todayNorm], 5,
                       "dayActivities[today] должен быть 5")

        // buildCalendarDays проверяем activityLevel
        let calDays = sut.buildCalendarDays(month: Date(), dayActivities: agg.dayActivities)
        let todayCell = calDays.first {
            calendar.startOfDay(for: $0.date) == todayNorm && $0.isCurrentMonth
        }
        // activityLevel для today+5 сессий = 4 (today && count>0)
        XCTAssertEqual(todayCell?.activityLevel, 4,
                       "activityLevel должен быть 4 для сегодняшнего дня с сессиями")
    }

    // MARK: - 12. heatmapCells — правильная шкала интенсивности

    func test_heatmapCells_correctIntensityScale() {
        let child = makeChild(id: "c-1")
        // 1 сессия 3 дня назад — sessionCount=1 → activityLevel=1
        let session = makeSession(childId: "c-1", daysAgo: 3)
        let agg = sut.aggregate(child: child, sessions: [session])

        let calendar = Calendar.current
        let threeDaysAgo = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -3, to: Date())!
        )

        // В heatmap ищем тот день
        let entry = agg.heatmapEntries.first {
            calendar.startOfDay(for: $0.date) == threeDaysAgo
        }
        XCTAssertNotNil(entry, "heatmap должен содержать запись для 3 дней назад")
        XCTAssertEqual(entry?.sessionCount, 1,
                       "sessionCount должен быть 1 для этого дня")
    }

    // MARK: - 13. compareChildren — лидер имеет наибольший avgSuccessRate

    func test_compareChildren_findsBestSoundDelta() {
        let childA = makeChild(id: "c-a", name: "Аня", progressSummary: ["Р": 0.90, "Ш": 0.60])
        let childB = makeChild(id: "c-b", name: "Боря", progressSummary: ["Р": 0.50, "Ш": 0.40])

        // Сессии с высокой точностью для Ани (correct=9/10) и низкой для Бори (correct=4/10)
        let sessionsA = (0..<3).map { _ in makeSession(childId: "c-a", daysAgo: 1, totalAttempts: 10, correct: 9) }
        let sessionsB = (0..<3).map { _ in makeSession(childId: "c-b", daysAgo: 1, totalAttempts: 10, correct: 4) }

        let aggA = sut.aggregate(child: childA, sessions: sessionsA)
        let aggB = sut.aggregate(child: childB, sessions: sessionsB)

        XCTAssertGreaterThan(aggA.avgSuccessRate, aggB.avgSuccessRate,
                             "avgSuccessRate Ани должен быть выше чем у Бори")

        // Лучший звук Ани — «Р» (0.90)
        XCTAssertEqual(aggA.bestSound, "Р",
                       "bestSound для Ани должен быть «Р» (max progressSummary)")
        XCTAssertEqual(aggA.bestSoundRate, 0.90, accuracy: 0.001,
                       "bestSoundRate должен быть 0.90")
    }

    // MARK: - 14. streakDays — consecutive days считается корректно

    func test_streakDays_consecutiveDays() {
        let child = makeChild(id: "c-1")
        // 5 последовательных дней включая сегодня
        var sessions: [SessionDTO] = []
        for day in 0..<5 {
            sessions.append(makeSession(childId: "c-1", daysAgo: day))
        }

        let agg = sut.aggregate(child: child, sessions: sessions)

        XCTAssertEqual(agg.streak, 5,
                       "Streak должен быть 5 при 5 последовательных днях включая сегодня")
    }

    // MARK: - 15. emptyChild — нет сессий → нулевая статистика

    func test_emptyChild_returnsZeroStats() {
        let child = makeChild(id: "c-empty")
        let agg = sut.aggregate(child: child, sessions: [])

        XCTAssertEqual(agg.totalSessions, 0,
                       "totalSessions должен быть 0 при отсутствии сессий")
        XCTAssertEqual(agg.avgSuccessRate, 0.0, accuracy: 0.001,
                       "avgSuccessRate должен быть 0.0 при отсутствии сессий")
        XCTAssertEqual(agg.streak, 0,
                       "streak должен быть 0 при отсутствии сессий")
        XCTAssertTrue(agg.dayActivities.isEmpty,
                      "dayActivities должен быть пустым при отсутствии сессий")
    }
}
