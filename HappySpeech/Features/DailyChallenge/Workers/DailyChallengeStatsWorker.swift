import Foundation
import OSLog

// MARK: - DailyChallengeStatsWorkerProtocol

@MainActor
protocol DailyChallengeStatsWorkerProtocol: AnyObject {
    /// Возвращает сессии ребёнка, попавшие в указанный день.
    func fetchTodaySessions(childId: String, day: Date) async -> [SessionDTO]

    /// Прогресс в зависимости от типа цели.
    ///   - .repetitions → суммарные attempts (correct)
    ///   - .minutes     → суммарные минуты
    ///   - .soundFocus  → количество correct attempts с targetSound
    ///   - .streakKeep  → 1 если был хотя бы один сеанс сегодня, иначе 0
    func progress(
        for kind: DailyGoalKind,
        targetSound: String,
        sessions: [SessionDTO]
    ) -> Int

    /// Текущий streak — учитывает «есть ли сессия сегодня».
    func computeStreak(childId: String) async -> StreakState
}

// MARK: - DailyChallengeStatsWorker

@MainActor
final class DailyChallengeStatsWorker: DailyChallengeStatsWorkerProtocol {

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository
    private let calendar: Calendar

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyChallenge.StatsWorker"
    )

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository,
        calendar: Calendar = .current
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
        self.calendar = calendar
    }

    func fetchTodaySessions(childId: String, day: Date) async -> [SessionDTO] {
        do {
            // Берём последние 32 сессии — этого достаточно, чтобы покрыть один день
            // даже у самого активного ребёнка.
            let recent = try await sessionRepository.fetchRecent(childId: childId, limit: 32)
            let filtered = recent.filter { calendar.isDate($0.date, inSameDayAs: day) }
            Self.logger.debug("today sessions=\(filtered.count, privacy: .public) child=\(childId, privacy: .private)")
            return filtered
        } catch {
            Self.logger.error("fetchTodaySessions failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func progress(
        for kind: DailyGoalKind,
        targetSound: String,
        sessions: [SessionDTO]
    ) -> Int {
        switch kind {
        case .repetitions:
            return sessions.reduce(0) { $0 + $1.correctAttempts }

        case .minutes:
            let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
            return totalSeconds / 60

        case .soundFocus:
            return sessions
                .filter { $0.targetSound == targetSound }
                .reduce(0) { $0 + $1.correctAttempts }

        case .streakKeep:
            return sessions.isEmpty ? 0 : 1
        }
    }

    func computeStreak(childId: String) async -> StreakState {
        do {
            let profile = try await childRepository.fetch(id: childId)
            let lastISO: String? = profile.lastSessionAt.map {
                ISO8601DateFormatter().string(from: $0)
            }
            // Текущий streak храним в Realm; «longest» оцениваем как max(current, current).
            // Реальный longest можно отслеживать в отдельной коллекции — для AE batch 2 v21
            // достаточно эвристики «не меньше текущего».
            return StreakState(
                current: profile.currentStreak,
                longest: max(profile.currentStreak, profile.currentStreak),
                lastSessionISO: lastISO
            )
        } catch {
            Self.logger.error("computeStreak failed: \(error.localizedDescription, privacy: .public)")
            return StreakState(current: 0, longest: 0, lastSessionISO: nil)
        }
    }
}
