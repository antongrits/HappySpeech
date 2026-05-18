import Foundation
import OSLog

// MARK: - PlainProgressWorkerProtocol

@MainActor
protocol PlainProgressWorkerProtocol: AnyObject {
    /// Собирает агрегированную аналитику ребёнка за неделю/месяц.
    func loadProgress(childId: String) async throws -> PlainProgressModels.Load.Response
}

// MARK: - PlainProgressWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Изолированный сервисный вызов: читает профиль и сессии ребёнка из
// репозиториев, считает метрики по периодам и определяет тренд.
// Полностью offline / on-device.

@MainActor
final class PlainProgressWorker: PlainProgressWorkerProtocol {

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PlainProgress.Worker"
    )

    /// Порог «заметного» изменения точности неделя-к-неделе.
    private static let trendThreshold = 0.06

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    func loadProgress(childId: String) async throws -> PlainProgressModels.Load.Response {
        let child = try await childRepository.fetch(id: childId)
        let sessions = try await sessionRepository.fetchAll(childId: childId)

        let now = Date()
        let calendar = Calendar.current

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let monthPlusWeek = calendar.date(byAdding: .day, value: -37, to: now) ?? now

        let weekSessions = sessions.filter { $0.date >= weekAgo }
        let prevWeekSessions = sessions.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }
        let monthAgoSessions = sessions.filter { $0.date >= monthPlusWeek && $0.date < monthAgo }

        let weekRate = Self.averageRate(weekSessions)
        let prevWeekRate = Self.averageRate(prevWeekSessions)
        let monthAgoRate = Self.averageRate(monthAgoSessions)

        let focusSound = Self.dominantSound(in: weekSessions)
            ?? child.targetSounds.first
            ?? "—"
        let focusSessions = weekSessions.filter { $0.targetSound == focusSound }
        let focusRate = focusSessions.isEmpty
            ? weekRate
            : Self.averageRate(focusSessions)

        let practiceSeconds = weekSessions.reduce(0) { $0 + $1.durationSeconds }
        let trend = Self.computeTrend(
            week: weekRate,
            previousWeek: prevWeekRate,
            hasWeekData: !weekSessions.isEmpty
        )

        let response = PlainProgressModels.Load.Response(
            childName: child.name,
            childAge: child.age,
            weekSuccessRate: weekRate,
            previousWeekSuccessRate: prevWeekRate,
            monthAgoSuccessRate: monthAgoRate,
            sessionsThisWeek: weekSessions.count,
            practiceMinutesThisWeek: practiceSeconds / 60,
            focusSound: focusSound,
            focusSoundRate: focusRate,
            targetSounds: child.targetSounds,
            currentStreak: child.currentStreak,
            trend: trend,
            hasWeekData: !weekSessions.isEmpty
        )
        Self.logger.debug(
            "Loaded plain progress: \(weekSessions.count) week sessions, trend \(trend.rawValue, privacy: .public)"
        )
        return response
    }

    // MARK: - Aggregation helpers

    private static func averageRate(_ sessions: [SessionDTO]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let sum = sessions.reduce(0.0) { $0 + $1.successRate }
        return sum / Double(sessions.count)
    }

    /// Звук с наибольшим числом сессий за период.
    private static func dominantSound(in sessions: [SessionDTO]) -> String? {
        guard !sessions.isEmpty else { return nil }
        let counts = Dictionary(grouping: sessions, by: { $0.targetSound })
            .mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }

    private static func computeTrend(
        week: Double,
        previousWeek: Double,
        hasWeekData: Bool
    ) -> PlainProgressDirection {
        guard hasWeekData else { return .noData }
        let delta = week - previousWeek
        if delta >= trendThreshold {
            return .improved
        } else if delta <= -trendThreshold {
            return .declined
        } else {
            return .steady
        }
    }
}
