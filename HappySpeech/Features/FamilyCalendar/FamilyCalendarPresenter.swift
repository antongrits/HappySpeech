import Foundation
import OSLog

// MARK: - FamilyCalendarPresenter
//
// Response → ViewModel форматирование.
// Всё на @MainActor — обновляет ViewModel, которую читает View.

@MainActor
final class FamilyCalendarPresenter {

    // MARK: - Output

    var display: (any FamilyCalendarDisplayLogic)?

    private let statsWorker = FamilyStatsWorker()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyCalendarPresenter")

    // MARK: - Present Data Loaded

    func presentDataLoaded(response: FamilyCalendarResponse.DataLoaded) {
        let aggregations = buildAggregations(
            children: response.children,
            sessions: response.sessions,
            selectedChildId: response.selectedChildId
        )
        let vm = buildViewModel(
            children: response.children,
            sessions: response.sessions,
            aggregations: aggregations,
            selectedChildId: response.selectedChildId,
            currentMonth: response.currentMonth,
            weekOffset: response.weekOffset,
            weeklyGoals: response.weeklyGoals,
            plannedSessions: response.plannedSessions,
            specialistVisits: response.specialistVisits,
            isLoading: false
        )
        display?.displayFamilyData(viewModel: vm)
    }

    func presentChildSelected(response: FamilyCalendarResponse.ChildSelected) {
        let aggregations = buildAggregations(
            children: response.children,
            sessions: response.sessions,
            selectedChildId: response.childId
        )
        let vm = buildViewModel(
            children: response.children,
            sessions: response.sessions,
            aggregations: aggregations,
            selectedChildId: response.childId,
            currentMonth: response.currentMonth,
            weekOffset: response.weekOffset,
            weeklyGoals: response.weeklyGoals,
            plannedSessions: response.plannedSessions,
            specialistVisits: response.specialistVisits,
            isLoading: false
        )
        display?.displayFamilyData(viewModel: vm)
    }

    func presentMonthChanged(response: FamilyCalendarResponse.MonthChanged) {
        let aggregations = buildAggregations(
            children: response.children,
            sessions: response.sessions,
            selectedChildId: response.selectedChildId
        )
        let vm = buildViewModel(
            children: response.children,
            sessions: response.sessions,
            aggregations: aggregations,
            selectedChildId: response.selectedChildId,
            currentMonth: response.newMonth,
            weekOffset: 0,
            weeklyGoals: [:],
            plannedSessions: [],
            specialistVisits: [],
            isLoading: false
        )
        display?.displayFamilyData(viewModel: vm)
    }

    func presentWeekChanged(response: FamilyCalendarResponse.WeekChanged) {
        let aggregations = buildAggregations(
            children: response.children,
            sessions: response.sessions,
            selectedChildId: response.selectedChildId
        )
        let vm = buildViewModel(
            children: response.children,
            sessions: response.sessions,
            aggregations: aggregations,
            selectedChildId: response.selectedChildId,
            currentMonth: response.weekStart,
            weekOffset: response.weekOffset,
            weeklyGoals: response.weeklyGoals,
            plannedSessions: response.plannedSessions,
            specialistVisits: response.specialistVisits,
            isLoading: false
        )
        display?.displayFamilyData(viewModel: vm)
    }

    func presentDaySelected(response: FamilyCalendarResponse.DaySelected) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateText = dateFormatter.string(from: response.date)

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: response.date)

        var itemsByChild: [String: (name: String, count: Int, totalAttempts: Int, correct: Int)] = [:]
        let childMap: [String: String] = Dictionary(
            uniqueKeysWithValues: response.children.map { ($0.id, $0.name) }
        )
        for session in response.sessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            guard sessionDay == dayStart else { continue }
            let name = childMap[session.childId] ?? session.childId
            var entry = itemsByChild[session.childId] ?? (name: name, count: 0, totalAttempts: 0, correct: 0)
            entry.count += 1
            entry.totalAttempts += session.totalAttempts
            entry.correct += session.correctAttempts
            itemsByChild[session.childId] = entry
        }

        let sessionItems = itemsByChild.values.map { entry -> DaySessionItem in
            let pct = entry.totalAttempts > 0
                ? Int(Double(entry.correct) / Double(entry.totalAttempts) * 100)
                : 0
            return DaySessionItem(childName: entry.name, sessionCount: entry.count, accuracyPercent: pct)
        }.sorted { $0.childName < $1.childName }

        // Планы на этот день
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ru_RU")
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let dayPlans = response.dayPlans.map { plan -> DayPlanItem in
            let childName = childMap[plan.childId] ?? plan.childId
            return DayPlanItem(
                id: plan.id,
                childName: childName,
                lessonTemplate: plan.lessonTemplate,
                timeText: timeFormatter.string(from: plan.date)
            )
        }

        // Визит к специалисту
        let visitItem: DayVisitItem? = response.specialistVisits.first.map { visit in
            DayVisitItem(
                specialistName: visit.specialistName,
                notes: visit.notes,
                reportRequested: visit.reportRequested
            )
        }

        let isEmpty = sessionItems.isEmpty && dayPlans.isEmpty && visitItem == nil
        let detail = DayDetailViewModel(
            date: response.date,
            dateText: dateText,
            sessionItems: sessionItems,
            dayPlans: dayPlans,
            specialistVisit: visitItem,
            isEmpty: isEmpty
        )
        display?.displayDayDetail(viewModel: detail)
    }

    func presentInsights(response: FamilyCalendarResponse.InsightsGenerated) {
        let vms = response.insights.map {
            InsightItemViewModel(id: $0.id, iconName: $0.iconName, text: $0.text)
        }
        display?.displayInsights(insights: vms)
    }

    func presentLessonScheduled(response: FamilyCalendarResponse.LessonScheduled) {
        display?.displayLessonScheduled(voiceHint: response.voiceHint)
        display?.displayToast(message: String(format: String(localized: "family_calendar.toast.lesson_scheduled"), response.childName))
    }

    func presentRecurringPlanAdded(response: FamilyCalendarResponse.RecurringPlanAdded) {
        display?.displayToast(message: String(localized: "family_calendar.toast.recurring_added"))
    }

    func presentRecurringPlanRemoved(response: FamilyCalendarResponse.RecurringPlanRemoved) {
        display?.displayToast(message: String(localized: "family_calendar.toast.recurring_removed"))
    }

    func presentSpecialistVisitAdded(response: FamilyCalendarResponse.SpecialistVisitAdded) {
        display?.displayToast(message: String(localized: "family_calendar.toast.visit_added"))
    }

    func presentWeekSummary(response: FamilyCalendarResponse.WeekSummaryGenerated) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let rangeText = "\(dateFormatter.string(from: response.weekStart)) – \(dateFormatter.string(from: response.weekEnd))"

        let rows = response.childSummaries.map { summary -> WeekSummaryRowViewModel in
            let fraction = summary.sessionsGoal > 0
                ? min(1.0, Double(summary.sessionsAchieved) / Double(summary.sessionsGoal))
                : 0
            let sessionsText = String(format: String(localized: "family_calendar.week_summary.sessions_format"),
                                      summary.sessionsAchieved, summary.sessionsGoal)
            let hours = summary.totalMinutes / 60
            let mins = summary.totalMinutes % 60
            let durationText = hours > 0
                ? String(format: String(localized: "family_calendar.week_summary.duration_hm"), hours, mins)
                : String(format: String(localized: "family_calendar.week_summary.duration_m"), mins)
            return WeekSummaryRowViewModel(
                id: summary.childId,
                childName: summary.childName,
                initials: makeInitials(summary.childName),
                sessionsText: sessionsText,
                progressFraction: fraction,
                goalReached: summary.goalReached,
                durationText: durationText,
                accuracyPercent: Int(summary.avgSuccessRate * 100)
            )
        }

        let totalSessions = response.childSummaries.reduce(0) { $0 + $1.sessionsAchieved }
        let totalMinutes = response.childSummaries.reduce(0) { $0 + $1.totalMinutes }
        let allGoals = response.childSummaries.allSatisfy { $0.goalReached }

        let vm = WeekSummaryViewModel(
            weekRangeText: rangeText,
            childRows: rows,
            familyTotalMinutes: totalMinutes,
            familyTotalSessions: totalSessions,
            allGoalsReached: allGoals
        )
        display?.displayWeekSummary(viewModel: vm)
    }

    func presentError(response: FamilyCalendarResponse.ErrorOccurred) {
        display?.displayError(message: response.message)
    }

    func presentLoading(isLoading: Bool) {
        display?.displayLoadingState(isLoading: isLoading)
    }

    func presentInsightsLoading(isLoading: Bool) {
        display?.displayInsightsLoading(isLoading: isLoading)
    }

    // MARK: - Private Builder Helpers

    private func buildAggregations(
        children: [ChildProfileDTO],
        sessions: [SessionDTO],
        selectedChildId: String?
    ) -> [FamilyStatsAggregation] {
        if let childId = selectedChildId {
            let child = children.first { $0.id == childId }
            if let child {
                return [statsWorker.aggregate(child: child, sessions: sessions)]
            }
            return []
        } else {
            return children.map { child in
                statsWorker.aggregate(child: child, sessions: sessions)
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func buildViewModel(
        children: [ChildProfileDTO],
        sessions: [SessionDTO],
        aggregations: [FamilyStatsAggregation],
        selectedChildId: String?,
        currentMonth: Date,
        weekOffset: Int,
        weeklyGoals: [String: Int],
        plannedSessions: [PlannedSession],
        specialistVisits: [SpecialistVisit],
        isLoading: Bool
    ) -> FamilyCalendarViewModel {
        // ChildAvatarViewModels
        var childVMs: [ChildAvatarViewModel] = [
            ChildAvatarViewModel(
                id: "all",
                name: String(localized: "family_calendar.children.all"),
                initials: "",
                avatarStyle: "all",
                streak: 0,
                isAll: true
            )
        ]
        for child in children {
            let agg = aggregations.first { $0.childId == child.id }
            childVMs.append(ChildAvatarViewModel(
                id: child.id,
                name: child.name,
                initials: makeInitials(child.name),
                avatarStyle: child.avatarStyle,
                streak: agg?.streak ?? child.currentStreak,
                isAll: false
            ))
        }

        // Week days (7 ячеек текущей недели)
        let weekDays = buildWeekDays(
            weekStart: currentMonth,
            sessions: sessions,
            plannedSessions: plannedSessions,
            specialistVisits: specialistVisits,
            selectedChildId: selectedChildId
        )

        // Calendar days (сетка месяца, для совместимости)
        let combinedActivities = buildCombinedActivities(aggregations: aggregations)
        let calendarDays = statsWorker.buildCalendarDays(month: currentMonth, dayActivities: combinedActivities)

        // Heatmap
        let heatmapEntries: [HeatmapEntryViewModel]
        if let first = aggregations.first {
            heatmapEntries = buildHeatmapVMs(entries: first.heatmapEntries)
        } else {
            let allAgg = statsWorker.aggregateAll(children: children, sessions: sessions)
            heatmapEntries = buildHeatmapVMs(entries: allAgg.heatmapEntries)
        }

        // Comparison cards
        let comparisonCards = buildComparisonCards(
            children: children,
            aggregations: aggregations,
            selectedChildId: selectedChildId
        )

        // Weekly goal cards
        let weekGoalCards = buildWeekGoalCards(
            children: children,
            sessions: sessions,
            aggregations: aggregations,
            weeklyGoals: weeklyGoals,
            weekStart: currentMonth
        )

        return FamilyCalendarViewModel(
            children: childVMs,
            selectedChildId: selectedChildId,
            currentMonth: currentMonth,
            weekOffset: weekOffset,
            weekDays: weekDays,
            calendarDays: calendarDays,
            heatmapEntries: heatmapEntries,
            comparisonCards: comparisonCards,
            weekGoalCards: weekGoalCards,
            insights: [],
            isLoading: isLoading,
            isLoadingInsights: true,
            toastMessage: nil,
            isEmpty: sessions.isEmpty,
            selectedDayDetail: nil,
            weekSummary: nil
        )
    }

    // MARK: - Week Days Builder

    private func buildWeekDays(
        weekStart: Date,
        sessions: [SessionDTO],
        plannedSessions: [PlannedSession],
        specialistVisits: [SpecialistVisit],
        selectedChildId: String?
    ) -> [WeekDayViewModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayNames = [
            String(localized: "family_calendar.heatmap.day_mon"),
            String(localized: "family_calendar.heatmap.day_tue"),
            String(localized: "family_calendar.heatmap.day_wed"),
            String(localized: "family_calendar.heatmap.day_thu"),
            String(localized: "family_calendar.heatmap.day_fri"),
            String(localized: "family_calendar.heatmap.day_sat"),
            String(localized: "family_calendar.heatmap.day_sun")
        ]

        var days: [WeekDayViewModel] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let relevantSessions = sessions.filter { s in
                (selectedChildId == nil || s.childId == selectedChildId) &&
                s.date >= dayStart && s.date < dayEnd
            }
            let dayPlans = plannedSessions.filter { p in
                (selectedChildId == nil || p.childId == selectedChildId) &&
                p.date >= dayStart && p.date < dayEnd
            }
            let hasVisit = specialistVisits.contains { v in
                (selectedChildId == nil || v.childId == selectedChildId) &&
                v.date >= dayStart && v.date < dayEnd
            }

            let count = relevantSessions.count
            let actLevel: Int
            switch count {
            case 0:     actLevel = 0
            case 1...2: actLevel = 1
            case 3...4: actLevel = 2
            default:    actLevel = 3
            }

            let weekdayIdx = (calendar.component(.weekday, from: day) + 5) % 7
            days.append(WeekDayViewModel(
                date: day,
                dayNumber: calendar.component(.day, from: day),
                weekdayShort: weekdayNames[safe: weekdayIdx] ?? "",
                sessionCount: count,
                plannedCount: dayPlans.count,
                hasSpecialistVisit: hasVisit,
                isToday: dayStart == today,
                isFuture: dayStart > today,
                activityLevel: actLevel
            ))
        }
        return days
    }

    // MARK: - Week Goal Cards Builder

    private func buildWeekGoalCards(
        children: [ChildProfileDTO],
        sessions: [SessionDTO],
        aggregations: [FamilyStatsAggregation],
        weeklyGoals: [String: Int],
        weekStart: Date
    ) -> [WeekGoalCardViewModel] {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return [] }

        return children.map { child in
            let goal = weeklyGoals[child.id] ?? 4
            let weekSessions = sessions.filter { s in
                s.childId == child.id && s.date >= weekStart && s.date < weekEnd
            }
            let achieved = weekSessions.count
            let fraction = goal > 0 ? min(1.0, Double(achieved) / Double(goal)) : 0
            let streak = aggregations.first { $0.childId == child.id }?.streak ?? child.currentStreak

            return WeekGoalCardViewModel(
                id: child.id,
                childName: child.name,
                initials: makeInitials(child.name),
                sessionsAchieved: achieved,
                sessionsGoal: goal,
                progressFraction: fraction,
                goalReached: achieved >= goal,
                streakDays: streak
            )
        }
    }

    // MARK: - Common Helpers

    private func buildCombinedActivities(aggregations: [FamilyStatsAggregation]) -> [Date: Int] {
        var combined: [Date: Int] = [:]
        for agg in aggregations {
            for (date, count) in agg.dayActivities {
                combined[date, default: 0] += count
            }
        }
        return combined
    }

    private func buildHeatmapVMs(entries: [HeatmapEntry]) -> [HeatmapEntryViewModel] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "EE d MMM"
        return entries.map { entry in
            HeatmapEntryViewModel(
                id: entry.id,
                weekIndex: entry.weekIndex,
                weekday: entry.weekday,
                sessionCount: entry.sessionCount,
                date: entry.date,
                label: dateFormatter.string(from: entry.date)
            )
        }
    }

    private func buildComparisonCards(
        children: [ChildProfileDTO],
        aggregations: [FamilyStatsAggregation],
        selectedChildId: String?
    ) -> [ChildSummaryViewModel] {
        guard selectedChildId == nil, children.count >= 2 else { return [] }

        let familyAvgRate = aggregations.isEmpty
            ? 0.0
            : aggregations.reduce(0.0) { $0 + $1.avgSuccessRate } / Double(aggregations.count)
        let maxRate = aggregations.max(by: { $0.avgSuccessRate < $1.avgSuccessRate })?.avgSuccessRate ?? 0

        return aggregations.map { agg in
            let child = children.first { $0.id == agg.childId }
            let delta = agg.avgSuccessRate - familyAvgRate
            let isLeader = agg.avgSuccessRate == maxRate
            return ChildSummaryViewModel(
                id: agg.childId,
                name: agg.childName,
                initials: makeInitials(agg.childName),
                avatarStyle: child?.avatarStyle ?? "butterfly",
                bestSound: agg.bestSound ?? "—",
                bestSoundRate: agg.bestSoundRate,
                comparisonDelta: delta,
                isLeader: isLeader
            )
        }
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
