import Foundation
import OSLog

// MARK: - AchievementsSnapshotWorker
//
// Формирует последние N разблокированных достижений для карточки на ParentHome.
// Чистая функция над сессиями — без I/O, без LLM (kid-safe агрегация).

enum AchievementsSnapshotWorker {

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "AchievementsSnapshotWorker")

    // MARK: - Public API

    /// Возвращает последние `limit` ачивок, вычисленных из сессий.
    /// Логика: стрики, первый правильный для звука, идеальная сессия (100%), марафон (7 дней).
    static func buildSnapshot(
        from sessions: [SessionDTO],
        childName: String,
        limit: Int = 5
    ) -> [ParentHomeModels.AchievementItem] {
        var items: [ParentHomeModels.AchievementItem] = []

        // 1. Идеальные сессии (100% accuracy)
        let perfectSessions = sessions.filter { $0.totalAttempts > 0 && $0.correctAttempts == $0.totalAttempts }
        if !perfectSessions.isEmpty {
            items.append(.init(
                id: "perfect_session",
                icon: "star.circle.fill",
                title: String(localized: "achievement.perfect_session.title"),
                subtitle: String(format: String(localized: "achievement.perfect_session.subtitle"), perfectSessions.count),
                unlockedAt: perfectSessions.map(\.date).max() ?? Date(),
                colorToken: "gold"
            ))
        }

        // 2. Первый звук — уникальные звуки в сессиях
        let uniqueSounds = Array(Set(sessions.map(\.targetSound))).sorted()
        if !uniqueSounds.isEmpty {
            items.append(.init(
                id: "first_sounds_\(uniqueSounds.count)",
                icon: "waveform.badge.mic",
                title: String(format: String(localized: "achievement.sounds_unlocked.title"), uniqueSounds.count),
                subtitle: uniqueSounds.joined(separator: ", "),
                unlockedAt: sessions.first?.date ?? Date(),
                colorToken: "primary"
            ))
        }

        // 3. Марафон: 7+ активных дней подряд
        let streakDays = consecutiveDayStreak(from: sessions)
        if streakDays >= 7 {
            items.append(.init(
                id: "streak_\(streakDays)",
                icon: "flame.fill",
                title: String(format: String(localized: "achievement.streak.title"), streakDays),
                subtitle: String(localized: "achievement.streak.subtitle"),
                unlockedAt: Date(),
                colorToken: "warning"
            ))
        }

        // 4. Первые 10 сессий
        if sessions.count >= 10 {
            items.append(.init(
                id: "sessions_10",
                icon: "10.circle.fill",
                title: String(localized: "achievement.ten_sessions.title"),
                subtitle: String(format: String(localized: "achievement.ten_sessions.subtitle"), sessions.count),
                unlockedAt: sessions.sorted { $0.date < $1.date }.dropFirst(9).first?.date ?? Date(),
                colorToken: "success"
            ))
        }

        // 5. Отличник звука: accuracy > 90% за последние 5 сессий одного звука
        if let excellentSound = findExcellentSound(sessions: sessions) {
            items.append(.init(
                id: "excellent_\(excellentSound)",
                icon: "checkmark.seal.fill",
                title: String(format: String(localized: "achievement.master_sound.title"), excellentSound),
                subtitle: String(localized: "achievement.master_sound.subtitle"),
                unlockedAt: Date(),
                colorToken: "success"
            ))
        }

        let sorted = items.sorted { $0.unlockedAt > $1.unlockedAt }
        logger.debug("AchievementsSnapshotWorker: \(sorted.count) achievements built")
        return Array(sorted.prefix(limit))
    }

    // MARK: - Private

    private static func consecutiveDayStreak(from sessions: [SessionDTO]) -> Int {
        let calendar = Calendar.current
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        while activeDays.contains(currentDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prev
        }
        return streak
    }

    private static func findExcellentSound(sessions: [SessionDTO]) -> String? {
        let sounds = Array(Set(sessions.map(\.targetSound)))
        for sound in sounds {
            let soundSessions = sessions
                .filter { $0.targetSound == sound }
                .sorted { $0.date > $1.date }
                .prefix(5)
            guard soundSessions.count == 5 else { continue }
            let avgRate = soundSessions.map(\.successRate).reduce(0, +) / 5.0
            if avgRate >= 0.90 { return sound }
        }
        return nil
    }
}
