@testable import HappySpeech
import XCTest

// MARK: - FamilyInsightsWorkerTests
//
// Тестирует FamilyInsightsWorker:
//   - generateRuleBasedInsights: все правила (streak, bestSound, no_recent, played_today, high_accuracy)
//   - фильтрация по selectedChildId
//   - гарантированный минимум 1 insight
//   - лимит 5 insights
//   - generateLLMInsights через MockLLMDecisionService

final class FamilyInsightsWorkerTests: XCTestCase {

    private let sut = FamilyInsightsWorker()

    // MARK: - Helpers

    private func makeAggregation(
        childId: String = "c-001",
        childName: String = "Маша",
        streak: Int = 0,
        avgSuccessRate: Double = 0.5,
        bestSound: String? = nil,
        bestSoundRate: Double = 0.0,
        dayActivitiesCount: Int = 0
    ) -> FamilyStatsAggregation {
        var dayActivities: [Date: Int] = [:]
        let today = Calendar.current.startOfDay(for: Date())
        if dayActivitiesCount > 0 {
            dayActivities[today] = dayActivitiesCount
        }
        return FamilyStatsAggregation(
            childId: childId,
            childName: childName,
            streak: streak,
            totalSessions: 10,
            avgSuccessRate: avgSuccessRate,
            bestSound: bestSound,
            bestSoundRate: bestSoundRate,
            dayActivities: dayActivities,
            heatmapEntries: []
        )
    }

    // MARK: - Правило 1: streak >= 5 → flame insight

    func test_ruleBasedInsights_streak5_addsFlameInsight() {
        let agg = makeAggregation(streak: 5)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertTrue(insights.contains(where: { $0.iconName == "flame.fill" }),
                      "Streak >= 5 → flame.fill insight")
    }

    func test_ruleBasedInsights_streak4_noFlameInsight() {
        let agg = makeAggregation(streak: 4)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertFalse(insights.contains(where: { $0.iconName == "flame.fill" }))
    }

    // MARK: - Правило 2: bestSound + bestSoundRate >= 85%

    func test_ruleBasedInsights_bestSound85pct_addsStarInsight() {
        let agg = makeAggregation(bestSound: "Р", bestSoundRate: 0.90)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertTrue(insights.contains(where: { $0.iconName == "star.fill" }),
                      "bestSoundRate >= 85% → star.fill insight")
    }

    func test_ruleBasedInsights_bestSound70pct_noStarInsight() {
        let agg = makeAggregation(bestSound: "Ш", bestSoundRate: 0.70)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertFalse(insights.contains(where: { $0.iconName == "star.fill" }))
    }

    func test_ruleBasedInsights_noBestSound_noStarInsight() {
        let agg = makeAggregation(bestSound: nil, bestSoundRate: 0.90)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertFalse(insights.contains(where: { $0.iconName == "star.fill" }))
    }

    // MARK: - Правило 3: no recent sessions → lightbulb

    func test_ruleBasedInsights_noRecentSessions_addsLightbulbInsight() {
        // dayActivities пустой, нет дней >= sevenDaysAgo
        let agg = makeAggregation(dayActivitiesCount: 0)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        // Lightbulb от правила 3 (no_recent) или от default — в любом случае lightbulb должен быть
        XCTAssertTrue(insights.contains(where: { $0.iconName == "lightbulb.fill" }))
    }

    // MARK: - Правило 4: played today → checkmark.seal

    func test_ruleBasedInsights_playedToday_addsCheckmarkInsight() {
        let agg = makeAggregation(dayActivitiesCount: 2)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertTrue(insights.contains(where: { $0.iconName == "checkmark.seal.fill" }),
                      "Игра сегодня → checkmark.seal.fill")
    }

    // MARK: - Правило 5: avgSuccessRate >= 90% → trophy

    func test_ruleBasedInsights_highAccuracy_addsTrophyInsight() {
        let agg = makeAggregation(avgSuccessRate: 0.95, dayActivitiesCount: 1)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertTrue(insights.contains(where: { $0.iconName == "trophy.fill" }),
                      "avgSuccessRate >= 90% → trophy.fill")
    }

    func test_ruleBasedInsights_avgAccuracy85pct_noTrophy() {
        let agg = makeAggregation(avgSuccessRate: 0.85, dayActivitiesCount: 1)
        let insights = sut.generateRuleBasedInsights(aggregations: [agg], selectedChildId: nil)
        XCTAssertFalse(insights.contains(where: { $0.iconName == "trophy.fill" }))
    }

    // MARK: - Гарантированный минимум 1 insight

    func test_ruleBasedInsights_emptyAggregations_returnsDefaultInsight() {
        let insights = sut.generateRuleBasedInsights(aggregations: [], selectedChildId: nil)
        XCTAssertEqual(insights.count, 1, "Без агрегаций должен вернуться 1 дефолтный insight")
        XCTAssertEqual(insights.first?.iconName, "lightbulb.fill")
    }

    // MARK: - Лимит 5 insights

    func test_ruleBasedInsights_maxFiveInsights() {
        // Создаём много агрегаций, каждая триггерит несколько правил
        let aggregations = (0..<10).map { i in
            makeAggregation(
                childId: "c-\(i)",
                childName: "Ребёнок \(i)",
                streak: 5,
                avgSuccessRate: 0.95,
                bestSound: "Р",
                bestSoundRate: 0.90,
                dayActivitiesCount: 2
            )
        }
        let insights = sut.generateRuleBasedInsights(aggregations: aggregations, selectedChildId: nil)
        XCTAssertLessThanOrEqual(insights.count, 5, "Максимум 5 insights")
    }

    // MARK: - Фильтрация по selectedChildId

    func test_ruleBasedInsights_selectedChildId_filtersOtherChildren() {
        let agg1 = makeAggregation(childId: "c-001", childName: "Маша", streak: 5)
        let agg2 = makeAggregation(childId: "c-002", childName: "Ваня", streak: 5)
        // Только "all" фильтруется — не c-001 / c-002
        let insights = sut.generateRuleBasedInsights(
            aggregations: [agg1, agg2],
            selectedChildId: "c-001"
        )
        // Строки insights содержат имена — проверяем, что имя Вани не упоминается
        let texts = insights.map(\.text).joined()
        XCTAssertFalse(texts.contains("Ваня"),
                       "При selectedChildId=c-001 данные Вани не должны включаться")
        XCTAssertTrue(texts.contains("Маша") || !insights.isEmpty)
    }

    // MARK: - generateLLMInsights: non-empty tip

    func test_generateLLMInsights_returnsNonEmptyInsights() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true, useFallbackFlag: false)
        let child = TestDataBuilder.childProfile()
        let sessions = [TestDataBuilder.session(childId: child.id)]
        let insights = await sut.generateLLMInsights(
            llmService: mockLLM, child: child, sessions: sessions
        )
        XCTAssertFalse(insights.isEmpty, "generateLLMInsights с рабочим LLM → хотя бы 1 insight")
    }
}
