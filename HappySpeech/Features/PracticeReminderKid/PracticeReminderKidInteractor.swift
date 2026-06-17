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

    /// Загружает реальные минуты/серию/имя/целевой звук. Безопасно без репозиториев/childId.
    func load() async {
        guard let sessionRepository, !childId.isEmpty else {
            // Имя и звук даже без сессий — из профиля.
            let profile = await loadChildProfile()
            state.childName = profile?.name ?? ""
            state.targetSound = profile?.targetSounds.first ?? ""
            state.isLoading = false
            Self.logger.info("reminder load skipped (no sessionRepository/childId)")
            return
        }
        do {
            async let sessionsFetch = sessionRepository.fetchRecent(childId: childId, limit: 120)
            async let profileFetch: ChildProfileDTO? = loadChildProfile()
            let sessions = try await sessionsFetch
            let profile = await profileFetch
            let minutes = minutesToday(in: sessions)
            let streak = await loadStreak(fallback: sessions)
            state.minutesToday = minutes
            state.streakDays = streak
            state.childName = profile?.name ?? ""
            state.targetSound = profile?.targetSounds.first ?? ""
            state.isLoading = false
            Self.logger.info("reminder loaded (min=\(minutes), streak=\(streak), name=\(self.state.childName, privacy: .private))")
        } catch {
            state.isLoading = false
            Self.logger.error("reminder load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadChildProfile() async -> ChildProfileDTO? {
        guard let childRepository, !childId.isEmpty else { return nil }
        return try? await childRepository.fetch(id: childId)
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
        StreakCalculator.activeDayStreak(in: sessions, calendar: calendar)
    }
}
