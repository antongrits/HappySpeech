import Foundation
import OSLog

// MARK: - SoundJournalKidInteractor

/// Бизнес-логика детского «дневника звуков».
///
/// При наличии `SessionRepository` агрегирует реальные сессии ребёнка по
/// отрабатываемому звуку: количество практик за сегодня и последний балл
/// (по фактическим попыткам). Когда репозиторий не передан (Preview, тесты)
/// или сессий ещё нет — остаётся пустое состояние `.initial` (без выдумок).
@MainActor
@Observable
final class SoundJournalKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundJournalKid"
    )

    let childId: String
    var state: SoundJournalKidModels.ViewState

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

    /// Пересобирает дневник из реальных сессий. Безопасно без репозитория/childId.
    func refresh() {
        guard let repository = sessionRepository, !childId.isEmpty else {
            Self.logger.info("sound journal refresh skipped (no repository/childId)")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sessions = try await repository.fetchRecent(childId: self.childId, limit: 120)
                self.state = self.makeState(from: sessions)
                Self.logger.info("sound journal refreshed: \(self.state.entries.count, privacy: .public) sounds")
            } catch {
                Self.logger.error("sound journal refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func select(_ id: String) {
        state.selectedEntryId = (state.selectedEntryId == id) ? nil : id
        Self.logger.info("select entry \(id, privacy: .public)")
    }

    // MARK: - Aggregation

    /// Группирует сессии по `targetSound`. Для каждого звука:
    /// - `timesPracticed` — число сегодняшних сессий по этому звуку;
    /// - `lastScore` — последний фактический балл (по самой свежей сессии),
    ///   процент от 0 до 100 (успешные попытки / все попытки).
    /// Звуки сортируются по числу практик сегодня, затем по последнему баллу.
    func makeState(from sessions: [SessionDTO]) -> SoundJournalKidModels.ViewState {
        let today = calendar.startOfDay(for: Date())
        // Группировка по звуку.
        var bySound: [String: [SessionDTO]] = [:]
        for session in sessions where !session.targetSound.isEmpty {
            bySound[session.targetSound, default: []].append(session)
        }

        var entries: [SoundJournalKidModels.Entry] = bySound.compactMap { sound, group in
            let sortedByDate = group.sorted { $0.date > $1.date }
            let todayCount = group.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
            guard let latest = sortedByDate.first else { return nil }
            let rate = latest.totalAttempts > 0
                ? Double(latest.correctAttempts) / Double(latest.totalAttempts)
                : 0
            let lastScore = Int((rate * 100).rounded())
            // Если сегодня не практиковался, показываем общее число сессий по звуку,
            // чтобы дневник не выглядел пустым после паузы — но честно (фактические сессии).
            let times = todayCount > 0 ? todayCount : group.count
            return SoundJournalKidModels.Entry(
                id: sound,
                sound: sound,
                timesPracticed: times,
                lastScore: lastScore,
                emoji: SoundJournalKidModels.emoji(for: sound)
            )
        }

        entries.sort {
            if $0.timesPracticed != $1.timesPracticed {
                return $0.timesPracticed > $1.timesPracticed
            }
            return $0.lastScore > $1.lastScore
        }

        return SoundJournalKidModels.ViewState(entries: entries, selectedEntryId: nil)
    }
}
