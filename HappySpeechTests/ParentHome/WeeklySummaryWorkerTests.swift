@testable import HappySpeech
import XCTest

// MARK: - WeeklySummaryWorkerTests
//
// Покрывает buildWeekStats и weekTrend (чистая логика без I/O),
// а также generateWeeklyInsight Tier C и Tier B через MockLLMDecisionService.

@MainActor
final class WeeklySummaryWorkerTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(
        childId: String = "c-001",
        daysAgo: Int,
        durationSeconds: Int = 180,
        totalAttempts: Int = 10,
        correctAttempts: Int = 8,
        sound: String = "Р"
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: date,
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: durationSeconds,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    // MARK: - buildWeekStats

    func test_buildWeekStats_returnsSevenDays() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let stats = sut.buildWeekStats(sessions: [])
        XCTAssertEqual(stats.count, 7, "buildWeekStats должен возвращать ровно 7 элементов")
    }

    func test_buildWeekStats_emptySessions_allZeroMinutes() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let stats = sut.buildWeekStats(sessions: [])
        XCTAssertTrue(stats.allSatisfy { $0.minutes == 0 }, "Без сессий всё minutes = 0")
    }

    func test_buildWeekStats_todaySession_countedInFirstDay() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let session = makeSession(daysAgo: 0, durationSeconds: 300)
        let stats = sut.buildWeekStats(sessions: [session])
        // Last element == today (reversed array ends at today)
        XCTAssertGreaterThan(stats.last?.minutes ?? 0, 0,
                             "Сессия сегодня должна попасть в последний DayStat")
    }

    func test_buildWeekStats_oldSession_notCountedInWeek() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let session = makeSession(daysAgo: 10, durationSeconds: 300)
        let stats = sut.buildWeekStats(sessions: [session])
        XCTAssertTrue(stats.allSatisfy { $0.minutes == 0 },
                      "Сессия старше 7 дней не должна попасть в статистику недели")
    }

    func test_buildWeekStats_multipleSessions_sameDayAdded() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let s1 = makeSession(daysAgo: 1, durationSeconds: 120)
        let s2 = makeSession(daysAgo: 1, durationSeconds: 180)
        let stats = sut.buildWeekStats(sessions: [s1, s2])
        // Вчера — предпоследний элемент (reversed, 0=today, 6=6 дней назад → last-1 = 1 день назад)
        let yesterday = stats.dropLast().last
        XCTAssertEqual(yesterday?.minutes, 5, "120+180=300сек=5мин за вчера")
    }

    func test_buildWeekStats_accuracyAveragesCorrectly() {
        let sut = WeeklySummaryWorker(llmService: nil)
        // 10 total / 8 correct = 0.8; 10 total / 6 correct = 0.6 → avg = 0.7
        let s1 = makeSession(daysAgo: 0, totalAttempts: 10, correctAttempts: 8)
        let s2 = makeSession(daysAgo: 0, totalAttempts: 10, correctAttempts: 6)
        let stats = sut.buildWeekStats(sessions: [s1, s2])
        let todayAccuracy = stats.last?.accuracy ?? -1
        XCTAssertEqual(todayAccuracy, 0.7, accuracy: 0.01, "Средняя точность дня должна быть 0.7")
    }

    // MARK: - weekTrend

    func test_weekTrend_insufficientActiveDays_returnsStable() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let stats = sut.buildWeekStats(sessions: []) // все нулевые
        let trend = sut.weekTrend(from: stats)
        XCTAssertEqual(trend, .stable, "Менее 2 активных дней → stable")
    }

    func test_weekTrend_improving_returnsUp() {
        let sut = WeeklySummaryWorker(llmService: nil)
        // Создаём DayStat вручную: первая половина низкая, вторая высокая
        let now = Date()
        let makeDayStat: (Double, Int) -> ParentHomeModels.DayStat = { accuracy, daysAgo in
            let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return ParentHomeModels.DayStat(date: d, minutes: 5, accuracy: accuracy, sessionsCount: 1)
        }
        let stats = [
            makeDayStat(0.50, 6), makeDayStat(0.50, 5), makeDayStat(0.50, 4),
            makeDayStat(0.90, 3), makeDayStat(0.90, 2), makeDayStat(0.90, 1), makeDayStat(0.90, 0)
        ]
        let trend = sut.weekTrend(from: stats)
        XCTAssertEqual(trend, .up, "Рост точности во второй половине недели → .up")
    }

    func test_weekTrend_declining_returnsDown() {
        let sut = WeeklySummaryWorker(llmService: nil)
        let now = Date()
        let makeDayStat: (Double, Int) -> ParentHomeModels.DayStat = { accuracy, daysAgo in
            let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return ParentHomeModels.DayStat(date: d, minutes: 5, accuracy: accuracy, sessionsCount: 1)
        }
        let stats = [
            makeDayStat(0.90, 6), makeDayStat(0.90, 5), makeDayStat(0.90, 4),
            makeDayStat(0.50, 3), makeDayStat(0.50, 2), makeDayStat(0.50, 1), makeDayStat(0.50, 0)
        ]
        let trend = sut.weekTrend(from: stats)
        XCTAssertEqual(trend, .down, "Падение точности → .down")
    }

    // MARK: - generateWeeklyInsight Tier C (llmService=nil)

    func test_generateWeeklyInsight_nilLLM_returnsRuleBasedInsight() async {
        let sut = WeeklySummaryWorker(llmService: nil)
        let sessions = [makeSession(daysAgo: 0, totalAttempts: 10, correctAttempts: 9)]
        let stats = sut.buildWeekStats(sessions: sessions)
        let insight = await sut.generateWeeklyInsight(
            childName: "Маша", sessions: sessions, dayStat: stats
        )
        XCTAssertFalse(insight.summaryText.isEmpty, "Tier C должен вернуть непустой summaryText")
        XCTAssertEqual(insight.source, .ruleBased)
    }

    func test_generateWeeklyInsight_highAccuracy_excellentBranch() async {
        let sut = WeeklySummaryWorker(llmService: nil)
        // accuracy >= 0.85 → excellent branch
        let sessions: [SessionDTO] = (0..<5).map { i in
            makeSession(daysAgo: i, totalAttempts: 10, correctAttempts: 9) // 0.9
        }
        let stats = sut.buildWeekStats(sessions: sessions)
        let insight = await sut.generateWeeklyInsight(
            childName: "Ваня", sessions: sessions, dayStat: stats
        )
        XCTAssertFalse(insight.summaryText.isEmpty)
        XCTAssertFalse(insight.highlights.isEmpty, "Excellent branch должен содержать highlights")
    }

    func test_generateWeeklyInsight_zeroSessions_needsWorkBranch() async {
        let sut = WeeklySummaryWorker(llmService: nil)
        let insight = await sut.generateWeeklyInsight(
            childName: "Петя", sessions: [], dayStat: []
        )
        // 0 сессий → avgAccuracy=0 < 0.60 → needs_work branch
        XCTAssertFalse(insight.summaryText.isEmpty)
        XCTAssertEqual(insight.source, .ruleBased)
    }

    // MARK: - generateWeeklyInsight Tier B (mock LLM, useFallbackFlag=false)

    func test_generateWeeklyInsight_llmAvailable_returnsLLMInsight() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true, useFallbackFlag: false)
        let sut = WeeklySummaryWorker(llmService: mockLLM)
        let sessions = [makeSession(daysAgo: 0)]
        let stats = sut.buildWeekStats(sessions: sessions)
        let insight = await sut.generateWeeklyInsight(
            childName: "Аня", sessions: sessions, dayStat: stats
        )
        XCTAssertFalse(insight.summaryText.isEmpty)
    }

    func test_generateWeeklyInsight_llmFallback_usesRuleBased() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true, useFallbackFlag: true)
        let sut = WeeklySummaryWorker(llmService: mockLLM)
        let sessions = [makeSession(daysAgo: 0)]
        let stats = sut.buildWeekStats(sessions: sessions)
        let insight = await sut.generateWeeklyInsight(
            childName: "Дима", sessions: sessions, dayStat: stats
        )
        // useFallbackFlag=true → tryLLMInsight returns nil → Tier C
        XCTAssertEqual(insight.source, .ruleBased)
    }
}
