import AppIntents
import Foundation
import OSLog

// MARK: - GetWeeklySummaryIntent

/// "Сири, расскажи про успехи за неделю в ХэппиСпич"
/// Зачитывает еженедельную сводку прогресса (сессии, точность, стрик).
@available(iOS 17.0, *)
public struct GetWeeklySummaryIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "GetWeeklySummaryIntent")

    public static let title: LocalizedStringResource = "Сводка за неделю"
    public static let description = IntentDescription(
        LocalizedStringResource("Итоги занятий за текущую неделю: сессии, точность произношения, серия дней"),
        categoryName: "Аналитика"
    )
    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Открыть детали"),
        description: LocalizedStringResource("Открыть экран прогресса после сводки"),
        default: false
    )
    public var openDetails: Bool

    public init() {}

    public init(openDetails: Bool = false) {
        self.openDetails = openDetails
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await loadWeeklySummary()

        logger.info("GetWeeklySummaryIntent: sessions=\(summary.sessions) accuracy=\(summary.accuracy) streak=\(summary.streakDays)")

        if openDetails {
            await MainActor.run {
                DeepLinkRouter.shared.handleGetWeeklySummary()
            }
        }

        let phrase = motivationalPhrase(accuracy: summary.accuracy, streak: summary.streakDays)
        let text = "За эту неделю: \(summary.sessions) занятий, точность \(summary.accuracy)%, серия \(summary.streakDays) дней. \(phrase)"
        let dialog = IntentDialog(stringLiteral: text)
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private struct WeeklySummary {
        let sessions: Int
        let accuracy: Int
        let streakDays: Int
        let soundsWorkedOn: [String]
        let totalMinutes: Int
    }

    private func loadWeeklySummary() async -> WeeklySummary {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let sessions = defaults?.integer(forKey: "progress.weekly_sessions") ?? 0
        let accuracyRaw = defaults?.double(forKey: "progress.weekly_accuracy") ?? 0.0
        let streak = defaults?.integer(forKey: "daily_mission.streak") ?? 0
        let sounds = defaults?.stringArray(forKey: "progress.weekly_sounds") ?? []
        let minutes = defaults?.integer(forKey: "progress.weekly_minutes") ?? 0
        return WeeklySummary(
            sessions: sessions,
            accuracy: Int(accuracyRaw * 100),
            streakDays: streak,
            soundsWorkedOn: sounds,
            totalMinutes: minutes
        )
    }

    private func motivationalPhrase(accuracy: Int, streak: Int) -> String {
        switch (accuracy, streak) {
        case (90..., 7...): return "Отличный результат! Так держать!"
        case (80..., 3...): return "Хорошая работа! Продолжай в том же духе."
        case (70..., _):    return "Неплохо! Ещё немного — и будет отлично."
        default:            return "Главное — не останавливаться. Ляля верит в тебя!"
        }
    }
}
