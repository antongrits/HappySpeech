import Foundation
import OSLog

// MARK: - ParentDailyDigestInteractor

/// Бизнес-логика экрана «Дневной дайджест родителя».
///
/// При наличии `SessionRepository` пересобирает KPI-плитки (минуты, точность,
/// серия) из реальных сессий ребёнка за текущий день / историю. Когда репозиторий
/// не передан (Preview, юнит-тесты) — остаётся на seed-состоянии `.initial`.
@MainActor
@Observable
final class ParentDailyDigestInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentDailyDigest"
    )

    var state: ParentDailyDigestModels.ViewState

    private let sessionRepository: (any SessionRepository)?
    private let childId: String
    private let calendar: Calendar

    init(
        sessionRepository: (any SessionRepository)? = nil,
        childId: String = "",
        calendar: Calendar = .current
    ) {
        self.sessionRepository = sessionRepository
        self.childId = childId
        self.calendar = calendar
        self.state = .initial
        Self.logger.info("digest loaded")
    }

    /// Пересобирает дайджест. Если репозитория нет или childId пуст — оставляет
    /// текущее состояние нетронутым (безопасно для Preview/тестов).
    func refresh() {
        guard let repository = sessionRepository, !childId.isEmpty else {
            Self.logger.info("digest refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sessions = try await repository.fetchRecent(childId: self.childId, limit: 60)
                self.state = self.makeState(from: sessions)
                Self.logger.info("digest refreshed from \(sessions.count, privacy: .public) sessions")
            } catch {
                Self.logger.error("digest refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Aggregation

    /// Строит `ViewState` из реальных сессий: минуты и точность за сегодня,
    /// серия активных дней подряд. Текстовый момент дня и совет берутся из seed
    /// (контент-движок советов — отдельная фича), KPI обновляются по фактам.
    func makeState(from sessions: [SessionDTO]) -> ParentDailyDigestModels.ViewState {
        let today = calendar.startOfDay(for: Date())
        let todaySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: today) }

        let todaySeconds = todaySessions.reduce(0) { $0 + $1.durationSeconds }
        let todayMinutes = max(0, Int((Double(todaySeconds) / 60.0).rounded()))

        let totalAttempts = todaySessions.reduce(0) { $0 + $1.totalAttempts }
        let correctAttempts = todaySessions.reduce(0) { $0 + $1.correctAttempts }
        let accuracyPercent = totalAttempts > 0
            ? Int((Double(correctAttempts) / Double(totalAttempts) * 100).rounded())
            : 0

        let streak = activeDayStreak(in: sessions, today: today)

        var newState = ParentDailyDigestModels.ViewState.initial
        newState.kpis = [
            ParentDailyDigestModels.KPI(
                id: "min",
                icon: "clock.fill",
                value: String(
                    format: String(localized: "parentDigest.kpi.minutes %lld"),
                    todayMinutes
                ),
                label: String(localized: "parentDigest.kpi.today")
            ),
            ParentDailyDigestModels.KPI(
                id: "score",
                icon: "star.fill",
                value: "\(accuracyPercent)%",
                label: String(localized: "parentDigest.kpi.accuracy")
            ),
            ParentDailyDigestModels.KPI(
                id: "streak",
                icon: "flame.fill",
                value: String(
                    format: String(localized: "parentDigest.kpi.days %lld"),
                    streak
                ),
                label: String(localized: "parentDigest.kpi.streak")
            ),
            ParentDailyDigestModels.KPI(
                id: "sessions",
                icon: "checkmark.seal.fill",
                value: "\(todaySessions.count)",
                label: String(localized: "parentDigest.kpi.sessions")
            )
        ]
        return newState
    }

    /// Считает серию активных дней подряд, заканчивающуюся сегодня или вчера.
    /// «Активный день» — день, в который есть хотя бы одна сессия.
    func activeDayStreak(in sessions: [SessionDTO], today: Date) -> Int {
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

        // Стартуем с сегодня; если сегодня нет активности, но есть вчера —
        // допускаем «вчерашний» хвост, чтобы не обнулять серию до конца дня.
        var cursor = today
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
