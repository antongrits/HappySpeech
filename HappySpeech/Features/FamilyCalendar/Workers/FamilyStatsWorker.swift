import Foundation
import OSLog

// MARK: - FamilyStatsWorker
//
// Агрегирует SessionDTO по одному или нескольким детям.
// Считает day-activities, heatmap за 12 недель, streak, лучший звук.
// Чистый вычислительный слой — не обращается к Realm напрямую.

struct FamilyStatsWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyStatsWorker")

    // MARK: - Public API

    /// Агрегирует статистику для одного ребёнка из его сессий.
    func aggregate(
        child: ChildProfileDTO,
        sessions: [SessionDTO],
        weeksCount: Int = 12
    ) -> FamilyStatsAggregation {
        let childSessions = sessions.filter { $0.childId == child.id }
        let streak = computeStreak(sessions: childSessions)
        let dayActivities = buildDayActivities(sessions: childSessions)
        let heatmap = buildHeatmap(sessions: childSessions, weeksCount: weeksCount)
        let (bestSound, bestSoundRate) = computeBestSound(child: child)
        return FamilyStatsAggregation(
            childId: child.id,
            childName: child.name,
            streak: streak,
            totalSessions: childSessions.count,
            avgSuccessRate: averageSuccessRate(sessions: childSessions),
            bestSound: bestSound,
            bestSoundRate: bestSoundRate,
            dayActivities: dayActivities,
            heatmapEntries: heatmap
        )
    }

    /// Агрегирует dayActivities для нескольких детей (режим «Все»).
    func aggregateAll(
        children: [ChildProfileDTO],
        sessions: [SessionDTO],
        weeksCount: Int = 12
    ) -> FamilyStatsAggregation {
        let combined = FamilyStatsAggregation(
            childId: "all",
            childName: String(localized: "family_calendar.children.all"),
            streak: 0,
            totalSessions: sessions.count,
            avgSuccessRate: averageSuccessRate(sessions: sessions),
            bestSound: nil,
            bestSoundRate: 0,
            dayActivities: buildDayActivities(sessions: sessions),
            heatmapEntries: buildHeatmap(sessions: sessions, weeksCount: weeksCount)
        )
        return combined
    }

    /// Строит CalendarDayViewModel[] для заданного месяца.
    func buildCalendarDays(
        month: Date,
        dayActivities: [Date: Int]
    ) -> [CalendarDayViewModel] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = monthInterval.start

        // Первый день недели (Пн = 2 в iOS Calendar.weekday)
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        // Конвертируем в 0-based Пн-начало (Mon=0, Sun=6)
        let leadingBlanks = (weekdayOfFirst + 5) % 7

        var days: [CalendarDayViewModel] = []
        let today = calendar.startOfDay(for: Date())

        // Leading days из предыдущего месяца
        for offset in (0..<leadingBlanks).reversed() {
            if let date = calendar.date(byAdding: .day, value: -(offset + 1), to: firstDay) {
                let dayNum = calendar.component(.day, from: date)
                let norm = calendar.startOfDay(for: date)
                let count = dayActivities[norm] ?? 0
                days.append(CalendarDayViewModel(
                    date: date,
                    dayNumber: dayNum,
                    sessionCount: count,
                    isToday: norm == today,
                    isCurrentMonth: false,
                    isFuture: norm > today,
                    activityLevel: activityLevel(count: count, isToday: norm == today)
                ))
            }
        }

        // Дни текущего месяца
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        for dayOffset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) {
                let dayNum = calendar.component(.day, from: date)
                let norm = calendar.startOfDay(for: date)
                let count = dayActivities[norm] ?? 0
                days.append(CalendarDayViewModel(
                    date: date,
                    dayNumber: dayNum,
                    sessionCount: count,
                    isToday: norm == today,
                    isCurrentMonth: true,
                    isFuture: norm > today,
                    activityLevel: activityLevel(count: count, isToday: norm == today)
                ))
            }
        }

        // Trailing days до полной сетки 6×7=42
        let totalCells = 42
        let trailingCount = totalCells - days.count
        if trailingCount > 0, let lastDay = calendar.date(byAdding: .day, value: daysInMonth - 1, to: firstDay) {
            for offset in 1...trailingCount {
                if let date = calendar.date(byAdding: .day, value: offset, to: lastDay) {
                    let dayNum = calendar.component(.day, from: date)
                    let norm = calendar.startOfDay(for: date)
                    let count = dayActivities[norm] ?? 0
                    days.append(CalendarDayViewModel(
                        date: date,
                        dayNumber: dayNum,
                        sessionCount: count,
                        isToday: norm == today,
                        isCurrentMonth: false,
                        isFuture: norm > today,
                        activityLevel: activityLevel(count: count, isToday: norm == today)
                    ))
                }
            }
        }

        return days
    }

    // MARK: - Private helpers

    private func buildDayActivities(sessions: [SessionDTO]) -> [Date: Int] {
        let calendar = Calendar.current
        var result: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            result[day, default: 0] += 1
        }
        return result
    }

    private func buildHeatmap(sessions: [SessionDTO], weeksCount: Int) -> [HeatmapEntry] {
        let calendar = Calendar.current
        let now = Date()
        // Начало недели, в которой сейчас находимся
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        // Начало самой старой недели (weeksCount недель назад)
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeksCount - 1), to: currentWeekStart) else {
            return []
        }

        // Считаем количество сессий по дням
        let dayActivities = buildDayActivities(sessions: sessions)

        var entries: [HeatmapEntry] = []
        for weekIdx in 0..<weeksCount {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIdx, to: startDate) else { continue }
            for dayIdx in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: dayIdx, to: weekStart) else { continue }
                let norm = calendar.startOfDay(for: day)
                let count = dayActivities[norm] ?? 0
                entries.append(HeatmapEntry(
                    weekIndex: weekIdx,
                    weekday: dayIdx,
                    sessionCount: count,
                    date: norm
                ))
            }
        }
        return entries
    }

    private func computeStreak(sessions: [SessionDTO]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var checkDay = today
        // Если сегодня уже есть сессия — считаем streak с сегодня, иначе со вчера
        if !sessionDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  sessionDays.contains(yesterday) else { return 0 }
            checkDay = yesterday
        }
        while sessionDays.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        return streak
    }

    private func averageSuccessRate(sessions: [SessionDTO]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0.0) { $0 + $1.successRate }
        return total / Double(sessions.count)
    }

    private func computeBestSound(child: ChildProfileDTO) -> (String?, Double) {
        guard let best = child.progressSummary.max(by: { $0.value < $1.value }) else {
            return (nil, 0)
        }
        return (best.key, best.value)
    }

    private func activityLevel(count: Int, isToday: Bool) -> Int {
        if isToday && count > 0 { return 4 }
        switch count {
        case 0:     return 0
        case 1...3: return 1
        case 4...6: return 2
        default:    return 3
        }
    }
}
