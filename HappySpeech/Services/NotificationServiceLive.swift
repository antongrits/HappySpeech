import Foundation
import OSLog
import UserNotifications

// MARK: - NotificationServiceLive
//
// Production-уровень уведомлений HappySpeech. Обёртка вокруг UNUserNotificationCenter
// с поддержкой ежедневного напоминания, стрик-оповещения, еженедельного отчёта
// для родителя и разового совета (parent tip). Kids-mode полностью отключает
// планирование и отменяет pending-запросы — это гигиена для детского контура.
//
// Идентификаторы запросов:
//   • hs.daily.reminder       — повторяется каждый день в установленное время
//   • hs.streak.reminder      — одноразовое на ближайшее 19:00, обновляется каждый запуск
//   • hs.weekly.report        — воскресенье 18:00 (Europe/Moscow), повторяется
//   • hs.parent.tip.<uuid>    — одноразовые подсказки, живут до даты trigger
//
// Все тексты — на русском через String Catalog (`String(localized:)`). Никаких
// debug-строк в user-facing payload. Логи — только через HSLogger (OSLog).

public final class NotificationServiceLive: NotificationService, @unchecked Sendable {

    // MARK: - Identifiers

    public enum Identifier {
        public static let dailyReminder = "hs.daily.reminder"
        public static let streakReminder = "hs.streak.reminder"
        public static let weeklyReport = "hs.weekly.report"
        public static let parentTipPrefix = "hs.parent.tip."
    }

    // MARK: - Kids-mode gating

    /// UserDefaults-ключ, который выставляется родителем при активации Kids-mode.
    /// Когда выставлен в `true`, сервис не планирует уведомлений и отменяет всё pending.
    public static let kidsModeUserDefaultsKey = "happyspeech.kidsModeActive"

    nonisolated(unsafe) private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    public init(
        center: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center
        self.userDefaults = userDefaults

        // Для еженедельного отчёта строго используем Europe/Moscow независимо от
        // локали устройства — родителю удобнее получить один и тот же слот каждое
        // воскресенье. В отдельном календаре храним тайзону, чтобы не мутировать
        // системный `.current`.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        cal.firstWeekday = 2 // понедельник
        self.calendar = cal
    }

    // MARK: - NotificationService protocol surface

    public func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            HSLogger.app.info("Notification permission: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            HSLogger.app.error("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    /// Legacy-совместимая подпись (iOS-`Int hour`, `Int minute`).
    public func scheduleDailyReminder(at hour: Int, minute: Int) async throws {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        try await scheduleDailyReminder(at: components)
    }

    public func cancelAllReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: [
            Identifier.dailyReminder,
            Identifier.streakReminder,
            Identifier.weeklyReport,
        ])
        HSLogger.app.info("Cancelled known reminders")
    }

    // MARK: - Expanded API (NotificationServiceLive-specific)

    /// Ежедневное напоминание в указанное время. DateComponents должен содержать
    /// hour и minute; timezone игнорируется — используем локальный календарь
    /// устройства (родителю удобнее поставить «18:00 своего времени»).
    public func scheduleDailyReminder(at time: DateComponents) async throws {
        guard !isKidsModeActive else {
            HSLogger.app.notice("Daily reminder skipped — Kids mode active")
            return
        }
        guard await isAuthorized else {
            HSLogger.app.notice("Daily reminder skipped — permission not granted")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notifications.daily.title")
        content.body = String(localized: "notifications.daily.body")
        content.sound = .default
        content.categoryIdentifier = "HS_DAILY_REMINDER"

        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute

        let request = UNNotificationRequest(
            identifier: Identifier.dailyReminder,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        // Убираем предыдущий с тем же id перед обновлением — иначе iOS не заменяет.
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.dailyReminder])
        try await center.add(request)

        let hour = time.hour ?? 0
        let minute = time.minute ?? 0
        HSLogger.app.info("Daily reminder scheduled at \(hour):\(String(format: "%02d", minute))")
    }

    /// Одноразовое стрик-напоминание в 19:00 текущего дня (или следующего, если
    /// уже позже 19:00). Пересобирается при каждом вызове.
    public func scheduleStreakReminder(streakDays: Int) async throws {
        guard !isKidsModeActive else {
            HSLogger.app.notice("Streak reminder skipped — Kids mode active")
            return
        }
        guard await isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notifications.streak.title")
        let bodyTemplate = String(localized: "notifications.streak.body")
        content.body = String(format: bodyTemplate, streakDays)
        content.sound = .default

        let fireDate = nextOccurrence(hour: 19, minute: 0)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: Identifier.streakReminder,
            content: content,
            trigger: trigger
        )
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.streakReminder])
        try await center.add(request)
        HSLogger.app.info("Streak reminder scheduled (streak=\(streakDays))")
    }

    /// Еженедельный отчёт — воскресенье 18:00 Europe/Moscow. Повторяется.
    public func scheduleWeeklyReport() async throws {
        guard !isKidsModeActive else {
            HSLogger.app.notice("Weekly report skipped — Kids mode active")
            return
        }
        guard await isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notifications.weekly.title")
        content.body = String(localized: "notifications.weekly.body")
        content.sound = .default
        content.categoryIdentifier = "HS_WEEKLY_REPORT"

        var trigger = DateComponents()
        trigger.calendar = calendar
        trigger.timeZone = calendar.timeZone
        trigger.weekday = 1   // Gregorian: 1 = воскресенье
        trigger.hour = 18
        trigger.minute = 0

        let request = UNNotificationRequest(
            identifier: Identifier.weeklyReport,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.weeklyReport])
        try await center.add(request)
        HSLogger.app.info("Weekly report scheduled Sunday 18:00 Europe/Moscow")
    }

    /// Одноразовый совет для родителя в указанный момент.
    @discardableResult
    public func scheduleParentTip(content text: String, when: DateComponents) async throws -> String {
        let identifier = Identifier.parentTipPrefix + UUID().uuidString
        guard !isKidsModeActive else {
            HSLogger.app.notice("Parent tip skipped — Kids mode active")
            return identifier
        }
        guard await isAuthorized else { return identifier }

        let payload = UNMutableNotificationContent()
        payload.title = String(localized: "notifications.tip.title")
        payload.body = text
        payload.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: payload,
            trigger: trigger
        )
        try await center.add(request)
        HSLogger.app.info("Parent tip scheduled id=\(identifier, privacy: .private)")
        return identifier
    }

    /// Отмена всех запланированных (pending) уведомлений — используется при
    /// выходе из аккаунта или удалении данных.
    public func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        HSLogger.app.info("All pending/delivered notifications cancelled")
    }

    /// Sendable-снимок запроса уведомления для UI-слоя.
    /// `UNNotificationRequest` сам по себе не Sendable, поэтому наружу отдаём DTO.
    public struct PendingRequestInfo: Sendable, Identifiable, Equatable {
        public let id: String
        public let title: String
        public let body: String
    }

    /// Список текущих pending-запросов (для отладки и Settings-экрана).
    public func pendingRequests() async -> [PendingRequestInfo] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let snapshot = requests.map { req in
                    PendingRequestInfo(
                        id: req.identifier,
                        title: req.content.title,
                        body: req.content.body
                    )
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    // MARK: - Private helpers

    private var isKidsModeActive: Bool {
        userDefaults.bool(forKey: Self.kidsModeUserDefaultsKey)
    }

    private var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .notDetermined, .denied:
                return false
            @unknown default:
                return false
            }
        }
    }

    private func nextOccurrence(hour: Int, minute: Int) -> Date {
        let now = Date()
        let localCalendar = Calendar.current
        var components = localCalendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        let candidate = localCalendar.date(from: components) ?? now
        if candidate > now { return candidate }
        return localCalendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }
}
