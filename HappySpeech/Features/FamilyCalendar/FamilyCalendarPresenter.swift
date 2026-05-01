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

        // Группируем сессии по детям за выбранный день
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
            return DaySessionItem(
                childName: entry.name,
                sessionCount: entry.count,
                accuracyPercent: pct
            )
        }.sorted { $0.childName < $1.childName }

        let detail = DayDetailViewModel(
            date: response.date,
            dateText: dateText,
            sessionItems: sessionItems,
            isEmpty: sessionItems.isEmpty
        )
        display?.displayDayDetail(viewModel: detail)
    }

    func presentInsights(response: FamilyCalendarResponse.InsightsGenerated) {
        let vms = response.insights.map {
            InsightItemViewModel(id: $0.id, iconName: $0.iconName, text: $0.text)
        }
        display?.displayInsights(insights: vms)
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
        isLoading: Bool
    ) -> FamilyCalendarViewModel {
        // ChildAvatarViewModels
        var childVMs: [ChildAvatarViewModel] = []
        // Первый — «Все»
        childVMs.append(ChildAvatarViewModel(
            id: "all",
            name: String(localized: "family_calendar.children.all"),
            initials: "",
            avatarStyle: "all",
            streak: 0,
            isAll: true
        ))
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

        // Calendar days
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

        // isEmpty
        let isEmpty = sessions.isEmpty

        return FamilyCalendarViewModel(
            children: childVMs,
            selectedChildId: selectedChildId,
            currentMonth: currentMonth,
            calendarDays: calendarDays,
            heatmapEntries: heatmapEntries,
            comparisonCards: comparisonCards,
            insights: [],
            isLoading: isLoading,
            isLoadingInsights: true,
            toastMessage: nil,
            isEmpty: isEmpty,
            selectedDayDetail: nil
        )
    }

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
