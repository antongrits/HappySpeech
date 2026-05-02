import AppIntents
import Foundation
import OSLog
import UserNotifications

// MARK: - SetReminderIntent

/// "Сири, напомни заниматься в ХэппиСпич в 18:00"
/// Устанавливает ежедневное локальное напоминание о логопедическом занятии.
@available(iOS 17.0, *)
public struct SetReminderIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "SetReminderIntent")

    public static let title: LocalizedStringResource = "Установить напоминание"
    public static let description = IntentDescription(
        LocalizedStringResource("Ежедневное напоминание о логопедическом занятии на выбранное время"),
        categoryName: "Напоминания"
    )
    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Час"),
        description: LocalizedStringResource("Час напоминания (0–23)"),
        default: 18,
        requestValueDialog: IntentDialog(
            LocalizedStringResource("В какой час поставить напоминание? (0–23)")
        )
    )
    public var hour: Int

    @Parameter(
        title: LocalizedStringResource("Минута"),
        description: LocalizedStringResource("Минута напоминания (0–59)"),
        default: 0,
        requestValueDialog: IntentDialog(
            LocalizedStringResource("На какую минуту?")
        )
    )
    public var minute: Int

    public init() {}

    public init(hour: Int = 18, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let clampedHour   = max(0, min(hour, 23))
        let clampedMinute = max(0, min(minute, 59))

        let authorized = await requestNotificationPermissionIfNeeded()
        guard authorized else {
            return .result(
                dialog: IntentDialog(
                    LocalizedStringResource("Нет разрешения на уведомления. Открой Настройки → ХэппиСпич → Уведомления.")
                )
            )
        }

        await MainActor.run {
            DeepLinkRouter.shared.handleSetReminder(hour: clampedHour, minute: clampedMinute)
        }

        logger.info("SetReminderIntent: hour=\(clampedHour) minute=\(clampedMinute)")

        let timeString = String(format: "%02d:%02d", clampedHour, clampedMinute)
        let dialog = IntentDialog(
            LocalizedStringResource("Каждый день в \(timeString) буду напоминать заниматься. Ляля не забудет!")
        )
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private func requestNotificationPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                logger.error("SetReminderIntent: ошибка запроса разрешения: \(error.localizedDescription)")
                return false
            }
        default:
            return false
        }
    }
}
