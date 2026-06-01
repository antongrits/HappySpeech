import Foundation
import OSLog

// MARK: - HabitStreakDashboardInteractor

/// Бизнес-логика тепловой карты привычки.
///
/// При наличии `SessionRepository` раскладывает реальные минуты практики по
/// 84 дням (12 недель) тепловой карты. Без репозитория (Preview/тесты) —
/// остаётся на демонстрационном `.initial`.
@MainActor
@Observable
final class HabitStreakDashboardInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HabitStreakDashboard"
    )

    let childId: String
    var state: HabitStreakDashboardModels.ViewState

    private let sessionRepository: (any SessionRepository)?
    private let calendar: Calendar

    init(
        childId: String,
        sessionRepository: (any SessionRepository)? = nil,
        calendar: Calendar = .current
    ) {
        self.childId = childId
        self.sessionRepository = sessionRepository
        self.calendar = calendar
        self.state = .initial
    }

    /// Пересобирает карту из реальных сессий. Безопасно без репозитория/childId.
    func refresh() {
        guard let sessionRepository, !childId.isEmpty else {
            Self.logger.info("habit streak refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sessions = try await sessionRepository.fetchRecent(childId: self.childId, limit: 500)
                self.state = self.makeState(from: sessions)
                Self.logger.info("habit streak refreshed: streak=\(self.state.currentStreak, privacy: .public) total=\(self.state.totalMinutes, privacy: .public)min")
            } catch {
                Self.logger.error("habit streak refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func select(_ day: HabitStreakDashboardModels.Day) {
        state.selected = day
        Self.logger.info("select day=\(day.id) minutes=\(day.minutes)")
    }

    func clearSelection() {
        state.selected = nil
    }

    // MARK: - Aggregation

    /// Суммирует длительности сессий по дню и раскладывает на 84-дневное окно,
    /// где последняя ячейка (offset = totalCells-1) — сегодня.
    func makeState(from sessions: [SessionDTO]) -> HabitStreakDashboardModels.ViewState {
        let total = HabitStreakDashboardModels.ViewState.totalCells
        let today = calendar.startOfDay(for: Date())

        var minutesByOffset: [Int: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            guard let daysAgo = calendar.dateComponents([.day], from: day, to: today).day,
                  daysAgo >= 0 else { continue }
            // offset: сегодня = total-1, вчера = total-2, …
            let offset = (total - 1) - daysAgo
            guard offset >= 0 else { continue }
            let minutes = Int((Double(session.durationSeconds) / 60.0).rounded())
            minutesByOffset[offset, default: 0] += minutes
        }

        return HabitStreakDashboardModels.ViewState.make(minutesByOffset: minutesByOffset)
    }
}
