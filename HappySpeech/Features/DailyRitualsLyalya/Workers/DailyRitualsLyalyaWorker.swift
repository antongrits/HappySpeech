import Foundation
import OSLog
import UserNotifications

// MARK: - DailyRitualsLyalyaWorkerProtocol

@MainActor
protocol DailyRitualsLyalyaWorkerProtocol: AnyObject {
    func steps(for kind: RitualKind) -> [RitualStep]
    func reminderEnabled(for kind: RitualKind) -> Bool
    func reminderTime(for kind: RitualKind) -> ReminderTime
    func setReminderEnabled(_ enabled: Bool, for kind: RitualKind)
    func setReminderTime(_ time: ReminderTime, for kind: RitualKind)
    func notificationAuthorizationStatus() async -> Bool
    func requestNotificationAuthorization() async -> Bool
    func scheduleReminder(for kind: RitualKind, time: ReminderTime) async
    func cancelReminder(for kind: RitualKind) async
}

// MARK: - DailyRitualsLyalyaWorker (Clean Swift: Worker)
//
// v31 Волна A, Функция Ф8 «Утро и вечер с Лялей».
//
// Координирует UserDefaults-настройки ритуалов и локальные напоминания через
// UNUserNotificationCenter. Не создаёт push-токенов и не использует FCM —
// только локальные уведомления (Kids Category compliant).

@MainActor
final class DailyRitualsLyalyaWorker: DailyRitualsLyalyaWorkerProtocol {

    // MARK: - Identifiers

    private enum Identifier {
        static let morning = "hs.ritual.morning"
        static let evening = "hs.ritual.evening"

        static func notification(for kind: RitualKind) -> String {
            switch kind {
            case .morning: return Self.morning
            case .evening: return Self.evening
            }
        }
    }

    // MARK: - Storage keys

    private enum DefaultsKey {
        static func enabled(_ kind: RitualKind) -> String {
            "dailyRituals.\(kind.rawValue).enabled"
        }
        static func hour(_ kind: RitualKind) -> String {
            "dailyRituals.\(kind.rawValue).hour"
        }
        static func minute(_ kind: RitualKind) -> String {
            "dailyRituals.\(kind.rawValue).minute"
        }
    }

    private let defaults: UserDefaults
    nonisolated(unsafe) private let center: UNUserNotificationCenter

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyRituals.Worker"
    )

    init(
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.center = center
    }

    // MARK: - Steps

    func steps(for kind: RitualKind) -> [RitualStep] {
        DailyRitualsLyalyaCorpus.steps(for: kind)
    }

    // MARK: - Reminder enabled

    func reminderEnabled(for kind: RitualKind) -> Bool {
        defaults.bool(forKey: DefaultsKey.enabled(kind))
    }

    func setReminderEnabled(_ enabled: Bool, for kind: RitualKind) {
        defaults.set(enabled, forKey: DefaultsKey.enabled(kind))
    }

    // MARK: - Reminder time

    func reminderTime(for kind: RitualKind) -> ReminderTime {
        if defaults.object(forKey: DefaultsKey.hour(kind)) == nil {
            return ReminderTime(hour: kind.defaultHour, minute: kind.defaultMinute)
        }
        let hour = defaults.integer(forKey: DefaultsKey.hour(kind))
        let minute = defaults.integer(forKey: DefaultsKey.minute(kind))
        return ReminderTime(hour: hour, minute: minute)
    }

    func setReminderTime(_ time: ReminderTime, for kind: RitualKind) {
        defaults.set(time.hour, forKey: DefaultsKey.hour(kind))
        defaults.set(time.minute, forKey: DefaultsKey.minute(kind))
    }

    // MARK: - Authorization

    func notificationAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func requestNotificationAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            Self.logger.info("Daily rituals authorization: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            Self.logger.error(
                "Daily rituals authorization error: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    // MARK: - Schedule / cancel

    func scheduleReminder(for kind: RitualKind, time: ReminderTime) async {
        await cancelReminder(for: kind)

        let content = UNMutableNotificationContent()
        content.title = String(localized: kindBodyTitleKey(for: kind))
        content.body = String(localized: kindBodyTextKey(for: kind))
        content.sound = .default

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Identifier.notification(for: kind),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Self.logger.info(
                "Scheduled \(kind.rawValue, privacy: .public) ritual at \(time.hour):\(time.minute)"
            )
        } catch {
            Self.logger.error(
                "Failed to schedule \(kind.rawValue, privacy: .public) ritual: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func cancelReminder(for kind: RitualKind) async {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.notification(for: kind)])
        Self.logger.debug("Cancelled \(kind.rawValue, privacy: .public) ritual reminder")
    }

    // MARK: - Localization keys

    private func kindBodyTitleKey(for kind: RitualKind) -> String.LocalizationValue {
        switch kind {
        case .morning: return "dailyRituals.notification.morning.title"
        case .evening: return "dailyRituals.notification.evening.title"
        }
    }

    private func kindBodyTextKey(for kind: RitualKind) -> String.LocalizationValue {
        switch kind {
        case .morning: return "dailyRituals.notification.morning.body"
        case .evening: return "dailyRituals.notification.evening.body"
        }
    }
}
