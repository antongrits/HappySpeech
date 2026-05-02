import Foundation
import OSLog

// MARK: - NotificationsHubWorker
//
// Агрегирует in-app уведомления для родителя:
// — напоминания о практике (на основе lastSessionAt)
// — unlock achievements
// — рекомендации логопеда (rule-based)
// Не использует push / UNNotification — только in-app feed карточки.

enum NotificationsHubWorker {

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "NotificationsHubWorker")

    // MARK: - Public API

    static func buildNotifications(
        child: ChildProfileDTO,
        sessions: [SessionDTO],
        achievements: [ParentHomeModels.AchievementItem],
        now: Date = Date()
    ) -> [ParentHomeModels.NotificationItem] {
        var items: [ParentHomeModels.NotificationItem] = []

        // 1. Напоминание о практике: нет занятий сегодня
        items += practiceReminders(child: child, sessions: sessions, now: now)

        // 2. Новые достижения за последние 24 часа
        items += achievementNotifications(achievements: achievements, now: now)

        // 3. Рекомендация специалиста: если EF < 1.5 для любого звука
        items += specialistNotifications(child: child, sessions: sessions)

        // 4. Поздравление: стрик 7+ дней
        if child.currentStreak >= 7 {
            items.append(.init(
                id: "streak_congrats_\(child.currentStreak)",
                icon: "flame.fill",
                title: String(
                    format: String(localized: "notification.streak.title"),
                    child.currentStreak
                ),
                body: String(
                    format: String(localized: "notification.streak.body"),
                    child.name
                ),
                kind: .achievement,
                date: now,
                isRead: false
            ))
        }

        let sorted = items.sorted { $0.date > $1.date }
        logger.debug("NotificationsHubWorker: \(sorted.count) notifications built")
        return sorted
    }

    // MARK: - Private

    private static func practiceReminders(
        child: ChildProfileDTO,
        sessions: [SessionDTO],
        now: Date
    ) -> [ParentHomeModels.NotificationItem] {
        let calendar = Calendar.current
        let todaySessions = sessions.filter { calendar.isDateInToday($0.date) }
        guard todaySessions.isEmpty else { return [] }

        // Если вчера было занятие — мягкое напоминание
        let yesterdaySessions = sessions.filter { calendar.isDateInYesterday($0.date) }
        if yesterdaySessions.isEmpty {
            return [.init(
                id: "reminder_practice_\(Int(now.timeIntervalSince1970))",
                icon: "bell.fill",
                title: String(localized: "notification.practice.title"),
                body: String(format: String(localized: "notification.practice.body_no_session"), child.name),
                kind: .reminder,
                date: now.addingTimeInterval(-3600),
                isRead: false
            )]
        }
        return [.init(
            id: "reminder_daily_\(Int(now.timeIntervalSince1970))",
            icon: "bell.badge.fill",
            title: String(localized: "notification.practice.title"),
            body: String(format: String(localized: "notification.practice.body_daily"), child.name),
            kind: .reminder,
            date: now.addingTimeInterval(-1800),
            isRead: false
        )]
    }

    private static func achievementNotifications(
        achievements: [ParentHomeModels.AchievementItem],
        now: Date
    ) -> [ParentHomeModels.NotificationItem] {
        let cutoff = now.addingTimeInterval(-86400)
        return achievements
            .filter { $0.unlockedAt >= cutoff }
            .map { ach in
                ParentHomeModels.NotificationItem(
                    id: "ach_\(ach.id)",
                    icon: ach.icon,
                    title: String(localized: "notification.achievement.title"),
                    body: ach.title,
                    kind: .achievement,
                    date: ach.unlockedAt,
                    isRead: false
                )
            }
    }

    private static func specialistNotifications(
        child: ChildProfileDTO,
        sessions: [SessionDTO]
    ) -> [ParentHomeModels.NotificationItem] {
        let sounds = child.targetSounds
        let needsReview = sounds.filter { sound in
            let soundSessions = sessions.filter { $0.targetSound == sound }
            let state = SoundProgressAggregator.aggregate(soundTarget: sound, sessions: soundSessions)
            return state.needsSpecialistReview
        }
        guard !needsReview.isEmpty else { return [] }
        let soundsList = needsReview.joined(separator: ", ")
        return [.init(
            id: "specialist_review_\(soundsList)",
            icon: "person.text.rectangle",
            title: String(localized: "notification.specialist.title"),
            body: String(format: String(localized: "notification.specialist.body"), soundsList),
            kind: .specialistMessage,
            date: Date().addingTimeInterval(-7200),
            isRead: false
        )]
    }
}
