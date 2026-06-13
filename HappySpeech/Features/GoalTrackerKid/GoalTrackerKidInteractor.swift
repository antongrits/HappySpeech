import Foundation
import OSLog

// MARK: - GoalTrackerKidInteractor

/// Бизнес-логика «трекера целей» ребёнка.
///
/// При наличии репозиториев считает фактический прогресс по целям за сегодня:
/// - минуты практики (сумма длительностей сегодняшних сессий);
/// - число разных звуков, отработанных сегодня;
/// - текущая серия активных дней.
/// Без репозиториев (Preview/тесты) — остаётся на нулевом `.initial`.
@MainActor
@Observable
final class GoalTrackerKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "GoalTrackerKid"
    )

    let childId: String
    var state: GoalTrackerKidModels.ViewState

    private let sessionRepository: (any SessionRepository)?
    private let childRepository: (any ChildRepository)?
    private let calendar: Calendar

    init(
        childId: String,
        sessionRepository: (any SessionRepository)? = nil,
        childRepository: (any ChildRepository)? = nil,
        calendar: Calendar = .current
    ) {
        self.childId = childId
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
        self.calendar = calendar
        self.state = .initial
    }

    /// Пересобирает цели из реальных данных. Безопасно без репозиториев/childId.
    func refresh() {
        guard let sessionRepository, !childId.isEmpty else {
            Self.logger.info("goals refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sessions = try await sessionRepository.fetchRecent(childId: self.childId, limit: 120)
                let streak = await self.loadStreak(fallback: sessions)
                self.state = self.makeState(from: sessions, streak: streak)
                Self.logger.info("goals refreshed (overall=\(Int(self.state.overallProgress * 100), privacy: .public)%)")
            } catch {
                Self.logger.error("goals refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func reset() {
        state = .initial
    }

    // MARK: - Aggregation

    /// Строит цели из сегодняшних сессий + серии дней.
    func makeState(from sessions: [SessionDTO], streak: Int) -> GoalTrackerKidModels.ViewState {
        let today = calendar.startOfDay(for: Date())
        let todaySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: today) }

        let todaySeconds = todaySessions.reduce(0) { $0 + $1.durationSeconds }
        let minutes = max(0, Int((Double(todaySeconds) / 60.0).rounded()))
        let distinctSounds = Set(todaySessions.map(\.targetSound).filter { !$0.isEmpty }).count

        return GoalTrackerKidModels.ViewState(goals: [
            GoalTrackerKidModels.Goal(
                id: .minutesToday,
                current: minutes,
                target: GoalTrackerKidModels.ViewState.target(for: .minutesToday)
            ),
            GoalTrackerKidModels.Goal(
                id: .newSounds,
                current: distinctSounds,
                target: GoalTrackerKidModels.ViewState.target(for: .newSounds)
            ),
            GoalTrackerKidModels.Goal(
                id: .streakDays,
                current: streak,
                target: GoalTrackerKidModels.ViewState.target(for: .streakDays)
            )
        ])
    }

    /// Серия активных дней: берём из профиля (`currentStreak`), а если профиль
    /// недоступен — считаем по сессиям как fallback.
    private func loadStreak(fallback sessions: [SessionDTO]) async -> Int {
        if let childRepository {
            do {
                let profile = try await childRepository.fetch(id: childId)
                if profile.currentStreak > 0 { return profile.currentStreak }
            } catch {
                Self.logger.debug("goals: profile streak unavailable, computing from sessions")
            }
        }
        return activeDayStreak(in: sessions)
    }

    /// Серия активных дней подряд, заканчивающаяся сегодня или вчера.
    func activeDayStreak(in sessions: [SessionDTO]) -> Int {
        StreakCalculator.activeDayStreak(in: sessions, calendar: calendar)
    }
}
