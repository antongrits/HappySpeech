import Foundation
import OSLog

// MARK: - ParentInsightsTimelineBusinessLogic

@MainActor
protocol ParentInsightsTimelineBusinessLogic: AnyObject {
    func load(request: ParentInsightsTimelineModels.Load.Request) async
    func selectDay(request: ParentInsightsTimelineModels.SelectDay.Request) async
    func refresh(request: ParentInsightsTimelineModels.Refresh.Request) async
}

// MARK: - ParentInsightsTimelineDataStore

@MainActor
protocol ParentInsightsTimelineDataStore: AnyObject {
    var currentInsights: [DailyInsight] { get set }
    var currentChildName: String { get set }
}

// MARK: - ParentInsightsTimelineInteractor (Clean Swift: Interactor)
//
// Block AE batch 2 v21 — Weekly Insights Timeline для родителя.
//
// Ответственность:
//   • Собрать 7-дневный набор инсайтов через ``InsightAggregatorWorker``.
//   • Дополнить top-3 дня LLM-комментариями через ``LLMInsightWorker``.
//   • Подсчитать summary недели.
//   • Передать detail-vm в Presenter при выборе конкретного дня.
//
// COPPA: вся фича — только parent-контур; ребёнок никогда не видит экран
// или LLM-сводки о себе в текстовой форме.

@MainActor
final class ParentInsightsTimelineInteractor: ParentInsightsTimelineBusinessLogic,
    ParentInsightsTimelineDataStore {

    // MARK: - DataStore

    var currentInsights: [DailyInsight] = []
    var currentChildName: String = ""

    // MARK: - VIP

    var presenter: (any ParentInsightsTimelinePresentationLogic)?

    // MARK: - Workers

    private let aggregator: any InsightAggregatorWorkerProtocol
    private let llmWorker: any LLMInsightWorkerProtocol
    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInsightsTimeline.Interactor"
    )

    // MARK: - Init

    init(
        aggregator: any InsightAggregatorWorkerProtocol,
        llmWorker: any LLMInsightWorkerProtocol,
        childRepository: any ChildRepository
    ) {
        self.aggregator = aggregator
        self.llmWorker = llmWorker
        self.childRepository = childRepository
    }

    // MARK: - Load

    func load(request: ParentInsightsTimelineModels.Load.Request) async {
        Self.logger.info("load child=\(request.childId, privacy: .private)")

        let childName: String
        do {
            let profile = try await childRepository.fetch(id: request.childId)
            childName = profile.name
        } catch {
            Self.logger.error("load: fetch child failed: \(error.localizedDescription, privacy: .public)")
            childName = "—"
        }
        currentChildName = childName

        let raw = await aggregator.buildWeek(childId: request.childId, endingOn: request.weekEndingOn)
        let (enriched, usedLLM) = await llmWorker.enrich(insights: raw, childName: childName)
        currentInsights = enriched

        let summary = aggregator.summary(from: enriched)
        let response = ParentInsightsTimelineModels.Load.Response(
            insights: enriched,
            summary: summary,
            childName: childName,
            usedLLM: usedLLM
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - SelectDay

    func selectDay(request: ParentInsightsTimelineModels.SelectDay.Request) async {
        guard let insight = currentInsights.first(where: { $0.id == request.dayId }) else {
            Self.logger.warning("selectDay: unknown id \(request.dayId, privacy: .public)")
            return
        }
        let detail: String
        if let llm = insight.llmComment, !llm.isEmpty {
            detail = llm
        } else {
            detail = WeekTimelineBuilder.heuristicComment(
                sessionCount: insight.sessionCount,
                minutes: insight.minutesPracticed,
                successRate: insight.successRate,
                isToday: insight.isToday
            )
        }
        let response = ParentInsightsTimelineModels.SelectDay.Response(
            insight: insight,
            detail: detail
        )
        await presenter?.presentSelectDay(response: response)
    }

    // MARK: - Refresh

    func refresh(request: ParentInsightsTimelineModels.Refresh.Request) async {
        Self.logger.info("refresh child=\(request.childId, privacy: .private)")
        await load(request: .init(childId: request.childId, weekEndingOn: Date()))
        let response = ParentInsightsTimelineModels.Refresh.Response(
            success: true,
            toastKey: "parentInsightsTimeline.refresh.toast.success"
        )
        await presenter?.presentRefresh(response: response)
    }
}
