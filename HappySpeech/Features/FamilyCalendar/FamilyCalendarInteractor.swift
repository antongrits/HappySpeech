import Foundation
import OSLog

// MARK: - FamilyCalendarInteractor
//
// Бизнес-логика: загрузка детей + сессий, переключение выбранного ребёнка,
// смена месяца, генерация инсайтов через worker.
// Читает данные из репозиториев — не напрямую из Realm.

@MainActor
final class FamilyCalendarInteractor {

    // MARK: - Dependencies

    var presenter: FamilyCalendarPresenter?
    var router: FamilyCalendarRouter?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let llmDecisionService: (any LLMDecisionServiceProtocol)?

    private let insightsWorker = FamilyInsightsWorker()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyCalendarInteractor")

    // MARK: - Internal State

    private var allChildren: [ChildProfileDTO] = []
    private var allSessions: [SessionDTO] = []
    private var selectedChildId: String?
    private var currentMonth: Date = {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        llmDecisionService: (any LLMDecisionServiceProtocol)?
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.llmDecisionService = llmDecisionService
    }

    // MARK: - Use Cases

    func loadFamilyData(request: FamilyCalendarRequest.LoadData) async {
        presenter?.presentLoading(isLoading: true)

        do {
            // Загружаем всех детей (у одного родителя)
            let children = try await childRepository.fetchAll()
            allChildren = children

            // Загружаем сессии за последние 12 недель для каждого ребёнка
            var sessions: [SessionDTO] = []
            let cutoffDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? Date()

            for child in children {
                let childSessions = try await sessionRepository.fetchAll(childId: child.id)
                let recent = childSessions.filter { $0.date >= cutoffDate }
                sessions.append(contentsOf: recent)
            }
            allSessions = sessions

            let response = FamilyCalendarResponse.DataLoaded(
                children: allChildren,
                sessions: allSessions,
                selectedChildId: selectedChildId,
                currentMonth: currentMonth
            )
            presenter?.presentDataLoaded(response: response)

            // Запускаем генерацию инсайтов параллельно
            await generateInsights()
        } catch {
            logger.error("loadFamilyData failed: \(error.localizedDescription)")
            presenter?.presentError(response: FamilyCalendarResponse.ErrorOccurred(
                message: String(localized: "family_calendar.error.load")
            ))
        }
    }

    func selectChild(request: FamilyCalendarRequest.SelectChild) async {
        selectedChildId = request.childId
        let response = FamilyCalendarResponse.ChildSelected(
            childId: selectedChildId,
            children: allChildren,
            sessions: allSessions,
            currentMonth: currentMonth
        )
        presenter?.presentChildSelected(response: response)
        await generateInsights()
    }

    func changeMonth(request: FamilyCalendarRequest.ChangeMonth) {
        let calendar = Calendar.current
        let offset: Int
        switch request.direction {
        case .previous: offset = -1
        case .next:     offset = 1
        }
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) else { return }
        // Не позволяем уйти дальше текущего месяца
        let now = Date()
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        guard newMonth <= currentMonthStart else { return }
        currentMonth = newMonth
        let response = FamilyCalendarResponse.MonthChanged(
            newMonth: currentMonth,
            sessions: allSessions,
            selectedChildId: selectedChildId,
            children: allChildren
        )
        presenter?.presentMonthChanged(response: response)
    }

    func selectDay(request: FamilyCalendarRequest.SelectDay) {
        let relevantSessions = filterSessions(for: selectedChildId)
        let response = FamilyCalendarResponse.DaySelected(
            date: request.date,
            sessions: relevantSessions,
            children: allChildren
        )
        presenter?.presentDaySelected(response: response)
    }

    // MARK: - Insights

    private func generateInsights() async {
        presenter?.presentInsightsLoading(isLoading: true)

        let relevantSessions = filterSessions(for: selectedChildId)
        let statsWorker = FamilyStatsWorker()

        // Агрегации для rule-based
        let aggregations: [FamilyStatsAggregation]
        if let childId = selectedChildId {
            if let child = allChildren.first(where: { $0.id == childId }) {
                aggregations = [statsWorker.aggregate(child: child, sessions: relevantSessions)]
            } else {
                aggregations = []
            }
        } else {
            aggregations = allChildren.map { child in
                statsWorker.aggregate(child: child, sessions: relevantSessions)
            }
        }

        // Rule-based fallback (всегда работает)
        var insights = insightsWorker.generateRuleBasedInsights(
            aggregations: aggregations,
            selectedChildId: selectedChildId
        )

        // Пробуем LLM (Tier B/C parent circuit, таймаут 3с)
        if let llm = llmDecisionService, let child = firstRelevantChild() {
            let llmTask = Task {
                await insightsWorker.generateLLMInsights(
                    llmService: llm,
                    child: child,
                    sessions: relevantSessions
                )
            }
            // Таймаут 3 секунды — если LLM не ответил, используем rule-based
            let llmInsightsResult = await withTaskGroup(of: [InsightItem].self) { group in
                group.addTask { await llmTask.value }
                group.addTask {
                    try? await Task.sleep(for: .seconds(3))
                    return []
                }
                var firstResult: [InsightItem] = []
                for await result in group where !result.isEmpty {
                    firstResult = result
                    group.cancelAll()
                    break
                }
                return firstResult
            }

            if !llmInsightsResult.isEmpty {
                // Добавляем LLM-инсайты в начало (они более персонализированы)
                insights = Array((llmInsightsResult + insights).prefix(5))
            }
        }

        presenter?.presentInsightsLoading(isLoading: false)
        presenter?.presentInsights(response: FamilyCalendarResponse.InsightsGenerated(insights: insights))
    }

    // MARK: - Private Helpers

    private func filterSessions(for childId: String?) -> [SessionDTO] {
        guard let childId else { return allSessions }
        return allSessions.filter { $0.childId == childId }
    }

    private func firstRelevantChild() -> ChildProfileDTO? {
        if let childId = selectedChildId {
            return allChildren.first { $0.id == childId }
        }
        return allChildren.first
    }
}
