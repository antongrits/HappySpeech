import AppIntents
import Foundation
import OSLog

// MARK: - ShowChildProgressIntent

/// "Сири, покажи прогресс в ХэппиСпич"
/// Открывает ProgressDashboard. Опционально — для конкретного ребёнка (multi-child).
/// Возвращает краткую сводку в Siri-диалоге и предлагает открыть детали.
@available(iOS 17.0, *)
public struct ShowChildProgressIntent: AppIntent {

    public static let title: LocalizedStringResource = "Показать прогресс"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.show_progress.description"),
        categoryName: "Аналитика"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Имя ребёнка"),
        description: LocalizedStringResource("Для нескольких профилей. Оставьте пустым для активного профиля."),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Чей прогресс показать?")
        )
    )
    public var childName: String?

    @Parameter(
        title: LocalizedStringResource("Период"),
        description: LocalizedStringResource("За какой период показать статистику"),
        default: .week
    )
    public var period: ProgressPeriod

    public init() {}

    public init(childName: String? = nil, period: ProgressPeriod = .week) {
        self.childName = childName
        self.period = period
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let stats = await loadStatsFromSharedDefaults(period: period)
        await MainActor.run {
            DeepLinkRouter.shared.handleShowProgress(childName: childName)
        }

        let periodLabel = periodDisplayLabel(period)
        let namePrefix = childName.map { "\($0): " } ?? ""
        let text = "\(namePrefix)За \(periodLabel) — \(stats.sessions) занятий, точность \(stats.accuracy)%. Открываю подробности!"
        let dialog = IntentDialog(stringLiteral: text)
        return .result(dialog: dialog)
    }

    // MARK: - Private helpers

    private struct ProgressStats {
        let sessions: Int
        let accuracy: Int
    }

    private func loadStatsFromSharedDefaults(period: ProgressPeriod) async -> ProgressStats {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let sessions = defaults?.integer(forKey: "progress.weekly_sessions") ?? 0
        let accuracyRaw = defaults?.double(forKey: "progress.weekly_accuracy") ?? 0.0
        return ProgressStats(
            sessions: sessions,
            accuracy: Int(accuracyRaw * 100)
        )
    }

    private func periodDisplayLabel(_ p: ProgressPeriod) -> String {
        switch p {
        case .today: return "сегодня"
        case .week:  return "неделю"
        case .month: return "месяц"
        }
    }
}

// MARK: - ProgressPeriod (AppEnum)

@available(iOS 17.0, *)
public enum ProgressPeriod: String, AppEnum {
    case today
    case week
    case month

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Период")
    )

    public static let caseDisplayRepresentations: [ProgressPeriod: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Сегодня"),
        .week:  DisplayRepresentation(title: "Неделя"),
        .month: DisplayRepresentation(title: "Месяц")
    ]
}
