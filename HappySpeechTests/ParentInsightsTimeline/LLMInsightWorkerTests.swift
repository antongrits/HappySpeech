@testable import HappySpeech
import XCTest

// MARK: - LLMInsightWorkerTests
//
// Покрывает: enrich(insights:childName:) — LLM-обогащение инсайтов.

// MARK: - SpyLocalLLMService

private final class SpyLocalLLMService: LocalLLMService, @unchecked Sendable {
    var isModelDownloaded: Bool = true
    var isModelLoaded: Bool = true
    var shouldFail: Bool = false
    var stubbedSummary: String = "Отличная работа сегодня!"
    private(set) var callCount: Int = 0

    func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
        callCount += 1
        if shouldFail { throw AppError.realmReadFailed("LLM stub fail") }
        return ParentSummaryResponse(parentSummary: stubbedSummary, homeTask: "Повтори дома")
    }

    func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
        RoutePlannerResponse(route: [], sessionMaxDurationSec: 600)
    }

    func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
        MicroStoryResponse(sentences: [], gapPositions: [])
    }

    func downloadModel() async throws {}
}

// MARK: - DailyInsight builder helper

private func makeInsight(
    id: String = "2024-01-01",
    sessionCount: Int = 1,
    minutesPracticed: Int = 10,
    successRate: Double = 0.8,
    severity: InsightSeverity = .positive,
    llmComment: String? = nil,
    isToday: Bool = false
) -> DailyInsight {
    DailyInsight(
        id: id,
        day: Date(),
        weekdayShort: "Пн",
        sessionCount: sessionCount,
        minutesPracticed: minutesPracticed,
        successRate: successRate,
        severity: severity,
        llmComment: llmComment,
        isToday: isToday
    )
}

// MARK: - Tests

@MainActor
final class LLMInsightWorkerTests: XCTestCase {

    // MARK: - Модель не загружена

    func test_enrich_whenModelNotDownloaded_returnsSameInsightsAndFalse() async {
        let llm = SpyLocalLLMService()
        llm.isModelDownloaded = false
        let sut = LLMInsightWorker(localLLM: llm)
        let insights = [makeInsight(sessionCount: 1)]

        let (result, usedLLM) = await sut.enrich(insights: insights, childName: "Маша")

        XCTAssertEqual(result, insights, "При незагруженной модели инсайты не должны меняться")
        XCTAssertFalse(usedLLM, "При незагруженной модели usedLLM должен быть false")
        XCTAssertEqual(llm.callCount, 0, "LLM не должен вызываться при незагруженной модели")
    }

    // MARK: - Пустые инсайты

    func test_enrich_whenNoInsights_returnsEmptyAndFalse() async {
        let llm = SpyLocalLLMService()
        let sut = LLMInsightWorker(localLLM: llm)

        let (result, usedLLM) = await sut.enrich(insights: [], childName: "Маша")

        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(usedLLM)
        XCTAssertEqual(llm.callCount, 0)
    }

    // MARK: - Нет активных дней (sessionCount = 0)

    func test_enrich_whenAllSessionCountZero_doesNotCallLLM() async {
        let llm = SpyLocalLLMService()
        let sut = LLMInsightWorker(localLLM: llm)
        let insights = [makeInsight(sessionCount: 0), makeInsight(id: "2024-01-02", sessionCount: 0)]

        let (_, usedLLM) = await sut.enrich(insights: insights, childName: "Маша")

        XCTAssertFalse(usedLLM)
        XCTAssertEqual(llm.callCount, 0, "LLM не должен вызываться для дней без сессий")
    }

    // MARK: - Успешное обогащение

    func test_enrich_whenModelAvailableAndSessionsPresent_setsLLMComment() async {
        let llm = SpyLocalLLMService()
        llm.stubbedSummary = "Маша хорошо поработала!"
        let sut = LLMInsightWorker(localLLM: llm)
        let insight = makeInsight(id: "2024-01-01", sessionCount: 2, successRate: 0.85)
        let insights = [insight]

        let (result, usedLLM) = await sut.enrich(insights: insights, childName: "Маша")

        XCTAssertTrue(usedLLM, "При успешном LLM-вызове usedLLM должен быть true")
        XCTAssertEqual(result.first?.llmComment, "Маша хорошо поработала!",
                       "llmComment должен быть установлен из LLM-ответа")
    }

    func test_enrich_preservesOtherFields_whenEnriching() async {
        let llm = SpyLocalLLMService()
        let sut = LLMInsightWorker(localLLM: llm)
        let originalInsight = makeInsight(
            id: "2024-01-01",
            sessionCount: 1,
            minutesPracticed: 15,
            successRate: 0.7,
            severity: .neutral
        )

        let (result, _) = await sut.enrich(insights: [originalInsight], childName: "Маша")

        let enriched = result.first!
        XCTAssertEqual(enriched.id, originalInsight.id)
        XCTAssertEqual(enriched.minutesPracticed, 15)
        XCTAssertEqual(enriched.successRate, 0.7, accuracy: 0.001)
        XCTAssertEqual(enriched.severity, .neutral)
    }

    // MARK: - Максимум 3 LLM-вызова

    func test_enrich_callsLLMNoMoreThan3Times() async {
        let llm = SpyLocalLLMService()
        let sut = LLMInsightWorker(localLLM: llm)
        var insights: [DailyInsight] = []
        for i in 0..<7 {
            insights.append(makeInsight(id: "2024-01-0\(i+1)", sessionCount: 2, successRate: 0.5))
        }

        _ = await sut.enrich(insights: insights, childName: "Маша")

        XCTAssertLessThanOrEqual(llm.callCount, 3,
                                  "LLM должен вызываться не более 3 раз за один рефреш")
    }

    // MARK: - LLM завершается ошибкой

    func test_enrich_whenLLMFails_keepOriginalInsight() async {
        let llm = SpyLocalLLMService()
        llm.shouldFail = true
        let sut = LLMInsightWorker(localLLM: llm)
        let original = makeInsight(id: "2024-01-01", sessionCount: 2, llmComment: nil)

        let (result, usedLLM) = await sut.enrich(insights: [original], childName: "Маша")

        XCTAssertFalse(usedLLM, "При ошибке LLM usedLLM должен быть false")
        XCTAssertNil(result.first?.llmComment, "llmComment не должен устанавливаться при ошибке")
    }

    // MARK: - Пустой ответ от LLM игнорируется

    func test_enrich_whenLLMReturnsEmpty_doesNotSetComment() async {
        let llm = SpyLocalLLMService()
        llm.stubbedSummary = "   " // только пробелы
        let sut = LLMInsightWorker(localLLM: llm)
        let insight = makeInsight(id: "2024-01-01", sessionCount: 2)

        let (result, usedLLM) = await sut.enrich(insights: [insight], childName: "Маша")

        XCTAssertFalse(usedLLM, "Пустой LLM-ответ не должен помечаться как usedLLM=true")
        XCTAssertNil(result.first?.llmComment, "Пустой LLM-ответ не должен устанавливать llmComment")
    }
}
