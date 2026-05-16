@testable import HappySpeech
import XCTest

// MARK: - NotificationsHubWorkerTests
//
// NotificationsHubWorker — enum со статическими методами (нет I/O).
// Все пути тестируются напрямую.

final class NotificationsHubWorkerTests: XCTestCase {

    // MARK: - Helpers

    private func makeChild(
        id: String = "c-001",
        name: String = "Маша",
        targetSounds: [String] = ["Р"],
        streak: Int = 0,
        lastSessionAt: Date? = nil
    ) -> ChildProfileDTO {
        TestDataBuilder.childProfile(
            id: id,
            name: name,
            targetSounds: targetSounds,
            currentStreak: streak,
            lastSessionAt: lastSessionAt
        )
    }

    private func makeSession(
        childId: String = "c-001",
        daysAgo: Int = 0,
        sound: String = "Р"
    ) -> SessionDTO {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: date,
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 180,
            totalAttempts: 10,
            correctAttempts: 8,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    private func makeAchievement(
        id: String = UUID().uuidString,
        unlockedAt: Date = Date()
    ) -> ParentHomeModels.AchievementItem {
        ParentHomeModels.AchievementItem(
            id: id,
            icon: "star.fill",
            title: "Тестовое достижение",
            subtitle: "Описание",
            unlockedAt: unlockedAt,
            colorToken: "gold"
        )
    }

    // MARK: - practiceReminders: session today → no reminder

    func test_buildNotifications_todaySession_noPracticeReminder() {
        let child = makeChild()
        let todaySession = makeSession(daysAgo: 0)
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [todaySession],
            achievements: []
        )
        let reminders = notifications.filter { $0.kind == .reminder }
        XCTAssertTrue(reminders.isEmpty, "Если есть сессия сегодня — нет reminder")
    }

    // MARK: - practiceReminders: no session today + no session yesterday → reminder (bell.fill)

    func test_buildNotifications_noRecentSessions_addsBellReminder() {
        let child = makeChild()
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [],
            achievements: []
        )
        let reminders = notifications.filter { $0.kind == .reminder }
        XCTAssertFalse(reminders.isEmpty, "Без сессий должен появиться reminder")
        XCTAssertTrue(reminders.contains(where: { $0.icon == "bell.fill" }),
                      "Нет сессий давно → bell.fill (body_no_session)")
    }

    // MARK: - practiceReminders: session yesterday + no session today → bell.badge.fill

    func test_buildNotifications_sessionYesterday_addsBellBadgeReminder() {
        let child = makeChild()
        let yesterdaySession = makeSession(daysAgo: 1)
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [yesterdaySession],
            achievements: []
        )
        let reminders = notifications.filter { $0.kind == .reminder }
        XCTAssertFalse(reminders.isEmpty)
        XCTAssertTrue(reminders.contains(where: { $0.icon == "bell.badge.fill" }),
                      "Была сессия вчера → bell.badge.fill (body_daily)")
    }

    // MARK: - achievementNotifications: recent achievement → notification

    func test_buildNotifications_recentAchievement_addsNotification() {
        let child = makeChild()
        let ach = makeAchievement(unlockedAt: Date()) // сейчас → последние 24 часа
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [makeSession(daysAgo: 0)],
            achievements: [ach]
        )
        let achNotifs = notifications.filter { $0.kind == .achievement && $0.id == "ach_\(ach.id)" }
        XCTAssertFalse(achNotifs.isEmpty, "Достижение последние 24ч → notification")
    }

    func test_buildNotifications_oldAchievement_noNotification() {
        let child = makeChild()
        let oldDate = Date().addingTimeInterval(-90000) // 25 часов назад
        let ach = makeAchievement(unlockedAt: oldDate)
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [makeSession(daysAgo: 0)],
            achievements: [ach]
        )
        let achNotifs = notifications.filter { $0.id == "ach_\(ach.id)" }
        XCTAssertTrue(achNotifs.isEmpty, "Достижение старше 24ч → нет notification")
    }

    // MARK: - streak 7+ → congrats notification

    func test_buildNotifications_streak7_addsFlameNotification() {
        let child = makeChild(streak: 7)
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [makeSession(daysAgo: 0)],
            achievements: []
        )
        let streakNotif = notifications.first(where: { $0.id == "streak_congrats_7" })
        XCTAssertNotNil(streakNotif, "Streak >= 7 должен давать поздравительное уведомление")
        XCTAssertEqual(streakNotif?.icon, "flame.fill")
    }

    func test_buildNotifications_streak6_noStreakNotification() {
        let child = makeChild(streak: 6)
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [makeSession(daysAgo: 0)],
            achievements: []
        )
        let streakNotif = notifications.first(where: { $0.id.hasPrefix("streak_congrats_") })
        XCTAssertNil(streakNotif, "Streak < 7 → нет streak congrats")
    }

    // MARK: - sorted by date descending

    func test_buildNotifications_sortedByDateDescending() {
        let child = makeChild(streak: 7)
        let ach = makeAchievement(unlockedAt: Date().addingTimeInterval(-3600))
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [],
            achievements: [ach]
        )
        for i in 1..<notifications.count {
            XCTAssertGreaterThanOrEqual(
                notifications[i-1].date, notifications[i].date,
                "Уведомления должны быть отсортированы от свежих к старым"
            )
        }
    }

    // MARK: - isRead always false (новые уведомления не прочитаны)

    func test_buildNotifications_allNotificationsUnread() {
        let child = makeChild(streak: 8)
        let ach = makeAchievement()
        let notifications = NotificationsHubWorker.buildNotifications(
            child: child,
            sessions: [],
            achievements: [ach]
        )
        XCTAssertTrue(notifications.allSatisfy { !$0.isRead },
                      "Все новые уведомления должны быть isRead=false")
    }
}
