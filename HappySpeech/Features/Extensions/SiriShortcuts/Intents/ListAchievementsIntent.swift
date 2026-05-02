import AppIntents
import Foundation
import OSLog

// MARK: - ListAchievementsIntent

/// "Сири, покажи достижения в ХэппиСпич"
/// Зачитывает последние 5 разблокированных достижений и открывает Rewards экран.
@available(iOS 17.0, *)
public struct ListAchievementsIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "ListAchievementsIntent")

    public static let title: LocalizedStringResource = "Показать достижения"
    public static let description = IntentDescription(
        LocalizedStringResource("Последние разблокированные достижения и награды Ляли"),
        categoryName: "Награды"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Только новые"),
        description: LocalizedStringResource("Показать только достижения за последние 7 дней"),
        default: false
    )
    public var onlyRecent: Bool

    public init() {}

    public init(onlyRecent: Bool = false) {
        self.onlyRecent = onlyRecent
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let achievements = await loadAchievementsFromSharedDefaults()

        await MainActor.run {
            DeepLinkRouter.shared.handleListAchievements()
        }

        logger.info("ListAchievementsIntent: onlyRecent=\(onlyRecent), count=\(achievements.count)")

        let dialog = buildDialog(achievements: achievements)
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private struct AchievementInfo {
        let title: String
        let unlockedDaysAgo: Int
    }

    private func loadAchievementsFromSharedDefaults() async -> [AchievementInfo] {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        guard let raw = defaults?.array(forKey: "achievements.recent") as? [[String: Any]] else {
            return [
                AchievementInfo(title: "Первый урок", unlockedDaysAgo: 0),
                AchievementInfo(title: "Серия 3 дня", unlockedDaysAgo: 1)
            ]
        }
        return raw.prefix(5).compactMap { dict -> AchievementInfo? in
            guard let title = dict["title"] as? String,
                  let days = dict["daysAgo"] as? Int else { return nil }
            return AchievementInfo(title: title, unlockedDaysAgo: days)
        }
    }

    private func buildDialog(achievements: [AchievementInfo]) -> IntentDialog {
        guard !achievements.isEmpty else {
            return IntentDialog(
                LocalizedStringResource("Пока нет разблокированных достижений. Продолжай заниматься!")
            )
        }
        let filtered = onlyRecent ? achievements.filter { $0.unlockedDaysAgo <= 7 } : achievements
        if filtered.isEmpty {
            return IntentDialog(
                LocalizedStringResource("За последние 7 дней новых достижений нет. Открываю все.")
            )
        }
        let names = filtered.prefix(3).map { $0.title }.joined(separator: ", ")
        return IntentDialog(
            LocalizedStringResource("Последние достижения: \(names). Открываю альбом наград!")
        )
    }
}
