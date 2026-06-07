import Foundation
import OSLog

// MARK: - PracticeReminderKidInteractor (Clean Swift: Interactor)
//
// Считает РЕАЛЬНЫЕ минуты практики за сегодня (сумма длительностей
// сегодняшних сессий) и текущую серию активных дней (профиль → fallback
// по сессиям). Источник — `SessionRepository`/`ChildRepository`.
// Без репозиториев (Preview/тесты) остаётся на нулевом `.initial`.

@MainActor
@Observable
final class PracticeReminderKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PracticeReminderKid"
    )

    let childId: String
    var state: PracticeReminderKidModels.ViewState

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

    /// Загружает реальные минуты/серию. Безопасно без репозиториев/childId.
    func load() async {
        guard let sessionRepository, !childId.isEmpty else {
            state.isLoading = false
            Self.logger.info("reminder load skipped (no repository/childId)")
            return
        }
        do {
            let sessions = try await sessionRepository.fetchRecent(childId: childId, limit: 120)
            let minutes = minutesToday(in: sessions)
            let streak = await loadStreak(fallback: sessions)
            state.minutesToday = minutes
            state.streakDays = streak
            state.isLoading = false
            Self.logger.info("reminder loaded (min=\(minutes), streak=\(streak))")
        } catch {
            state.isLoading = false
            Self.logger.error("reminder load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func snooze() {
        state.isDismissed = true
        Self.logger.info("snoozed reminder for \(self.childId, privacy: .public)")
    }

    // MARK: - Aggregation

    /// Минуты практики за сегодня из реальных сессий.
    func minutesToday(in sessions: [SessionDTO]) -> Int {
        let today = calendar.startOfDay(for: Date())
        let todaySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: today) }
        let seconds = todaySessions.reduce(0) { $0 + $1.durationSeconds }
        return max(0, Int((Double(seconds) / 60.0).rounded()))
    }

    /// Серия активных дней: профиль (`currentStreak`) → fallback по сессиям.
    private func loadStreak(fallback sessions: [SessionDTO]) async -> Int {
        if let childRepository {
            do {
                let profile = try await childRepository.fetch(id: childId)
                if profile.currentStreak > 0 { return profile.currentStreak }
            } catch {
                Self.logger.debug("reminder: profile streak unavailable, computing from sessions")
            }
        }
        return activeDayStreak(in: sessions)
    }

    /// Серия активных дней подряд, заканчивающаяся сегодня или вчера.
    func activeDayStreak(in sessions: [SessionDTO]) -> Int {
        let today = calendar.startOfDay(for: Date())
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

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
