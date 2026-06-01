import Foundation
import OSLog

// MARK: - DailyMissionsHubInteractor

/// Бизнес-логика хаба ежедневных миссий.
///
/// Выполнение миссий складывается из двух источников реальных данных:
/// 1. **Авто-выполнение** — если сегодня уже была сессия с подходящим
///    `templateType` (из истории `SessionRepository`), миссия отмечается
///    выполненной автоматически.
/// 2. **Ручная отметка** — `markCompleted` сохраняет выбор в `UserDefaults`
///    с привязкой к ребёнку и текущему дню, поэтому отметки переживают
///    перезапуск приложения и сбрасываются на следующий день.
@MainActor
@Observable
final class DailyMissionsHubInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyMissionsHub"
    )

    let childId: String
    var state: DailyMissionsHubModels.ViewState = .init()

    private let sessionRepository: (any SessionRepository)?
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(
        childId: String,
        sessionRepository: (any SessionRepository)? = nil,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.childId = childId
        self.sessionRepository = sessionRepository
        self.defaults = defaults
        self.calendar = calendar
        // Загружаем ранее сохранённые ручные отметки за сегодня сразу,
        // чтобы экран не «мигал» пустым до завершения async-fetch.
        self.state.completed = loadManualCompletions()
    }

    /// Пересобирает выполнение миссий: объединяет ручные отметки за сегодня
    /// и авто-выполнение из реальных сессий. Безопасно без репозитория/childId.
    func refresh() {
        guard let repository = sessionRepository, !childId.isEmpty else {
            Self.logger.info("missions refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sessions = try await repository.fetchRecent(childId: self.childId, limit: 40)
                let auto = self.autoCompleted(from: sessions)
                let manual = self.loadManualCompletions()
                self.state.completed = auto.union(manual)
                Self.logger.info("missions refreshed: auto=\(auto.count, privacy: .public) manual=\(manual.count, privacy: .public)")
            } catch {
                Self.logger.error("missions refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func markCompleted(_ mission: DailyMissionsHubModels.Mission) {
        state.completed.insert(mission)
        persistManual(mission)
        Self.logger.info("Mission completed: \(mission.rawValue, privacy: .public)")
    }

    // MARK: - Auto-completion

    /// Миссии, выполненные сегодня по факту сессий нужного типа.
    func autoCompleted(from sessions: [SessionDTO]) -> Set<DailyMissionsHubModels.Mission> {
        let today = calendar.startOfDay(for: Date())
        let todayTypes = Set(
            sessions
                .filter { calendar.isDate($0.date, inSameDayAs: today) }
                .map(\.templateType)
        )
        var result: Set<DailyMissionsHubModels.Mission> = []
        for mission in DailyMissionsHubModels.Mission.allCases
        where !mission.matchingTemplateTypes.isDisjoint(with: todayTypes) {
            result.insert(mission)
        }
        return result
    }

    // MARK: - Manual completion persistence (per child + day)

    private var storageKey: String {
        let dayStamp = calendar.startOfDay(for: Date()).timeIntervalSince1970
        return "dailyMissions.\(childId).\(Int(dayStamp))"
    }

    private func loadManualCompletions() -> Set<DailyMissionsHubModels.Mission> {
        guard !childId.isEmpty,
              let raw = defaults.array(forKey: storageKey) as? [String] else {
            return []
        }
        return Set(raw.compactMap(DailyMissionsHubModels.Mission.init(rawValue:)))
    }

    private func persistManual(_ mission: DailyMissionsHubModels.Mission) {
        guard !childId.isEmpty else { return }
        var stored = loadManualCompletions()
        stored.insert(mission)
        defaults.set(stored.map(\.rawValue), forKey: storageKey)
    }
}
