@testable import HappySpeech
import XCTest

// MARK: - InsightAggregatorWorkerTests
//
// Тестирует InsightAggregatorWorker через SpySessionRepository.
// buildWeek: загрузка сессий, группировка по дням, severity.
// summary: агрегация totalSessions, totalMinutes, averageSuccessRate, activeDays, bestDayId.

@MainActor
final class InsightAggregatorWorkerTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(
        childId: String = "c-001",
        daysAgo: Int,
        totalAttempts: Int = 10,
        correctAttempts: Int = 8,
        durationSeconds: Int = 300
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: date,
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: "Р",
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: durationSeconds,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    private func makeSUT(sessions: [SessionDTO] = []) -> (InsightAggregatorWorker, SpySessionRepository) {
        let repo = SpySessionRepository(sessions: sessions)
        let worker = InsightAggregatorWorker(sessionRepository: repo)
        return (worker, repo)
    }

    // MARK: - buildWeek: returns 7 days

    func test_buildWeek_returnsSeven() async {
        let (sut, _) = makeSUT()
        let insights = await sut.buildWeek(childId: "c-001", endingOn: Date())
        XCTAssertEqual(insights.count, 7, "buildWeek должен возвращать 7 DailyInsight")
    }

    // MARK: - buildWeek: repository failure → empty sessions → 7 zero-insight days

    func test_buildWeek_repoFailure_returnsSevenNeutralDays() async {
        let repo = SpySessionRepository()
        repo.shouldFail = true
        let sut = InsightAggregatorWorker(sessionRepository: repo)
        let insights = await sut.buildWeek(childId: "c-001", endingOn: Date())
        XCTAssertEqual(insights.count, 7)
        XCTAssertTrue(insights.allSatisfy { $0.sessionCount == 0 })
    }

    // MARK: - buildWeek: today's session counted

    func test_buildWeek_todaySession_countedInTodaySlot() async {
        let session = makeSession(childId: "c-001", daysAgo: 0, durationSeconds: 600)
        let (sut, _) = makeSUT(sessions: [session])
        let insights = await sut.buildWeek(childId: "c-001", endingOn: Date())
        let today = insights.first(where: { $0.isToday })
        XCTAssertNotNil(today, "Должен быть слот isToday=true")
        XCTAssertEqual(today?.sessionCount, 1, "1 сессия сегодня → sessionCount=1")
        XCTAssertEqual(today?.minutesPracticed, 10, "600 сек = 10 минут")
    }

    // MARK: - buildWeek: session 8 days ago not counted

    func test_buildWeek_oldSession_notCountedInWeek() async {
        let session = makeSession(childId: "c-001", daysAgo: 8)
        let (sut, _) = makeSUT(sessions: [session])
        let insights = await sut.buildWeek(childId: "c-001", endingOn: Date())
        XCTAssertTrue(insights.allSatisfy { $0.sessionCount == 0 },
                      "Сессия 8 дней назад не должна попасть в недельный отчёт")
    }

    // MARK: - buildWeek: successRate calculated

    func test_buildWeek_successRate_calculatedCorrectly() async {
        // 10 total / 8 correct = 0.8
        let session = makeSession(childId: "c-001", daysAgo: 0, totalAttempts: 10, correctAttempts: 8)
        let (sut, _) = makeSUT(sessions: [session])
        let insights = await sut.buildWeek(childId: "c-001", endingOn: Date())
        let today = insights.first(where: { $0.isToday })
        XCTAssertEqual(today?.successRate ?? -1, 0.8, accuracy: 0.001)
    }

    // MARK: - buildWeek: no sessions for day → successRate = 0

    func test_buildWeek_noSessionsForDay_successRateZero() async {
        let (sut, _) = makeSUT()
        let insights = await sut.buildWeek(childId: "c-001", endingOn: Date())
        let allZero = insights.allSatisfy { $0.successRate == 0 }
        XCTAssertTrue(allZero)
    }

    // MARK: - summary: totalSessions

    func test_summary_totalSessions_summed() {
        let (sut, _) = makeSUT()
        let insights: [DailyInsight] = [
            makeInsight(sessionCount: 3),
            makeInsight(sessionCount: 2),
            makeInsight(sessionCount: 0)
        ]
        let summary = sut.summary(from: insights)
        XCTAssertEqual(summary.totalSessions, 5)
    }

    func test_summary_totalMinutes_summed() {
        let (sut, _) = makeSUT()
        let insights: [DailyInsight] = [
            makeInsight(minutes: 10),
            makeInsight(minutes: 15),
            makeInsight(minutes: 0)
        ]
        let summary = sut.summary(from: insights)
        XCTAssertEqual(summary.totalMinutes, 25)
    }

    // MARK: - summary: activeDays (sessionCount > 0)

    func test_summary_activeDays_onlyPositiveSessions() {
        let (sut, _) = makeSUT()
        let insights: [DailyInsight] = [
            makeInsight(sessionCount: 1),
            makeInsight(sessionCount: 0),
            makeInsight(sessionCount: 2)
        ]
        let summary = sut.summary(from: insights)
        XCTAssertEqual(summary.activeDays, 2, "activeDays считает только дни с sessionCount > 0")
    }

    // MARK: - summary: averageSuccessRate

    func test_summary_averageSuccessRate_onlyActiveDays() {
        let (sut, _) = makeSUT()
        let insights: [DailyInsight] = [
            makeInsight(sessionCount: 1, successRate: 0.8),
            makeInsight(sessionCount: 0, successRate: 0.0), // не участвует
            makeInsight(sessionCount: 1, successRate: 0.6)
        ]
        let summary = sut.summary(from: insights)
        XCTAssertEqual(summary.averageSuccessRate, 0.7, accuracy: 0.001)
    }

    func test_summary_noActiveDays_averageIsZero() {
        let (sut, _) = makeSUT()
        let insights: [DailyInsight] = [makeInsight(sessionCount: 0)]
        let summary = sut.summary(from: insights)
        XCTAssertEqual(summary.averageSuccessRate, 0.0)
    }

    // MARK: - summary: bestDayId

    func test_summary_bestDayId_highestSuccessRate() {
        let (sut, _) = makeSUT()
        let insights: [DailyInsight] = [
            makeInsight(id: "2026-05-13", sessionCount: 1, successRate: 0.6),
            makeInsight(id: "2026-05-14", sessionCount: 1, successRate: 0.95),
            makeInsight(id: "2026-05-15", sessionCount: 1, successRate: 0.7)
        ]
        let summary = sut.summary(from: insights)
        XCTAssertEqual(summary.bestDayId, "2026-05-14", "Лучший день — с наибольшим successRate")
    }

    func test_summary_emptyInsights_bestDayNil() {
        let (sut, _) = makeSUT()
        let summary = sut.summary(from: [])
        XCTAssertNil(summary.bestDayId)
    }

    // MARK: - Private factory

    private func makeInsight(
        id: String = UUID().uuidString,
        sessionCount: Int = 0,
        minutes: Int = 0,
        successRate: Double = 0.0
    ) -> DailyInsight {
        DailyInsight(
            id: id,
            day: Date(),
            weekdayShort: "Пн",
            sessionCount: sessionCount,
            minutesPracticed: minutes,
            successRate: successRate,
            severity: .neutral,
            llmComment: nil,
            isToday: false
        )
    }
}
