import Foundation
import OSLog

// MARK: - FamilyCalendarInteractor
//
// Бизнес-логика семейного календаря (Parent-контур).
// Поддерживает: недельная сетка ±2 недели, планирование уроков,
// повторяющиеся расписания, многодетный режим, цели недели,
// визиты к логопеду, напоминания, voice hints от Ляли.

@MainActor
final class FamilyCalendarInteractor {

    // MARK: - Dependencies

    var presenter: FamilyCalendarPresenter?
    var router: FamilyCalendarRouter?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let notificationService: (any NotificationService)?
    private let llmDecisionService: (any LLMDecisionServiceProtocol)?

    private let insightsWorker = FamilyInsightsWorker()
    private let statsWorker = FamilyStatsWorker()
    private let planStore = FamilyPlanStore()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyCalendarInteractor")

    // MARK: - Internal State

    private var allChildren: [ChildProfileDTO] = []
    private var allSessions: [SessionDTO] = []
    private var selectedChildId: String?
    private var weekOffset: Int = 0   // 0=текущая, -1=прошлая, +1=следующая (±2)
    private var weeklyGoals: [String: Int] = [:]   // childId → goal sessions/week
    private var plannedSessions: [PlannedSession] = []
    private var recurringPlans: [RecurringPlan] = []
    private var specialistVisits: [SpecialistVisit] = []

    // MARK: - Week helpers

    private var currentWeekStart: Date {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let shifted = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart)
        else { return Date() }
        return shifted
    }

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        notificationService: (any NotificationService)? = nil,
        llmDecisionService: (any LLMDecisionServiceProtocol)?
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.notificationService = notificationService
        self.llmDecisionService = llmDecisionService
    }

    // MARK: - Use Case: LoadData

    func loadFamilyData(request: FamilyCalendarRequest.LoadData) async {
        presenter?.presentLoading(isLoading: true)

        do {
            let children = try await childRepository.fetchAll()
            allChildren = children

            var sessions: [SessionDTO] = []
            let cutoffDate = Calendar.current.date(
                byAdding: .weekOfYear, value: -12, to: Date()
            ) ?? Date()

            for child in children {
                let childSessions = try await sessionRepository.fetchAll(childId: child.id)
                sessions.append(contentsOf: childSessions.filter { $0.date >= cutoffDate })
            }
            allSessions = sessions

            // Загружаем планы и посещения из локального хранилища
            plannedSessions = planStore.loadPlannedSessions()
            recurringPlans = planStore.loadRecurringPlans()
            specialistVisits = planStore.loadSpecialistVisits()

            // Дефолтные цели: 4 сессии в неделю
            for child in children where weeklyGoals[child.id] == nil {
                weeklyGoals[child.id] = 4
            }

            let response = FamilyCalendarResponse.DataLoaded(
                children: allChildren,
                sessions: allSessions,
                selectedChildId: selectedChildId,
                currentMonth: currentWeekStart,
                weekOffset: weekOffset,
                weeklyGoals: weeklyGoals,
                plannedSessions: plannedSessions,
                recurringPlans: recurringPlans,
                specialistVisits: specialistVisits
            )
            presenter?.presentDataLoaded(response: response)
            await generateInsights()
        } catch {
            logger.error("loadFamilyData failed: \(error.localizedDescription)")
            presenter?.presentError(response: FamilyCalendarResponse.ErrorOccurred(
                message: String(localized: "family_calendar.error.load")
            ))
        }
    }

    // MARK: - Use Case: SelectChild

    func selectChild(request: FamilyCalendarRequest.SelectChild) async {
        selectedChildId = request.childId
        let response = FamilyCalendarResponse.ChildSelected(
            childId: selectedChildId,
            children: allChildren,
            sessions: allSessions,
            currentMonth: currentWeekStart,
            weekOffset: weekOffset,
            weeklyGoals: weeklyGoals,
            plannedSessions: plannedSessions,
            recurringPlans: recurringPlans,
            specialistVisits: specialistVisits
        )
        presenter?.presentChildSelected(response: response)
        await generateInsights()
    }

    // MARK: - Use Case: ChangeWeek (±2 weeks navigation)

    func changeWeek(request: FamilyCalendarRequest.ChangeWeek) {
        let newOffset: Int
        switch request.direction {
        case .previous: newOffset = weekOffset - 1
        case .next:     newOffset = weekOffset + 1
        }
        // Ограничение: не дальше +1 в будущее и -8 в прошлое
        guard newOffset >= -8, newOffset <= 1 else { return }
        weekOffset = newOffset

        let response = FamilyCalendarResponse.WeekChanged(
            weekStart: currentWeekStart,
            weekOffset: weekOffset,
            sessions: allSessions,
            selectedChildId: selectedChildId,
            children: allChildren,
            weeklyGoals: weeklyGoals,
            plannedSessions: plannedSessions,
            specialistVisits: specialistVisits
        )
        presenter?.presentWeekChanged(response: response)
    }

    // MARK: - Use Case: ChangeMonth (совместимость с предыдущим API)

    func changeMonth(request: FamilyCalendarRequest.ChangeMonth) {
        let weekRequest: FamilyCalendarRequest.ChangeWeek
        switch request.direction {
        case .previous: weekRequest = .init(direction: .previous)
        case .next:     weekRequest = .init(direction: .next)
        }
        changeWeek(request: weekRequest)
    }

    // MARK: - Use Case: SelectDay

    func selectDay(request: FamilyCalendarRequest.SelectDay) {
        let relevantSessions = filterSessions(for: selectedChildId)
        let dayPlans = plannedSessions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: request.date)
        }
        let visits = specialistVisits.filter {
            Calendar.current.isDate($0.date, inSameDayAs: request.date)
        }
        let response = FamilyCalendarResponse.DaySelected(
            date: request.date,
            sessions: relevantSessions,
            children: allChildren,
            dayPlans: dayPlans,
            specialistVisits: visits
        )
        presenter?.presentDaySelected(response: response)
    }

    // MARK: - Use Case: ScheduleLesson

    func scheduleLesson(request: FamilyCalendarRequest.ScheduleLesson) async {
        let newPlan = PlannedSession(
            id: UUID().uuidString,
            childId: request.childId,
            date: request.date,
            lessonTemplate: request.lessonTemplate,
            notificationScheduled: request.enableReminder
        )
        plannedSessions.append(newPlan)
        planStore.savePlannedSessions(plannedSessions)

        if request.enableReminder, let notifService = notificationService {
            await scheduleNotification(for: newPlan, childName: request.childName)
            _ = notifService  // подтверждение использования через protocol surface
        }

        logger.info("Lesson scheduled: \(newPlan.id) for child \(request.childId) on \(request.date)")

        presenter?.presentLessonScheduled(response: FamilyCalendarResponse.LessonScheduled(
            plan: newPlan,
            childName: request.childName,
            voiceHint: buildScheduleVoiceHint(childName: request.childName, date: request.date)
        ))

        // Обновляем полный экран
        let response = FamilyCalendarResponse.WeekChanged(
            weekStart: currentWeekStart,
            weekOffset: weekOffset,
            sessions: allSessions,
            selectedChildId: selectedChildId,
            children: allChildren,
            weeklyGoals: weeklyGoals,
            plannedSessions: plannedSessions,
            specialistVisits: specialistVisits
        )
        presenter?.presentWeekChanged(response: response)
    }

    // MARK: - Use Case: AddRecurringPlan

    func addRecurringPlan(request: FamilyCalendarRequest.AddRecurringPlan) {
        let plan = RecurringPlan(
            id: UUID().uuidString,
            childId: request.childId,
            weekday: request.weekday,
            hour: request.hour,
            minute: request.minute,
            lessonTemplate: request.lessonTemplate,
            isActive: true
        )
        recurringPlans.append(plan)
        planStore.saveRecurringPlans(recurringPlans)

        logger.info("RecurringPlan added: \(plan.id) weekday=\(plan.weekday) \(plan.hour):\(plan.minute)")

        presenter?.presentRecurringPlanAdded(response: FamilyCalendarResponse.RecurringPlanAdded(plan: plan))
    }

    // MARK: - Use Case: RemoveRecurringPlan

    func removeRecurringPlan(request: FamilyCalendarRequest.RemoveRecurringPlan) {
        recurringPlans.removeAll { $0.id == request.planId }
        planStore.saveRecurringPlans(recurringPlans)
        presenter?.presentRecurringPlanRemoved(response: FamilyCalendarResponse.RecurringPlanRemoved(planId: request.planId))
    }

    // MARK: - Use Case: SetWeeklyGoal

    func setWeeklyGoal(request: FamilyCalendarRequest.SetWeeklyGoal) {
        weeklyGoals[request.childId] = request.sessionsPerWeek
        let response = buildWeekChangedResponse()
        presenter?.presentWeekChanged(response: response)
        logger.info("Weekly goal set: child=\(request.childId) goal=\(request.sessionsPerWeek)")
    }

    // MARK: - Use Case: AddSpecialistVisit

    func addSpecialistVisit(request: FamilyCalendarRequest.AddSpecialistVisit) {
        let visit = SpecialistVisit(
            id: UUID().uuidString,
            childId: request.childId,
            date: request.date,
            specialistName: request.specialistName,
            notes: request.notes,
            reportRequested: request.requestReport
        )
        specialistVisits.append(visit)
        planStore.saveSpecialistVisits(specialistVisits)

        if request.enableReminder {
            Task { await scheduleVisitNotification(visit: visit, childName: request.childName) }
        }

        logger.info("SpecialistVisit added: \(visit.id) for \(request.childId)")
        presenter?.presentSpecialistVisitAdded(response: FamilyCalendarResponse.SpecialistVisitAdded(visit: visit))

        let weekResponse = buildWeekChangedResponse()
        presenter?.presentWeekChanged(response: weekResponse)
    }

    // MARK: - Use Case: RemovePlannedSession

    func removePlannedSession(request: FamilyCalendarRequest.RemovePlannedSession) {
        plannedSessions.removeAll { $0.id == request.sessionId }
        planStore.savePlannedSessions(plannedSessions)

        let response = buildWeekChangedResponse()
        presenter?.presentWeekChanged(response: response)
        logger.info("PlannedSession removed: \(request.sessionId)")
    }

    // MARK: - Use Case: GenerateWeekSummary

    func generateWeekSummary(request: FamilyCalendarRequest.GenerateWeekSummary) {
        let calendar = Calendar.current
        let weekStart = request.weekStart
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return }
        let weekEndBound = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: weekEnd)) ?? weekEnd

        let weekSessions = allSessions.filter { s in
            s.date >= calendar.startOfDay(for: weekStart) &&
            s.date <= weekEndBound &&
            (selectedChildId == nil || s.childId == selectedChildId)
        }

        let sessionsByChild: [String: [SessionDTO]] = Dictionary(grouping: weekSessions) { $0.childId }
        var childSummaries: [WeekChildSummary] = []

        for child in allChildren {
            let childSessions = sessionsByChild[child.id] ?? []
            let goal = weeklyGoals[child.id] ?? 4
            let achieved = childSessions.count
            let avgRate = childSessions.isEmpty ? 0.0 :
                childSessions.reduce(0.0) { $0 + $1.successRate } / Double(childSessions.count)
            let durationMinutes = childSessions.reduce(0) { $0 + ($1.durationSeconds / 60) }

            childSummaries.append(WeekChildSummary(
                childId: child.id,
                childName: child.name,
                sessionsAchieved: achieved,
                sessionsGoal: goal,
                goalReached: achieved >= goal,
                avgSuccessRate: avgRate,
                totalMinutes: durationMinutes,
                plannedCount: plannedSessions.filter {
                    $0.childId == child.id &&
                    $0.date >= weekStart && $0.date <= weekEnd
                }.count
            ))
        }

        let response = FamilyCalendarResponse.WeekSummaryGenerated(
            weekStart: weekStart,
            weekEnd: weekEnd,
            childSummaries: childSummaries
        )
        presenter?.presentWeekSummary(response: response)
    }

    // MARK: - Insights

    private func generateInsights() async {
        presenter?.presentInsightsLoading(isLoading: true)

        let relevantSessions = filterSessions(for: selectedChildId)

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

        var insights = insightsWorker.generateRuleBasedInsights(
            aggregations: aggregations,
            selectedChildId: selectedChildId
        )

        // Добавляем goal-инсайт если цель достигнута за эту неделю
        insights += generateGoalInsights()

        // Добавляем инсайт про предстоящий визит к специалисту (если есть)
        insights += generateVisitInsights()

        if let llm = llmDecisionService, let child = firstRelevantChild() {
            let llmTask = Task {
                await insightsWorker.generateLLMInsights(
                    llmService: llm,
                    child: child,
                    sessions: relevantSessions
                )
            }
            let llmResult = await withTaskGroup(of: [InsightItem].self) { group in
                group.addTask { await llmTask.value }
                group.addTask {
                    try? await Task.sleep(for: .seconds(3))
                    return []
                }
                var first: [InsightItem] = []
                for await result in group where !result.isEmpty {
                    first = result
                    group.cancelAll()
                    break
                }
                return first
            }
            if !llmResult.isEmpty {
                insights = Array((llmResult + insights).prefix(6))
            }
        }

        presenter?.presentInsightsLoading(isLoading: false)
        presenter?.presentInsights(response: FamilyCalendarResponse.InsightsGenerated(
            insights: Array(insights.prefix(6))
        ))
    }

    // MARK: - Goal Insights

    private func generateGoalInsights() -> [InsightItem] {
        var result: [InsightItem] = []
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)
        else { return result }

        let relevantChildren = selectedChildId == nil
            ? allChildren
            : allChildren.filter { $0.id == selectedChildId }

        for child in relevantChildren {
            let goal = weeklyGoals[child.id] ?? 4
            let weekSessions = allSessions.filter {
                $0.childId == child.id && $0.date >= weekStart && $0.date < weekEnd
            }
            if weekSessions.count >= goal {
                result.append(InsightItem(
                    iconName: "checkmark.circle.fill",
                    text: String(format: String(localized: "family_calendar.insight.goal_reached"), child.name, goal)
                ))
            } else {
                let remaining = goal - weekSessions.count
                result.append(InsightItem(
                    iconName: "target",
                    text: String(format: String(localized: "family_calendar.insight.goal_remaining"), child.name, remaining, goal)
                ))
            }
        }
        return result
    }

    // MARK: - Visit Insights

    private func generateVisitInsights() -> [InsightItem] {
        var result: [InsightItem] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: today) else { return result }

        let upcoming = specialistVisits.filter { $0.date >= today && $0.date <= nextWeek }
        for visit in upcoming {
            let childName = allChildren.first { $0.id == visit.childId }?.name ?? ""
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateStyle = .short
            result.append(InsightItem(
                iconName: "stethoscope",
                text: String(format: String(localized: "family_calendar.insight.specialist_visit"), childName, formatter.string(from: visit.date))
            ))
        }
        return result
    }

    // MARK: - Notification Helpers

    private func scheduleNotification(for plan: PlannedSession, childName: String) async {
        guard let service = notificationService else { return }
        let granted = await service.requestPermission()
        guard granted else {
            logger.notice("scheduleNotification skipped — permission denied")
            return
        }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.date)
        components.hour = components.hour ?? 17
        components.minute = components.minute ?? 0

        let content = buildLessonNotificationContent(childName: childName, date: plan.date)
        let identifier = "hs.planned.\(plan.id)"

        do {
            try await scheduleCalendarNotification(
                identifier: identifier,
                content: content,
                components: components,
                repeats: false,
                service: service
            )
        } catch {
            logger.error("Failed to schedule lesson notification: \(error.localizedDescription)")
        }
    }

    private func scheduleVisitNotification(visit: SpecialistVisit, childName: String) async {
        guard let service = notificationService else { return }
        let granted = await service.requestPermission()
        guard granted else { return }

        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -1, to: visit.date) else { return }
        var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 18
        components.minute = 0

        let content = buildVisitNotificationContent(childName: childName, date: visit.date)
        let identifier = "hs.visit.\(visit.id)"

        do {
            try await scheduleCalendarNotification(
                identifier: identifier,
                content: content,
                components: components,
                repeats: false,
                service: service
            )
        } catch {
            logger.error("Failed to schedule visit notification: \(error.localizedDescription)")
        }
    }

    private func scheduleCalendarNotification(
        identifier: String,
        content: FamilyNotificationContent,
        components: DateComponents,
        repeats: Bool,
        service: any NotificationService
    ) async throws {
        // NotificationServiceLive имеет scheduleDailyReminder(at:DateComponents).
        // Для произвольных дат используем внутренний канал через UserDefaults-queue.
        // Это упрощённая реализация: сохраняем pending в UserDefaults,
        // реальный тригер срабатывает при следующем открытии приложения.
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)
        var pending = UserDefaults.standard.array(forKey: "hs.pending_notifications") as? [Data] ?? []
        pending.append(data)
        UserDefaults.standard.set(pending, forKey: "hs.pending_notifications")
        logger.debug("Notification queued: \(identifier)")
        _ = service  // protocol used for permission gate above
    }

    // MARK: - Voice Hint (Ляля)

    private func buildScheduleVoiceHint(childName: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return String(format: String(localized: "family_calendar.voice.lesson_scheduled"),
                      childName, formatter.string(from: date))
    }

    // MARK: - Private Helpers

    private func buildWeekChangedResponse() -> FamilyCalendarResponse.WeekChanged {
        FamilyCalendarResponse.WeekChanged(
            weekStart: currentWeekStart,
            weekOffset: weekOffset,
            sessions: allSessions,
            selectedChildId: selectedChildId,
            children: allChildren,
            weeklyGoals: weeklyGoals,
            plannedSessions: plannedSessions,
            specialistVisits: specialistVisits
        )
    }

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

    private func buildLessonNotificationContent(childName: String, date: Date) -> FamilyNotificationContent {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let timeStr = formatter.string(from: date)
        return FamilyNotificationContent(
            identifier: UUID().uuidString,
            title: String(localized: "notifications.lesson.title"),
            body: String(format: String(localized: "notifications.lesson.body"), childName, timeStr),
            scheduledDate: date
        )
    }

    private func buildVisitNotificationContent(childName: String, date: Date) -> FamilyNotificationContent {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return FamilyNotificationContent(
            identifier: UUID().uuidString,
            title: String(localized: "notifications.visit.title"),
            body: String(format: String(localized: "notifications.visit.body"), childName, formatter.string(from: date)),
            scheduledDate: date
        )
    }
}
