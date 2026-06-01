import Foundation
import OSLog

// MARK: - ProgressDashboardAggregating

/// Worker, агрегирующий РЕАЛЬНЫЙ прогресс ребёнка из репозиториев.
///
/// Источник данных:
/// - `SessionRepository` — завершённые сессии (дата, длительность, попытки,
///   правильные попытки, целевой звук) для расчёта точности, серий по дням,
///   минут и звёзд;
/// - `ChildRepository` — `currentStreak` ребёнка (ground-truth серия дней)
///   и `progressSummary` (накопленная точность по звукам).
///
/// Никаких выдуманных чисел: если у ребёнка нет сессий, возвращается
/// `DashboardAggregate.empty` (нулевые summary, пустые массивы), и Presenter
/// показывает честное пустое состояние «пока нет занятий».
@MainActor
protocol ProgressDashboardAggregating: AnyObject {
    func aggregate(
        childId: String,
        period: ProgressDashboardModels.TimePeriod
    ) async -> DashboardAggregate
}

// MARK: - DashboardAggregate

/// Результат агрегации — всё, что нужно интерактору для одного периода.
struct DashboardAggregate: Sendable, Equatable {
    let summary: DashboardSummary
    let daily: [DailyAccuracy]
    let weekly: [WeeklyAccuracy]
    let sounds: [SoundProgress]
    let soundHistory: [String: [DailyAccuracy]]

    static let empty = DashboardAggregate(
        summary: DashboardSummary(overallAccuracy: 0, streakDays: 0, totalMinutes: 0, totalStars: 0),
        daily: [],
        weekly: [],
        sounds: [],
        soundHistory: [:]
    )

    var isEmpty: Bool { sounds.isEmpty && daily.isEmpty }
}

// MARK: - ProgressDashboardWorker

@MainActor
final class ProgressDashboardWorker: ProgressDashboardAggregating {

    // MARK: - Collaborators

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgressDashboardWorker")

    // MARK: - Init

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    // MARK: - Aggregation

    func aggregate(
        childId: String,
        period: ProgressDashboardModels.TimePeriod
    ) async -> DashboardAggregate {
        let now = Date()
        let allSessions: [SessionDTO]
        do {
            allSessions = try await sessionRepository.fetchAll(childId: childId)
        } catch {
            logger.error("aggregate: fetchAll failed \(error.localizedDescription, privacy: .public)")
            return .empty
        }

        // Окно периода: week=7д, month=30д, quarter=90д.
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(
            for: now.addingTimeInterval(-Double(period.dayCount - 1) * 86_400)
        )
        let sessions = allSessions
            .filter { $0.date >= windowStart }
            .filter { $0.totalAttempts > 0 }
            .sorted { $0.date < $1.date }

        guard !sessions.isEmpty else {
            logger.info("aggregate: no sessions in window period=\(period.rawValue, privacy: .public)")
            // Серию читаем из профиля даже без сессий в окне (ground-truth),
            // но summary остаётся «пустым», чтобы UI показал честный empty-state.
            return .empty
        }

        let daily = Self.makeDaily(sessions: sessions, period: period, now: now, calendar: calendar)
        let weekly = Self.makeWeekly(sessions: sessions, period: period, now: now, calendar: calendar)
        let sounds = Self.makeSounds(sessions: sessions)
        let soundHistory = Self.makeSoundHistory(sessions: sessions, period: period, now: now, calendar: calendar)

        let overall = Self.weightedAccuracy(sessions)
        let minutes = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
        let stars = sessions.reduce(0) { $0 + Self.stars(for: $1) }
        let streak = await fetchStreak(childId: childId, fallback: Self.streakFromSessions(sessions, calendar: calendar))

        let summary = DashboardSummary(
            overallAccuracy: Float(overall),
            streakDays: streak,
            totalMinutes: minutes,
            totalStars: stars
        )

        logger.info(
            "aggregate: sessions=\(sessions.count, privacy: .public) accuracy=\(Int(overall * 100), privacy: .public) minutes=\(minutes, privacy: .public)"
        )

        return DashboardAggregate(
            summary: summary,
            daily: daily,
            weekly: weekly,
            sounds: sounds,
            soundHistory: soundHistory
        )
    }

    // MARK: - Streak (ground-truth из профиля)

    private func fetchStreak(childId: String, fallback: Int) async -> Int {
        do {
            let child = try await childRepository.fetch(id: childId)
            return child.currentStreak
        } catch {
            logger.debug("fetchStreak: profile unavailable, derive from sessions")
            return fallback
        }
    }
}

// MARK: - Pure aggregation helpers (тестируемые, без I/O)

extension ProgressDashboardWorker {

    /// Точность периода — взвешенная по числу попыток (а не среднее по сессиям),
    /// чтобы короткие сессии не искажали общий процент.
    static func weightedAccuracy(_ sessions: [SessionDTO]) -> Double {
        let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
        guard totalAttempts > 0 else { return 0 }
        let totalCorrect = sessions.reduce(0) { $0 + $1.correctAttempts }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    /// Звёзды за сессию по правилу SessionComplete:
    /// 1 — любое завершение, 2 — accuracy ≥ 60%, 3 — accuracy ≥ 85%.
    static func stars(for session: SessionDTO) -> Int {
        let rate = session.successRate
        if rate >= 0.85 { return 3 }
        if rate >= 0.60 { return 2 }
        return 1
    }

    /// Серия дней подряд, выведенная из дат сессий (fallback, если профиль недоступен).
    static func streakFromSessions(_ sessions: [SessionDTO], calendar: Calendar) -> Int {
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        // Серия считается, если занимались сегодня или вчера (терпимость к «ещё не сегодня»).
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        while activeDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Дневная кривая точности. Для week — последние 7 дней с короткими
    /// названиями («Пн»…); для month/quarter — по дням периода с номером дня.
    /// Дни без занятий пропускаются (никаких выдуманных точек).
    static func makeDaily(
        sessions: [SessionDTO],
        period: ProgressDashboardModels.TimePeriod,
        now: Date,
        calendar: Calendar
    ) -> [DailyAccuracy] {
        var grouped: [Date: (correct: Int, total: Int)] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            var bucket = grouped[day] ?? (0, 0)
            bucket.correct += session.correctAttempts
            bucket.total += session.totalAttempts
            grouped[day] = bucket
        }

        let sortedDays = grouped.keys.sorted()
        return sortedDays.compactMap { day -> DailyAccuracy? in
            guard let bucket = grouped[day], bucket.total > 0 else { return nil }
            let accuracy = Float(Double(bucket.correct) / Double(bucket.total))
            let label = dailyLabel(for: day, period: period, calendar: calendar)
            return DailyAccuracy(day: label, accuracy: accuracy)
        }
    }

    /// Понедельные (или помесячные для quarter) агрегаты для линейного графика.
    static func makeWeekly(
        sessions: [SessionDTO],
        period: ProgressDashboardModels.TimePeriod,
        now: Date,
        calendar: Calendar
    ) -> [WeeklyAccuracy] {
        let useMonths = (period == .quarter)
        let component: Calendar.Component = useMonths ? .month : .weekOfYear

        var grouped: [Date: (correct: Int, total: Int)] = [:]
        for session in sessions {
            let anchor: Date
            if useMonths {
                let comps = calendar.dateComponents([.year, .month], from: session.date)
                anchor = calendar.date(from: comps) ?? calendar.startOfDay(for: session.date)
            } else {
                anchor = calendar.dateInterval(of: component, for: session.date)?.start
                    ?? calendar.startOfDay(for: session.date)
            }
            var bucket = grouped[anchor] ?? (0, 0)
            bucket.correct += session.correctAttempts
            bucket.total += session.totalAttempts
            grouped[anchor] = bucket
        }

        let sortedKeys = grouped.keys.sorted()
        return sortedKeys.enumerated().compactMap { index, key -> WeeklyAccuracy? in
            guard let bucket = grouped[key], bucket.total > 0 else { return nil }
            let accuracy = Float(Double(bucket.correct) / Double(bucket.total))
            let prefix = useMonths
                ? String(localized: "progressDashboard.chart.monthPrefix")
                : String(localized: "progressDashboard.chart.weekPrefix")
            let label = "\(prefix) \(index + 1)"
            return WeeklyAccuracy(weekIndex: index + 1, label: label, accuracy: accuracy)
        }
    }

    /// Прогресс по звукам: точность (взвешенная) + число сессий + тренд
    /// (сравнение первой и второй половины окна по звуку).
    static func makeSounds(sessions: [SessionDTO]) -> [SoundProgress] {
        let bySound = Dictionary(grouping: sessions) { $0.targetSound }
            .filter { !$0.key.isEmpty }

        return bySound.map { sound, soundSessions -> SoundProgress in
            let ordered = soundSessions.sorted { $0.date < $1.date }
            let accuracy = weightedAccuracy(ordered)
            let trend = trend(for: ordered)
            return SoundProgress(
                sound: sound,
                accuracy: Float(accuracy),
                sessions: ordered.count,
                trend: trend
            )
        }
        .sorted { $0.sound < $1.sound }
    }

    /// История по конкретному звуку для detail-экрана (дневная кривая по звуку).
    static func makeSoundHistory(
        sessions: [SessionDTO],
        period: ProgressDashboardModels.TimePeriod,
        now: Date,
        calendar: Calendar
    ) -> [String: [DailyAccuracy]] {
        let bySound = Dictionary(grouping: sessions) { $0.targetSound }
            .filter { !$0.key.isEmpty }
        var result: [String: [DailyAccuracy]] = [:]
        for (sound, soundSessions) in bySound {
            result[sound] = makeDaily(
                sessions: soundSessions,
                period: period,
                now: now,
                calendar: calendar
            )
        }
        return result
    }

    /// Тренд звука: сравнение средней точности первой и второй половины серии.
    static func trend(for sessions: [SessionDTO]) -> ProgressTrend {
        guard sessions.count >= 2 else { return .stable }
        let mid = sessions.count / 2
        let firstHalf = Array(sessions.prefix(mid))
        let secondHalf = Array(sessions.suffix(sessions.count - mid))
        let before = weightedAccuracy(firstHalf)
        let after = weightedAccuracy(secondHalf)
        let delta = after - before
        if delta > 0.05 { return .up }
        if delta < -0.05 { return .down }
        return .stable
    }

    // MARK: - Labels

    private static func dailyLabel(
        for day: Date,
        period: ProgressDashboardModels.TimePeriod,
        calendar: Calendar
    ) -> String {
        switch period {
        case .week:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "EEEEEE"   // «пн», «вт» …
            return formatter.string(from: day).capitalized
        case .month, .quarter:
            let dayNumber = calendar.component(.day, from: day)
            let month = calendar.component(.month, from: day)
            return "\(dayNumber).\(month)"
        }
    }
}
