import Foundation
import OSLog

// MARK: - AchievementCalendarInteractor

/// Бизнес-логика календаря достижений (родительский контур).
///
/// При наличии `SessionRepository` раскладывает реальную активность текущего
/// месяца по дням: число «достижений» за день (успешные сессии с точностью
/// ≥ порога) и подпись лучшего достижения. Без репозитория (Preview/тесты) —
/// остаётся на пустом `.initial` (честный календарь без выдумок).
@MainActor
@Observable
final class AchievementCalendarInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AchievementCalendar"
    )

    /// Порог точности сессии, при котором она считается «достижением».
    private static let achievementThreshold: Double = 0.80

    let childId: String
    var state: AchievementCalendarModels.ViewState

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

    /// Пересобирает календарь из реальных сессий. Безопасно без репозитория/childId.
    func refresh() {
        guard let sessionRepository, !childId.isEmpty else {
            Self.logger.info("achievement calendar refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sessions = try await sessionRepository.fetchRecent(childId: self.childId, limit: 500)
                self.state = self.makeState(from: sessions)
                Self.logger.info("achievement calendar refreshed: total=\(self.state.totalAchievements, privacy: .public)")
            } catch {
                Self.logger.error("achievement calendar refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func selectDay(_ day: Int) {
        state.selectedDay = (state.selectedDay == day) ? nil : day
        Self.logger.info("selectDay \(day)")
    }

    var selectedEntry: AchievementCalendarModels.DayEntry? {
        guard let day = state.selectedDay else { return nil }
        return state.days.first(where: { $0.day == day })
    }

    // MARK: - Aggregation

    /// Заполняет дни текущего месяца достижениями из сессий.
    func makeState(from sessions: [SessionDTO], now: Date = Date()) -> AchievementCalendarModels.ViewState {
        let dayCount = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Группируем сессии текущего месяца по номеру дня.
        var byDay: [Int: [SessionDTO]] = [:]
        for session in sessions {
            let comps = calendar.dateComponents([.year, .month, .day], from: session.date)
            guard comps.year == currentYear, comps.month == currentMonth, let d = comps.day else { continue }
            byDay[d, default: []].append(session)
        }

        let days: [AchievementCalendarModels.DayEntry] = (1...dayCount).map { d in
            let group = byDay[d] ?? []
            // «Достижение» — сессия с точностью ≥ порога.
            let achieving = group.filter { $0.successRate >= Self.achievementThreshold }
            let best = group.max { $0.successRate < $1.successRate }
            let top: String? = achieving.isEmpty ? nil : Self.achievementLabel(for: best)
            return AchievementCalendarModels.DayEntry(
                id: d,
                day: d,
                achievementCount: achieving.count,
                topAchievement: top
            )
        }

        return AchievementCalendarModels.ViewState(
            month: AchievementCalendarModels.ViewState.monthTitle(now, calendar: calendar),
            days: days,
            selectedDay: nil
        )
    }

    /// Подпись достижения по лучшей сессии дня (звук + точность).
    private static func achievementLabel(for session: SessionDTO?) -> String {
        guard let session else { return "Достижение дня" }
        let percent = Int((session.successRate * 100).rounded())
        if !session.targetSound.isEmpty {
            return "Звук «\(session.targetSound)» — \(percent)%"
        }
        return "Точность \(percent)%"
    }
}
